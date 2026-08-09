#!/usr/bin/env node
'use strict';

// The local FluencyLoop reader. It deliberately has no build step and no dependencies: every
// response reads the project's current store, distillations, and local calibration profile.

const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const DEFAULT_PORT = 4173;
const SITE_ASSETS = {
  '/assets/site.css': { file: 'site.css', contentType: 'text/css; charset=utf-8' },
  '/assets/site.js': { file: 'site.js', contentType: 'application/javascript; charset=utf-8' },
  '/assets/fonts/dm-sans.woff2': { file: 'fonts/dm-sans.woff2.b64', contentType: 'font/woff2', encoding: 'base64' },
  '/assets/fonts/fraunces.woff2': { file: 'fonts/fraunces.woff2.b64', contentType: 'font/woff2', encoding: 'base64' },
};
const IDENTITY_FIELDS = {
  feature: ['slug'],
  session: ['feature', 'slug'],
  decision: ['feature', 'session', 'where', 'title'],
  component: ['feature', 'session', 'name'],
  condition: ['feature', 'session', 'subject'],
  concept: ['name'],
  relation: ['from', 'to', 'kind'],
  principle: ['number'],
  requirement: ['feature', 'gap'],
  open_question: ['feature', 'gap'],
};

function usage(message) {
  if (message) process.stderr.write(`Error: ${message}\n`);
  process.stderr.write('Usage: fluencyloop site [--port <0-65535>]\n');
  process.exitCode = 1;
}

function parseArgs(argv) {
  const options = { root: '', port: DEFAULT_PORT };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--root' || arg === '--port') {
      const value = argv[index + 1];
      if (!value) throw new Error(`${arg} needs a value`);
      index += 1;
      if (arg === '--root') options.root = path.resolve(value);
      else {
        if (!/^\d+$/.test(value)) throw new Error('--port must be an integer from 0 to 65535');
        options.port = Number(value);
        if (options.port > 65535) throw new Error('--port must be an integer from 0 to 65535');
      }
    } else {
      throw new Error(`unknown option: ${arg}`);
    }
  }
  if (!options.root) throw new Error('the project root is required');
  return options;
}

function filesUnder(directory, extension) {
  if (!fs.existsSync(directory)) return [];
  const result = [];
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const child = path.join(current, entry.name);
      if (entry.isDirectory()) visit(child);
      else if (entry.isFile() && child.endsWith(extension)) result.push(child);
    }
  };
  visit(directory);
  return result.sort();
}

function identityFor(record, fallback) {
  const fields = IDENTITY_FIELDS[record.type];
  if (!fields || fields.some((field) => typeof record[field] !== 'string')) return `${record.type || 'unknown'}\u0000${fallback}`;
  return [record.type, ...fields.map((field) => record[field])].join('\u0000');
}

function readStore(storeDir) {
  const errors = [];
  const current = new Map();
  const files = filesUnder(storeDir, '.jsonl');
  let ordinal = 0;
  for (const file of files) {
    const relative = path.relative(storeDir, file);
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    lines.forEach((line, lineIndex) => {
      if (!line.trim()) return;
      ordinal += 1;
      try {
        const record = JSON.parse(line);
        if (!record || typeof record !== 'object' || Array.isArray(record)) throw new Error('expected a JSON object');
        const key = identityFor(record, `${relative}:${lineIndex + 1}:${ordinal}`);
        current.set(key, record);
      } catch (error) {
        errors.push({ file: relative, line: lineIndex + 1, message: error.message });
      }
    });
  }
  return { files: files.map((file) => path.relative(storeDir, file)), errors, records: [...current.values()] };
}

function readDistillations(directory) {
  return filesUnder(directory, '.md').map((file) => ({
    path: path.relative(directory, file).split(path.sep).join('/'),
    content: fs.readFileSync(file, 'utf8'),
  }));
}

function readCalibration() {
  const home = process.env.FLUENCYLOOP_HOME || path.join(os.homedir(), '.fluencyloop');
  const calibration = path.join(home, 'calibration.md');
  const levels = {};
  if (!fs.existsSync(calibration)) return levels;

  let inProfile = false;
  let inComment = false;
  for (const line of fs.readFileSync(calibration, 'utf8').split(/\r?\n/)) {
    if (inComment) {
      if (line.includes('-->')) inComment = false;
      continue;
    }
    if (line.includes('<!--')) {
      if (!line.includes('-->')) inComment = true;
      continue;
    }
    if (line === '## Profile') {
      inProfile = true;
      continue;
    }
    if (/^##\s/.test(line)) inProfile = false;
    if (!inProfile) continue;
    const match = line.match(/^([A-Za-z0-9][A-Za-z0-9._+-]*):\s*(fluent|familiar|learning|new)(?:\s|$)/);
    if (match) levels[match[1]] = match[2];
  }
  return levels;
}

function readSiteData(root) {
  const docs = path.join(root, 'docs', 'fluencyloop');
  const data = {
    project: path.basename(root),
    store: readStore(path.join(docs, 'store')),
    distillations: readDistillations(path.join(docs, 'distillations')),
    calibration: readCalibration(),
  };
  data.navigation = buildNavigation(data);
  return data;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  })[character]);
}

function recordLabel(record) {
  return record.title || record.name || record.slug || record.number || record.gap || record.type;
}

function slugFor(value) {
  return String(value).trim().toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'untitled';
}

function byType(records, type) {
  return records.filter((record) => record.type === type);
}

// True once the store holds decisions/components/conditions but no concepts yet — the shape a
// project takes right after `fluencyloop import`, since the legacy importer deterministically
// parses what old markdown already said and never synthesizes a concept (that needs judgment,
// which is what fluencyloop-backfill is for, not import). Distinguishing this from a genuinely
// empty project changes which empty-state message actually points somewhere useful.
function hasCapturedHistoryWithoutConcepts(records) {
  const hasHistory = records.some((record) => record.type === 'decision' || record.type === 'component' || record.type === 'condition');
  const hasConcepts = records.some((record) => record.type === 'concept');
  return hasHistory && !hasConcepts;
}

function sortByLabel(records) {
  return [...records].sort((left, right) => recordLabel(left).localeCompare(recordLabel(right)));
}

function distillationIndex(distillations) {
  const index = new Map();
  for (const item of distillations) index.set(item.path, item);
  return index;
}

function buildNavigation(data) {
  const records = data.store.records;
  const concepts = sortByLabel(byType(records, 'concept'));
  const conceptByName = new Map(concepts.map((concept) => [concept.name, concept]));
  const features = new Map();
  const addFeature = (slug) => {
    if (!slug || slug === 'global') return;
    if (!features.has(slug)) features.set(slug, { slug, concepts: new Set() });
  };

  for (const record of records) {
    if (record.type === 'feature') addFeature(record.slug);
    if (typeof record.feature === 'string') addFeature(record.feature);
  }

  const featureRecords = new Map(byType(records, 'feature').map((record) => [record.slug, record]));
  const relations = sortByLabel(byType(records, 'relation'));
  const addFeatureConcept = (feature, concept) => {
    if (features.has(feature) && conceptByName.has(concept)) features.get(feature).concepts.add(concept);
  };
  for (const concept of concepts) addFeatureConcept(concept.feature, concept.name);
  for (const relation of relations) {
    addFeatureConcept(relation.from, relation.to);
    addFeatureConcept(relation.to, relation.from);
  }

  const distillations = distillationIndex(data.distillations);
  const featureList = [...features.values()].map((feature) => {
    const record = featureRecords.get(feature.slug);
    return {
      ...feature,
      record,
      concepts: sortByLabel([...feature.concepts].map((name) => conceptByName.get(name))),
      decisions: sortByLabel(byType(records, 'decision').filter((decision) => decision.feature === feature.slug)),
      requirements: sortByLabel(byType(records, 'requirement').filter((item) => item.feature === feature.slug)),
      openQuestions: sortByLabel(byType(records, 'open_question').filter((item) => item.feature === feature.slug)),
      distillation: distillations.get(`features/${feature.slug}.md`) || null,
    };
  }).sort((left, right) => left.slug.localeCompare(right.slug));

  return {
    product: distillations.get('product.md') || null,
    concepts: concepts.map((concept) => ({
      ...concept,
      slug: slugFor(concept.name),
      distillation: distillations.get(`concepts/${slugFor(concept.name)}.md`) || null,
      relations: relations.filter((relation) => relation.from === concept.name || relation.to === concept.name),
      features: featureList.filter((feature) => feature.concepts.some((item) => item.name === concept.name)),
    })),
    features: featureList,
    relations,
    requirements: sortByLabel(byType(records, 'requirement').filter((item) => item.feature === 'global')),
    openQuestions: sortByLabel(byType(records, 'open_question').filter((item) => item.feature === 'global')),
    hasCapturedHistoryWithoutConcepts: hasCapturedHistoryWithoutConcepts(records),
  };
}

function conceptPath(concept) {
  return `/concepts/${encodeURIComponent(concept.slug || slugFor(concept.name))}`;
}

function featurePath(feature) {
  return `/features/${encodeURIComponent(feature.slug)}`;
}

function decisionPath(decision) {
  return `/decisions/${[decision.feature, decision.session, decision.where, decision.title]
    .map((part) => encodeURIComponent(part)).join('/')}`;
}

function link(href, label) {
  return `<a href="${escapeHtml(href)}">${escapeHtml(label)}</a>`;
}

function prose(content) {
  return content.trim() ? `<pre class="distillation-prose">${escapeHtml(content.trim())}</pre>` : '';
}

function diagramCaption(value) {
  return value && value.trim()
    ? value.trim()
    : 'Diagram supporting the surrounding written explanation.';
}

function isSupportedDiagram(source) {
  return /^(?:flowchart|graph)\s+(?:TD|TB|BT|LR|RL)\b/i.test(source.trim()) ||
    /^sequenceDiagram\b/i.test(source.trim());
}

function markdown(content) {
  const pattern = /\`\`\`mermaid[^\n]*\r?\n([\s\S]*?)\`\`\`(?:\r?\n(?:Diagram|Caption):[ \t]*(.+))?/gi;
  let cursor = 0;
  let match;
  let rendered = '';
  while ((match = pattern.exec(content))) {
    rendered += prose(content.slice(cursor, match.index));
    const source = match[1].trim();
    const caption = diagramCaption(match[2]);
    if (isSupportedDiagram(source)) {
      rendered += `<figure class="diagram" data-mermaid="${escapeHtml(encodeURIComponent(source))}"><div class="diagram-canvas" aria-hidden="true">Rendering diagram…</div><figcaption>${escapeHtml(caption)}</figcaption></figure>`;
    } else {
      rendered += `<aside class="diagram-unavailable" role="note"><strong>Diagram unavailable.</strong><p>${escapeHtml(caption)}</p></aside>`;
    }
    cursor = pattern.lastIndex;
  }
  return rendered + prose(content.slice(cursor));
}

function emptyState(message) {
  return `<p>${escapeHtml(message)}</p>`;
}

function topicClass(name) {
  let hash = 0;
  for (const character of name) hash = ((hash * 31) + character.charCodeAt(0)) >>> 0;
  return `topic-${hash % 6}`;
}

function topicNames(concepts) {
  return concepts.map((concept) => concept.name);
}

function metadata(record) {
  if (!record) return '';
  const date = record.ts ? `<span>Recorded <time datetime="${escapeHtml(record.ts)}">${escapeHtml(record.ts)}</time></span>` : '';
  const commit = record.commit
    ? `<code title="Commit ${escapeHtml(record.commit)}">${escapeHtml(record.commit === 'uncommitted' ? 'Uncommitted' : record.commit.slice(0, 7))}</code>`
    : '';
  return date || commit ? `<div class="record-meta">${date}${commit}</div>` : '';
}

function topicBadges(concepts, interactive = false) {
  if (!concepts.length) return '';
  const tag = interactive ? 'button' : 'span';
  return `<div class="topic-badges">${concepts.map((concept) => {
    const attributes = interactive
      ? ` type="button" data-topic-filter="${escapeHtml(concept.slug)}" aria-label="Filter by ${escapeHtml(concept.name)}"`
      : '';
    return `<${tag} class="topic-badge ${topicClass(concept.name)}"${attributes}>${escapeHtml(concept.name)}</${tag}>`;
  }).join('')}</div>`;
}

function filterBar(concepts) {
  if (!concepts.length) return '';
  return `<div class="topic-filter" aria-label="Filter by architectural concept" data-topic-filter-bar>
    <span class="filter-label">Filter by concept</span>
    <button type="button" class="filter-all" data-topic-filter="all" aria-pressed="true">All</button>
    ${concepts.map((concept) => `<button type="button" class="topic-badge ${topicClass(concept.name)}" data-topic-filter="${escapeHtml(concept.slug)}" aria-pressed="false">${escapeHtml(concept.name)}</button>`).join('')}
  </div>`;
}

function recordCard(item) {
  const topics = item.concepts || [];
  const topicData = topics.map((concept) => concept.slug).join(' ');
  const title = item.href ? link(item.href, item.title) : escapeHtml(item.title);
  return `<article class="record-card record-card--${escapeHtml(item.kind || 'record')}" data-topic-card data-topics="${escapeHtml(topicData)}">
    <div class="record-main">
      <div class="record-kicker">${escapeHtml(item.label || item.kind || 'Record')}</div>
      <h2>${title}</h2>
      ${item.summary ? `<p>${escapeHtml(item.summary)}</p>` : ''}
      ${topicBadges(topics, true)}
    </div>
    ${metadata(item.record)}
  </article>`;
}

function filterableCollection(concepts, items, emptyMessage) {
  if (!items.length) return emptyState(emptyMessage);
  return `<section class="record-collection" data-topic-collection>
    ${filterBar(concepts)}
    <p class="filter-status" data-topic-status aria-live="polite"></p>
    <div class="record-list">${items.map(recordCard).join('')}</div>
  </section>`;
}

function featureTopics(navigation, feature) {
  return feature ? feature.concepts : [];
}

function recordTopics(navigation, record) {
  if (record.type === 'concept') {
    const concept = navigation.concepts.find((item) => item.name === record.name);
    return concept ? [concept] : [];
  }
  const feature = navigation.features.find((item) => item.slug === record.feature || item.slug === record.slug);
  return featureTopics(navigation, feature);
}

function activityItem(navigation, record) {
  const concepts = recordTopics(navigation, record);
  if (record.type === 'concept') return {
    kind: 'concept', label: 'Concept', title: record.name, summary: record.problem,
    href: conceptPath(navigation.concepts.find((item) => item.name === record.name)), record, concepts,
  };
  if (record.type === 'feature') return {
    kind: 'feature', label: 'Feature', title: record.slug, summary: record.intent,
    href: featurePath(navigation.features.find((item) => item.slug === record.slug)), record, concepts,
  };
  if (record.type === 'decision') return {
    kind: 'decision', label: 'Decision', title: record.title, summary: record.why,
    href: decisionPath(record), record, concepts,
  };
  if (record.type === 'requirement') return {
    kind: 'requirement', label: 'Requirement', title: record.gap, summary: record.answer,
    href: record.feature === 'global' ? '/features' : featurePath(navigation.features.find((item) => item.slug === record.feature)), record, concepts,
  };
  if (record.type === 'open_question') return {
    kind: 'open-question', label: 'Open question', title: record.gap, summary: record.why_it_matters,
    href: record.feature === 'global' ? '/features' : featurePath(navigation.features.find((item) => item.slug === record.feature)), record, concepts,
  };
  return null;
}

function sortByRecorded(items) {
  return [...items].sort((left, right) => {
    const leftDate = left.record && left.record.ts || '';
    const rightDate = right.record && right.record.ts || '';
    return rightDate.localeCompare(leftDate) || left.title.localeCompare(right.title);
  });
}

function layout(data, title, body, crumbs = []) {
  const storeWarning = data.store.errors.length
    ? `<p role="alert">${data.store.errors.length} unreadable store record(s) were skipped.</p>`
    : '';
  const breadcrumb = crumbs.length
    ? `<nav aria-label="Breadcrumb"><ol>${crumbs.map((crumb) => `<li>${crumb.href ? link(crumb.href, crumb.label) : escapeHtml(crumb.label)}</li>`).join('')}</ol></nav>`
    : '';
  return `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(title)} — ${escapeHtml(data.project)} — FluencyLoop</title><link rel="stylesheet" href="/assets/site.css"></head>
  <body data-depth="${Math.min(crumbs.length, 3)}">
    <main id="content" tabindex="-1">
      <nav aria-label="Primary"><a class="site-mark" href="/">FL</a><span class="project-name">${escapeHtml(data.project)}</span><span class="nav-links">${link('/', 'Overview')}${link('/concepts', 'Concepts')}${link('/features', 'Features')}</span><button type="button" data-theme-toggle aria-label="Switch theme" aria-pressed="false">Theme</button></nav>
      ${breadcrumb}
      ${storeWarning}
      ${body}
    </main>
    <script src="/assets/site.js" defer></script>
  </body>
</html>`;
}

function renderConstraints(requirements, openQuestions) {
  const cards = [
    ...requirements.map((record) => ({
      kind: 'requirement', label: 'Requirement', title: record.gap, summary: `Answer: ${record.answer}. Consequence: ${record.consequence}`, record, concepts: [],
    })),
    ...openQuestions.map((record) => ({
      kind: 'open-question', label: 'Open question', title: record.gap, summary: record.why_it_matters, record, concepts: [],
    })),
  ];
  return cards.length
    ? `<section class="detail-section"><h2>Constraints</h2><div class="record-list">${cards.map(recordCard).join('')}</div></section>`
    : '';
}

function renderProduct(data) {
  const navigation = data.navigation;
  const overview = navigation.product
    ? markdown(navigation.product.content)
    : emptyState(navigation.hasCapturedHistoryWithoutConcepts
      ? 'No product overview has been distilled yet. Ask your assistant to "fluencyloop backfill" the imported history to synthesize one, or it will appear automatically once a feature materially changes the product shape.'
      : 'No product overview has been distilled yet. It will appear when a feature materially changes the product shape.');
  const activity = sortByRecorded(data.store.records.map((record) => activityItem(navigation, record)).filter(Boolean));
  return layout(data, 'Product overview', `
    <header><p class="eyebrow">Project knowledge</p><h1>${escapeHtml(data.project)}</h1><p>Architecture, feature deltas, and the decisions that shaped them.</p></header>
    <section class="overview-prose"><h2>Technical overview</h2>${overview}</section>
    <div class="section-heading"><p class="eyebrow">Project record</p><h2>What changed</h2></div>
    ${filterableCollection(navigation.concepts, activity, 'No project records have been captured yet.')}
  `);
}

function renderConceptList(data) {
  const concepts = data.navigation.concepts.map((concept) => ({
    kind: 'concept', label: 'Concept', title: concept.name, summary: concept.problem,
    href: conceptPath(concept), record: concept, concepts: [concept],
  }));
  const relationships = data.navigation.relations.map((relation) => {
    const endpoints = [relation.from, relation.to].map((name) => data.navigation.concepts.find((concept) => concept.name === name)).filter(Boolean);
    return {
      kind: 'relation', label: 'Relationship', title: `${relation.from} ${relation.kind} ${relation.to}`,
      summary: 'A recorded architectural connection.', record: relation, concepts: endpoints,
    };
  });
  return layout(data, 'Architectural concepts', `
    <header><p class="eyebrow">Architecture</p><h1>Architectural concepts</h1><p>Concepts are the stable vocabulary that links individual feature work together.</p></header>
    <div class="section-heading"><p class="eyebrow">Concept map</p><h2>Concepts and relationships</h2></div>
    ${filterableCollection(data.navigation.concepts, sortByRecorded([...concepts, ...relationships]), data.navigation.hasCapturedHistoryWithoutConcepts
      ? 'No architectural concepts have been recorded yet. This project has imported decision history — ask your assistant to "fluencyloop backfill" it to synthesize concepts, or capture one directly with fluencyloop concept.'
      : 'No architectural concepts have been recorded yet. The product overview remains available while the store is empty.')}
  `, [
    { href: '/', label: 'Product overview' }, { label: 'Architectural concepts' },
  ]);
}

function endpointLink(navigation, endpoint) {
  const concept = navigation.concepts.find((item) => item.name === endpoint);
  if (concept) return link(conceptPath(concept), endpoint);
  const feature = navigation.features.find((item) => item.slug === endpoint);
  if (feature) return link(featurePath(feature), endpoint);
  return escapeHtml(endpoint);
}

function renderConcept(data, concept) {
  const realizedBy = String(concept.realized_by || '').split(/\r?\n/).filter(Boolean);
  const explanation = concept.distillation
    ? markdown(concept.distillation.content)
    : emptyState('No concept explanation has been distilled yet.');
  return layout(data, concept.name, `
    <header><p class="eyebrow">Concept</p><h1>${escapeHtml(concept.name)}</h1>${metadata(concept)}${topicBadges([concept])}</header>
    <section class="detail-section"><h2>Problem in this product</h2><p>${escapeHtml(concept.problem)}</p><h2>How it works</h2><p>${escapeHtml(concept.how)}</p>
    <h2>Realized by</h2>${realizedBy.length ? `<ul class="detail-list">${realizedBy.map((item) => `<li>${escapeHtml(item)}</li>`).join('')}</ul>` : emptyState('No implementation area was recorded.')}</section>
    <section class="detail-section"><h2>Concept explanation</h2>${explanation}</section>
    <section class="detail-section"><h2>Relationships</h2>${concept.relations.length ? `<div class="record-list">${concept.relations.map((relation) => recordCard({ kind: 'relation', label: 'Relationship', title: `${relation.from} ${relation.kind} ${relation.to}`, summary: 'A recorded architectural connection.', record: relation, concepts: [concept] })).join('')}</div>` : emptyState('This concept has no recorded relationships yet.')}</section>
    <section class="detail-section"><h2>Features that change this concept</h2>${concept.features.length ? `<div class="record-list">${concept.features.map((feature) => recordCard({ kind: 'feature', label: 'Feature', title: feature.slug, summary: feature.record && feature.record.intent, href: featurePath(feature), record: feature.record, concepts: feature.concepts })).join('')}</div>` : emptyState('No feature is currently linked to this concept.')}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/concepts', label: 'Architectural concepts' }, { label: concept.name }]);
}

function renderFeatureList(data) {
  const features = data.navigation.features.map((feature) => ({
    kind: 'feature', label: 'Feature', title: feature.slug, summary: feature.record && feature.record.intent,
    href: featurePath(feature), record: feature.record, concepts: feature.concepts,
  }));
  return layout(data, 'Features', `
    <header><p class="eyebrow">Product changes</p><h1>Features as deltas</h1><p>Each feature is a bounded change, connected to the concepts it moves.</p></header>
    ${filterableCollection(data.navigation.concepts, sortByRecorded(features), 'No features have been recorded yet.')}
  `, [
    { href: '/', label: 'Product overview' }, { label: 'Features' },
  ]);
}

function renderFeature(data, feature) {
  const delta = feature.distillation
    ? markdown(feature.distillation.content)
    : emptyState('No feature delta has been distilled yet.');
  return layout(data, feature.slug, `
    <header><p class="eyebrow">Feature</p><h1>${escapeHtml(feature.slug)}</h1>${feature.record && feature.record.intent ? `<p>${escapeHtml(feature.record.intent)}</p>` : ''}${metadata(feature.record)}${topicBadges(feature.concepts)}</header>
    <section class="detail-section"><h2>Feature delta</h2>${delta}</section>
    <section class="detail-section"><h2>Concepts changed</h2>${feature.concepts.length ? `<div class="record-list">${feature.concepts.map((concept) => recordCard({ kind: 'concept', label: 'Concept', title: concept.name, summary: concept.problem, href: conceptPath(concept), record: concept, concepts: [concept] })).join('')}</div>` : emptyState('This feature has no recorded concept links yet.')}</section>
    ${renderConstraints(feature.requirements, feature.openQuestions)}
    <section class="detail-section"><h2>Decisions</h2>${feature.decisions.length ? `<div class="record-list">${sortByRecorded(feature.decisions.map((decision) => ({ kind: 'decision', label: 'Decision', title: decision.title, summary: decision.why, href: decisionPath(decision), record: decision, concepts: feature.concepts }))).map(recordCard).join('')}</div>` : emptyState('No decisions have been recorded for this feature yet.')}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/features', label: 'Features' }, { label: feature.slug }]);
}

function renderDecision(data, feature, decision) {
  return layout(data, decision.title, `
    <header><p class="eyebrow">Decision in ${link(featurePath(feature), feature.slug)}</p><h1>${escapeHtml(decision.title)}</h1>${metadata(decision)}${topicBadges(feature.concepts)}</header>
    <section class="detail-section"><h2>Why</h2><p>${escapeHtml(decision.why)}</p>
    ${decision.alternative ? `<h2>Alternative rejected</h2><p>${escapeHtml(decision.alternative)}</p>` : ''}
    <h2>Where</h2><p>${escapeHtml(decision.where)}</p></section>
    <section class="detail-section"><h2>Concepts served</h2>${feature.concepts.length ? `<div class="record-list">${feature.concepts.map((concept) => recordCard({ kind: 'concept', label: 'Concept', title: concept.name, summary: concept.problem, href: conceptPath(concept), record: concept, concepts: [concept] })).join('')}</div>` : emptyState('No concept link was recorded for this feature.')}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/features', label: 'Features' }, { href: featurePath(feature), label: feature.slug }, { label: decision.title }]);
}

function send(response, status, contentType, body) {
  response.writeHead(status, { 'Content-Type': contentType, 'Cache-Control': 'no-store' });
  response.end(body);
}

function createServer(root) {
  return http.createServer((request, response) => {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      send(response, 405, 'text/plain; charset=utf-8', 'Method not allowed\n');
      return;
    }
    try {
      const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
      if (pathname === '/health') {
        send(response, 200, 'application/json; charset=utf-8', request.method === 'HEAD' ? '' : '{"status":"ok"}\n');
        return;
      }
      const asset = SITE_ASSETS[pathname];
      if (asset) {
        const source = request.method === 'HEAD' ? '' : fs.readFileSync(path.join(__dirname, asset.file), asset.encoding ? 'utf8' : undefined);
        const body = asset.encoding ? Buffer.from(source, asset.encoding) : source;
        send(response, 200, asset.contentType, body);
        return;
      }
      const data = readSiteData(root);
      if (pathname === '/api/site-data') {
        send(response, 200, 'application/json; charset=utf-8', request.method === 'HEAD' ? '' : `${JSON.stringify(data)}\n`);
        return;
      }
      const segments = pathname.split('/').filter(Boolean).map((segment) => decodeURIComponent(segment));
      let page = null;
      if (segments.length === 0) {
        page = renderProduct(data);
      } else if (segments.length === 1 && segments[0] === 'concepts') {
        page = renderConceptList(data);
      } else if (segments.length === 2 && segments[0] === 'concepts') {
        const concept = data.navigation.concepts.find((item) => item.slug === segments[1]);
        if (concept) page = renderConcept(data, concept);
      } else if (segments.length === 1 && segments[0] === 'features') {
        page = renderFeatureList(data);
      } else if (segments.length === 2 && segments[0] === 'features') {
        const feature = data.navigation.features.find((item) => item.slug === segments[1]);
        if (feature) page = renderFeature(data, feature);
      } else if (segments.length === 5 && segments[0] === 'decisions') {
        const feature = data.navigation.features.find((item) => item.slug === segments[1]);
        const decision = feature && feature.decisions.find((item) =>
          item.session === segments[2] && item.where === segments[3] && item.title === segments[4]);
        if (feature && decision) page = renderDecision(data, feature, decision);
      }
      if (page) {
        send(response, 200, 'text/html; charset=utf-8', request.method === 'HEAD' ? '' : page);
        return;
      }
      send(response, 404, 'text/plain; charset=utf-8', 'Not found\n');
    } catch (error) {
      send(response, 500, 'text/plain; charset=utf-8', `Could not read FluencyLoop data: ${error.message}\n`);
    }
  });
}

function listen(server, port) {
  return new Promise((resolve, reject) => {
    const onError = (error) => {
      server.removeListener('listening', onListening);
      reject(error);
    };
    const onListening = () => {
      server.removeListener('error', onError);
      resolve();
    };
    server.once('error', onError);
    server.once('listening', onListening);
    server.listen({ host: '127.0.0.1', port });
  });
}

async function start(root, requestedPort) {
  let port = requestedPort;
  while (port <= 65535) {
    const server = createServer(root);
    try {
      await listen(server, port);
      const address = server.address();
      process.stdout.write(`FluencyLoop site: http://127.0.0.1:${address.port}\n`);
      const stop = () => server.close(() => process.exit(0));
      process.once('SIGINT', stop);
      process.once('SIGTERM', stop);
      return;
    } catch (error) {
      if (error.code === 'EADDRINUSE' && port !== 0) {
        port += 1;
        continue;
      }
      throw error;
    }
  }
  throw new Error(`no free loopback port found from ${requestedPort} through 65535`);
}

let options;
try {
  options = parseArgs(process.argv.slice(2));
} catch (error) {
  usage(error.message);
}
if (options) {
  start(options.root, options.port).catch((error) => {
    process.stderr.write(`Could not start FluencyLoop site: ${error.message}\n`);
    process.exitCode = 1;
  });
}
