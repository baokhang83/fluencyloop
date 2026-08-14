'use strict';

// A small, bundled Mermaid reader. It intentionally accepts only the diagram forms that are
// useful in a distillation: relationship flowcharts and message sequences. Unknown or malformed
// input becomes a caption-only note instead of exposing source or breaking the page.
const svgNamespace = 'http:' + '//' + 'www.w3.org/2000/svg';

function svgElement(name, attributes = {}) {
  const element = document.createElementNS(svgNamespace, name);
  for (const [key, value] of Object.entries(attributes)) element.setAttribute(key, String(value));
  return element;
}

function appendText(parent, value, x, y, attributes = {}) {
  const text = svgElement('text', { x, y, ...attributes });
  text.textContent = value;
  parent.append(text);
  return text;
}

function parseEndpoint(token) {
  const match = token.trim().match(/^([A-Za-z0-9_-]+)(?:\[([^\]]+)\]|\(([^)]+)\)|\{([^}]+)\})?$/);
  if (!match) throw new Error('invalid node');
  return { id: match[1], label: match[2] || match[3] || match[4] || match[1] };
}

function parseFlowchart(source) {
  const lines = source.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('%%'));
  const heading = lines.shift()?.match(/^(?:flowchart|graph)\s+(TD|TB|BT|LR|RL)$/i);
  if (!heading) throw new Error('unsupported flowchart');
  const nodes = new Map();
  const edges = [];
  for (const line of lines) {
    const edge = line.match(/^(.+?)\s*(?:-->|---|==>|-\.->)\s*(.+?)(?:\s*:\s*.*)?$/);
    if (!edge) continue;
    const from = parseEndpoint(edge[1]);
    const to = parseEndpoint(edge[2]);
    nodes.set(from.id, from);
    nodes.set(to.id, to);
    edges.push({ from: from.id, to: to.id });
  }
  if (!edges.length) throw new Error('flowchart has no links');
  return { direction: heading[1].toUpperCase(), nodes: [...nodes.values()], edges };
}

function parseSequence(source) {
  const lines = source.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('%%'));
  if (lines.shift() !== 'sequenceDiagram') throw new Error('unsupported sequence');
  const actors = new Map();
  const messages = [];
  for (const line of lines) {
    const participant = line.match(/^participant\s+([A-Za-z0-9_-]+)(?:\s+as\s+(.+))?$/i);
    if (participant) {
      actors.set(participant[1], participant[2] || participant[1]);
      continue;
    }
    const message = line.match(/^([A-Za-z0-9_-]+)\s*[-=]+>+\s*([A-Za-z0-9_-]+)\s*:\s*(.+)$/);
    if (!message) continue;
    actors.set(message[1], actors.get(message[1]) || message[1]);
    actors.set(message[2], actors.get(message[2]) || message[2]);
    messages.push({ from: message[1], to: message[2], label: message[3] });
  }
  if (!messages.length) throw new Error('sequence has no messages');
  return { actors: [...actors].map(([id, label]) => ({ id, label })), messages };
}

function diagramSvg(width, height) {
  const svg = svgElement('svg', { viewBox: '0 0 ' + width + ' ' + height, role: 'img', focusable: 'false' });
  const defs = svgElement('defs');
  const marker = svgElement('marker', { id: 'diagram-arrow', markerWidth: 8, markerHeight: 8, refX: 7, refY: 4, orient: 'auto' });
  marker.append(svgElement('path', { d: 'M 0 0 L 8 4 L 0 8 z', class: 'diagram-arrow' }));
  defs.append(marker);
  svg.append(defs);
  return svg;
}

function renderFlowchart(model) {
  const horizontal = model.direction === 'LR' || model.direction === 'RL';
  const count = model.nodes.length;
  const width = horizontal ? Math.max(480, count * 190 + 70) : 640;
  const height = horizontal ? 220 : Math.max(220, count * 105 + 60);
  const svg = diagramSvg(width, height);
  const points = new Map();
  model.nodes.forEach((node, index) => {
    const x = horizontal ? 105 + index * 190 : width / 2;
    const y = horizontal ? height / 2 : 65 + index * 105;
    points.set(node.id, { x, y });
  });
  for (const edge of model.edges) {
    const from = points.get(edge.from);
    const to = points.get(edge.to);
    if (!from || !to) continue;
    svg.append(svgElement('line', { x1: from.x, y1: from.y, x2: to.x, y2: to.y, class: 'diagram-link', 'marker-end': 'url(#diagram-arrow)' }));
  }
  for (const node of model.nodes) {
    const point = points.get(node.id);
    svg.append(svgElement('rect', { x: point.x - 72, y: point.y - 25, width: 144, height: 50, rx: 12, class: 'diagram-node' }));
    appendText(svg, node.label, point.x, point.y + 5, { class: 'diagram-label', 'text-anchor': 'middle' });
  }
  return svg;
}

function renderSequence(model) {
  const width = Math.max(460, model.actors.length * 170 + 80);
  const height = Math.max(230, model.messages.length * 58 + 120);
  const svg = diagramSvg(width, height);
  const points = new Map();
  model.actors.forEach((actor, index) => {
    const x = 85 + index * ((width - 170) / Math.max(1, model.actors.length - 1));
    points.set(actor.id, x);
    svg.append(svgElement('rect', { x: x - 58, y: 16, width: 116, height: 36, rx: 10, class: 'diagram-node' }));
    appendText(svg, actor.label, x, 39, { class: 'diagram-label', 'text-anchor': 'middle' });
    svg.append(svgElement('line', { x1: x, y1: 58, x2: x, y2: height - 22, class: 'diagram-lifeline' }));
  });
  model.messages.forEach((message, index) => {
    const y = 94 + index * 58;
    const from = points.get(message.from);
    const to = points.get(message.to);
    svg.append(svgElement('line', { x1: from, y1: y, x2: to, y2: y, class: 'diagram-link', 'marker-end': 'url(#diagram-arrow)' }));
    appendText(svg, message.label, (from + to) / 2, y - 8, { class: 'diagram-message', 'text-anchor': 'middle' });
  });
  return svg;
}

function renderDiagram(figure) {
  const canvas = figure.querySelector('.diagram-canvas');
  const caption = figure.querySelector('figcaption')?.textContent || 'Supporting diagram';
  try {
    const source = decodeURIComponent(figure.dataset.mermaid || '');
    const svg = /^sequenceDiagram\b/.test(source.trim())
      ? renderSequence(parseSequence(source))
      : renderFlowchart(parseFlowchart(source));
    svg.setAttribute('aria-label', caption);
    canvas.replaceChildren(svg);
    figure.dataset.diagramState = 'rendered';
  } catch (_) {
    canvas.replaceChildren();
    canvas.hidden = true;
    figure.dataset.diagramState = 'unavailable';
  }
}

// Rows filter by two independent axes that compose with AND: free text (title, summary, tag names,
// and record kind) and a set of selected tags, which is OR among themselves — picking two tags
// widens the result to either, the way most faceted filters read. The server renders every row
// unfiltered, so this is pure progressive enhancement: without JavaScript the catalog is complete.
// State round-trips through the URL so a filtered view is something you can link to.
function installCatalogFilters() {
  document.querySelectorAll('[data-catalog]').forEach((catalog) => {
    const rows = [...catalog.querySelectorAll('[data-record-row]')];
    const tagControls = [...catalog.querySelectorAll('[data-tag-filter]')];
    const searchInput = catalog.querySelector('[data-catalog-search]');
    const status = catalog.querySelector('[data-catalog-status]');
    if (!rows.length) return;

    const rowText = new WeakMap();
    rows.forEach((row) => rowText.set(row, row.textContent.toLowerCase()));

    const params = new URLSearchParams(window.location.search);
    const selected = new Set((params.get('tag') || '').split(',').filter(Boolean));
    let query = params.get('q') || '';
    if (searchInput) searchInput.value = query;

    const syncUrl = () => {
      const next = new URLSearchParams(window.location.search);
      query ? next.set('q', query) : next.delete('q');
      selected.size ? next.set('tag', [...selected].join(',')) : next.delete('tag');
      const search = next.toString();
      const url = window.location.pathname + (search ? `?${search}` : '') + window.location.hash;
      window.history.replaceState(null, '', url);
    };

    const applyFilters = () => {
      const needle = query.trim().toLowerCase();
      let shown = 0;
      rows.forEach((row) => {
        const tags = (row.dataset.tags || '').split(' ').filter(Boolean);
        const matchesTags = selected.size === 0 || tags.some((tag) => selected.has(tag));
        const matchesText = !needle || rowText.get(row).includes(needle);
        const matches = matchesTags && matchesText;
        row.hidden = !matches;
        if (matches) shown += 1;
      });
      tagControls.forEach((control) => {
        const isAll = control.dataset.tagFilter === 'all';
        const active = isAll ? selected.size === 0 : selected.has(control.dataset.tagFilter);
        control.setAttribute('aria-pressed', String(active));
      });
      if (status) {
        status.textContent = shown === rows.length
          ? ''
          : `${shown} record${shown === 1 ? '' : 's'} of ${rows.length} shown.`;
      }
      syncUrl();
    };

    tagControls.forEach((control) => control.addEventListener('click', () => {
      const tag = control.dataset.tagFilter;
      if (tag === 'all') selected.clear();
      else selected.has(tag) ? selected.delete(tag) : selected.add(tag);
      applyFilters();
    }));

    searchInput?.addEventListener('input', () => {
      query = searchInput.value;
      applyFilters();
    });

    applyFilters();
  });
}

function syncEmbeddedDiagramThemes(theme) {
  document.querySelectorAll('.record-diagram iframe').forEach((frame) => {
    const source = frame.getAttribute('src');
    if (!source) return;
    const url = new URL(source, window.location.href);
    url.searchParams.set('theme', theme);
    if (frame.src !== url.href) frame.src = url.href;
  });
}

function highlightCode(scope = document) {
  if (!window.hljs) return;
  scope.querySelectorAll('code[data-highlight]').forEach((element) => {
    try { window.hljs.highlightElement(element); } catch (_) { /* Plain text stays readable. */ }
  });
}

// Evidence is a normal same-tab route first. JavaScript upgrades it to a drawer by fetching the
// same route with a presentation hint, so copied links and disabled JavaScript still reach the
// complete canonical page.
function installEvidenceDrawer() {
  let drawer = null;
  let opener = null;
  let pushed = false;
  const focusable = () => drawer ? [...drawer.querySelectorAll('a[href], button:not([disabled]), input, summary, [tabindex]:not([tabindex="-1"])')].filter((item) => !item.hidden) : [];

  const close = (fromHistory = false) => {
    if (!drawer) return;
    const current = drawer;
    drawer = null;
    current.remove();
    document.body.classList.remove('drawer-open');
    if (opener?.isConnected) opener.focus();
    opener = null;
    if (pushed && !fromHistory) history.back();
    pushed = false;
  };

  const open = async (href, trigger, replace = false) => {
    const target = new URL(href, window.location.href);
    const range = target.hash.match(/^#L?(\d+)(?:-L?(\d+))?$/i);
    if (range && target.pathname.startsWith('/code/')) target.searchParams.set('range', `${range[1]}${range[2] ? `-L${range[2]}` : ''}`);
    target.hash = '';
    target.searchParams.set('drawer', '1');
    const response = await fetch(target.href, { headers: { Accept: 'text/html' } });
    if (!response.ok) return;
    const documentForDrawer = new DOMParser().parseFromString(await response.text(), 'text/html');
    const content = documentForDrawer.querySelector('#content');
    if (!content) return;
    const retainHistory = replace && pushed;
    close(true);
    pushed = retainHistory;
    opener = trigger || document.activeElement;
    const shell = document.createElement('div');
    shell.className = 'evidence-drawer';
    shell.innerHTML = '<div class="evidence-backdrop" data-drawer-close></div><aside class="evidence-drawer-panel" role="dialog" aria-modal="true" aria-labelledby="evidence-drawer-title"><div class="drawer-heading"><h2 id="evidence-drawer-title">Evidence</h2><button type="button" data-drawer-close aria-label="Close evidence">Close</button></div><div class="drawer-content"></div></aside>';
    const destination = shell.querySelector('.drawer-content');
    [...content.children].forEach((child) => {
      if (child.matches('nav[aria-label="Primary"], nav[aria-label="Breadcrumb"]')) return;
      destination.append(child);
    });
    document.body.append(shell);
    drawer = shell;
    document.body.classList.add('drawer-open');
    highlightCode(shell);
    if (!replace) {
      history.pushState({ ...(history.state || {}), fluencyloopEvidenceDrawer: true }, '', new URL(href, window.location.href).href);
      pushed = true;
    }
    shell.querySelector('[data-drawer-close]')?.focus();
  };

  document.addEventListener('click', (event) => {
    const evidence = event.target.closest('a[data-evidence]');
    if (evidence && event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey) {
      event.preventDefault();
      open(evidence.href, evidence).catch(() => {});
      return;
    }
    const expand = event.target.closest('a[data-expand-source]');
    if (expand && drawer) {
      event.preventDefault();
      open(expand.href, opener, true).catch(() => {});
      return;
    }
    if (drawer && event.target.closest('[data-drawer-close]')) close();
  });
  document.addEventListener('keydown', (event) => {
    if (!drawer) return;
    if (event.key === 'Escape') { event.preventDefault(); close(); return; }
    if (event.key !== 'Tab') return;
    const items = focusable();
    if (!items.length) return;
    const first = items[0]; const last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  window.addEventListener('popstate', () => { if (drawer) close(true); });
}

// Keep personal presentation preferences in the browser, never in the project store.
(() => {
  const root = document.documentElement;
  const button = document.querySelector('[data-theme-toggle]');
  const storageKey = 'fluencyloop.site.theme';

  const updateButton = (theme) => {
    if (!button) return;
    const isDark = theme === 'dark';
    button.textContent = isDark ? 'Light' : 'Dark';
    button.setAttribute('aria-label', 'Switch to ' + (isDark ? 'light' : 'dark') + ' theme');
    button.setAttribute('aria-pressed', String(isDark));
  };

  let theme;
  try {
    const saved = localStorage.getItem(storageKey);
    theme = saved === 'light' || saved === 'dark'
      ? saved
      : (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  } catch (_) {
    theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  root.dataset.theme = theme;
  updateButton(theme);
  syncEmbeddedDiagramThemes(theme);

  button?.addEventListener('click', () => {
    const current = root.dataset.theme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    const next = current === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    updateButton(next);
    syncEmbeddedDiagramThemes(next);
    try { localStorage.setItem(storageKey, next); } catch (_) { /* presentation still changes */ }
  });

  requestAnimationFrame(() => { document.body.dataset.motion = 'ready'; });
  document.querySelectorAll('.diagram[data-mermaid]').forEach(renderDiagram);
  highlightCode();
  installCatalogFilters();
  installEvidenceDrawer();
})();
