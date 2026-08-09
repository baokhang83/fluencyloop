#!/usr/bin/env node
'use strict';

// The local FluencyLoop reader. It deliberately has no build step and no dependencies: every
// response reads the project's current store, distillations, and local calibration profile.

const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const DEFAULT_PORT = 4173;
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

function markdown(content) {
  return `<pre>${escapeHtml(content)}</pre>`;
}

function emptyState(message) {
  return `<p>${escapeHtml(message)}</p>`;
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
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(title)} — ${escapeHtml(data.project)} — FluencyLoop</title></head>
  <body>
    <main>
      <nav aria-label="Primary">${link('/', 'Product overview')} · ${link('/concepts', 'Architectural concepts')} · ${link('/features', 'Features')}</nav>
      ${breadcrumb}
      ${storeWarning}
      ${body}
    </main>
  </body>
</html>`;
}

function renderConstraints(requirements, openQuestions) {
  const answered = requirements.length
    ? `<ul>${requirements.map((item) => `<li><strong>${escapeHtml(item.gap)}</strong><br>Answer: ${escapeHtml(item.answer)}<br>Consequence: ${escapeHtml(item.consequence)}</li>`).join('')}</ul>`
    : emptyState('No answered requirements were recorded at this level.');
  const open = openQuestions.length
    ? `<ul>${openQuestions.map((item) => `<li><strong>${escapeHtml(item.gap)}</strong><br>Why it matters: ${escapeHtml(item.why_it_matters)}</li>`).join('')}</ul>`
    : emptyState('No open questions were recorded at this level.');
  return `<section><h2>Requirements</h2>${answered}<h2>Open questions</h2>${open}</section>`;
}

function renderProduct(data) {
  const navigation = data.navigation;
  const concepts = navigation.concepts.length
    ? `<ul>${navigation.concepts.map((concept) => `<li>${link(conceptPath(concept), concept.name)} — ${escapeHtml(concept.problem)}</li>`).join('')}</ul>`
    : emptyState('No architectural concepts have been recorded yet. Capture one with fluencyloop concept.');
  const features = navigation.features.length
    ? `<ul>${navigation.features.map((feature) => `<li>${link(featurePath(feature), feature.slug)}${feature.record && feature.record.intent ? ` — ${escapeHtml(feature.record.intent)}` : ''}</li>`).join('')}</ul>`
    : emptyState('No features have been recorded yet.');
  const overview = navigation.product
    ? markdown(navigation.product.content)
    : emptyState('No product overview has been distilled yet. It will appear when a feature materially changes the product shape.');
  const distillations = data.distillations.length
    ? `<ul>${data.distillations.map((item) => `<li>${escapeHtml(item.path)}</li>`).join('')}</ul>`
    : emptyState('No distillations have been written yet.');
  return layout(data, 'Product overview', `
    <header><h1>${escapeHtml(data.project)}</h1><p>Product overview</p></header>
    <section><h2>Technical overview</h2>${overview}</section>
    <section><h2>Architectural concepts</h2>${concepts}</section>
    <section><h2>Features as deltas</h2>${features}</section>
    <section><h2>Initiative constraints</h2>${renderConstraints(navigation.requirements, navigation.openQuestions)}</section>
    <section><h2>Available distillations</h2>${distillations}</section>
  `);
}

function renderConceptList(data) {
  const concepts = data.navigation.concepts.length
    ? `<ul>${data.navigation.concepts.map((concept) => `<li>${link(conceptPath(concept), concept.name)} — ${escapeHtml(concept.problem)}</li>`).join('')}</ul>`
    : emptyState('No architectural concepts have been recorded yet. The product overview remains available while the store is empty.');
  const relationships = data.navigation.relations.length
    ? `<ul>${data.navigation.relations.map((relation) => `<li>${endpointLink(data.navigation, relation.from)} — ${escapeHtml(relation.kind)} &rarr; ${endpointLink(data.navigation, relation.to)}</li>`).join('')}</ul>`
    : emptyState('No relationships have been recorded yet.');
  return layout(data, 'Architectural concepts', `<h1>Architectural concepts</h1><section><h2>Concepts</h2>${concepts}</section><section><h2>Relationship graph</h2>${relationships}</section>`, [
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
  const relationships = concept.relations.length
    ? `<ul>${concept.relations.map((relation) => `<li>${endpointLink(data.navigation, relation.from)} — ${escapeHtml(relation.kind)} &rarr; ${endpointLink(data.navigation, relation.to)}</li>`).join('')}</ul>`
    : emptyState('This concept has no recorded relationships yet.');
  const features = concept.features.length
    ? `<ul>${concept.features.map((feature) => `<li>${link(featurePath(feature), feature.slug)}</li>`).join('')}</ul>`
    : emptyState('No feature is currently linked to this concept.');
  const explanation = concept.distillation
    ? markdown(concept.distillation.content)
    : emptyState('No concept explanation has been distilled yet.');
  return layout(data, concept.name, `
    <h1>${escapeHtml(concept.name)}</h1>
    <section><h2>Problem in this product</h2><p>${escapeHtml(concept.problem)}</p><h2>How it works</h2><p>${escapeHtml(concept.how)}</p>
    <h2>Realized by</h2>${realizedBy.length ? `<ul>${realizedBy.map((item) => `<li>${escapeHtml(item)}</li>`).join('')}</ul>` : emptyState('No implementation area was recorded.')}</section>
    <section><h2>Concept explanation</h2>${explanation}</section>
    <section><h2>Relationships</h2>${relationships}</section>
    <section><h2>Features that change this concept</h2>${features}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/concepts', label: 'Architectural concepts' }, { label: concept.name }]);
}

function renderFeatureList(data) {
  const features = data.navigation.features.length
    ? `<ul>${data.navigation.features.map((feature) => `<li>${link(featurePath(feature), feature.slug)}${feature.record && feature.record.intent ? ` — ${escapeHtml(feature.record.intent)}` : ''}</li>`).join('')}</ul>`
    : emptyState('No features have been recorded yet.');
  return layout(data, 'Features', `<h1>Features as deltas</h1>${features}`, [
    { href: '/', label: 'Product overview' }, { label: 'Features' },
  ]);
}

function renderFeature(data, feature) {
  const concepts = feature.concepts.length
    ? `<ul>${feature.concepts.map((concept) => `<li>${link(conceptPath(concept), concept.name)} — ${escapeHtml(concept.problem)}</li>`).join('')}</ul>`
    : emptyState('This feature has no recorded concept links yet.');
  const decisions = feature.decisions.length
    ? `<ul>${feature.decisions.map((decision) => `<li>${link(decisionPath(decision), decision.title)} — ${escapeHtml(decision.why)}</li>`).join('')}</ul>`
    : emptyState('No decisions have been recorded for this feature yet.');
  const delta = feature.distillation
    ? markdown(feature.distillation.content)
    : emptyState('No feature delta has been distilled yet.');
  return layout(data, feature.slug, `
    <h1>${escapeHtml(feature.slug)}</h1>
    ${feature.record && feature.record.intent ? `<p>${escapeHtml(feature.record.intent)}</p>` : ''}
    <section><h2>Feature delta</h2>${delta}</section>
    <section><h2>Concepts changed</h2>${concepts}</section>
    <section><h2>Constraints for this feature</h2>${renderConstraints(feature.requirements, feature.openQuestions)}</section>
    <section><h2>Decisions</h2>${decisions}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/features', label: 'Features' }, { label: feature.slug }]);
}

function renderDecision(data, feature, decision) {
  const concepts = feature.concepts.length
    ? `<ul>${feature.concepts.map((concept) => `<li>${link(conceptPath(concept), concept.name)}</li>`).join('')}</ul>`
    : emptyState('No concept link was recorded for this feature.');
  return layout(data, decision.title, `
    <h1>${escapeHtml(decision.title)}</h1>
    <p>Decision in ${link(featurePath(feature), feature.slug)}.</p>
    <section><h2>Why</h2><p>${escapeHtml(decision.why)}</p>
    ${decision.alternative ? `<h2>Alternative rejected</h2><p>${escapeHtml(decision.alternative)}</p>` : ''}
    <h2>Where</h2><p>${escapeHtml(decision.where)}</p></section>
    <section><h2>Concepts served</h2>${concepts}</section>
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
