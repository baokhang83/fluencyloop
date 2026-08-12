#!/usr/bin/env node
'use strict';

// The local FluencyLoop reader. It deliberately has no build step and no dependencies: every
// response reads the project's current store, distillations, and local calibration profile.

const http = require('node:http');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function positiveMillisecondsFromEnvironment(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

const DEFAULT_PORT = 4173;
const MANAGED_DEFAULT_PORT = 44444;
const MANAGED_IDLE_MS = positiveMillisecondsFromEnvironment('FLUENCYLOOP_SITE_IDLE_MS', 2 * 60 * 60 * 1000);
const MANAGED_IDLE_CHECK_MS = positiveMillisecondsFromEnvironment('FLUENCYLOOP_SITE_IDLE_CHECK_MS', 60 * 1000);
const MANAGED_TOUCH_INTERVAL_MS = 30 * 1000;
// Keep the managed child on the same Windows-safe cold-start budget as the foreground-site test.
// This only affects an unavailable child; normal startup returns after its first health probe.
const MANAGED_START_TIMEOUT_MS = 30_000;
const SITE_VERSION = fs.existsSync(path.join(__dirname, '..', 'VERSION'))
  ? fs.readFileSync(path.join(__dirname, '..', 'VERSION'), 'utf8').trim()
  : 'unknown';
// No font files: the site sets type in the reader's own interface font. That keeps the reader
// byte-for-byte local without shipping a typeface, and matches the register of the tools the
// project record sits beside.
const SITE_ASSETS = {
  '/assets/site.css': { file: 'site.css', contentType: 'text/css; charset=utf-8' },
  '/assets/site.js': { file: 'site.js', contentType: 'application/javascript; charset=utf-8' },
};
// How many tag colours the palette cycles through before repeating.
const TAG_TONES = 8;
// A broad, cross-cutting feature can inherit many tags from its concepts. Catalogue rows should
// remain skimmable; its detail page still shows the complete vocabulary.
const CATALOG_TAG_LIMIT = 4;
const IDENTITY_FIELDS = {
  feature: ['slug'],
  session: ['feature', 'slug'],
  decision: ['feature', 'session', 'where', 'title'],
  component: ['feature', 'session', 'name'],
  condition: ['feature', 'session', 'subject'],
  concept: ['name'],
  relation: ['from', 'to', 'kind'],
  record_explanation: ['record'],
  principle: ['number'],
  requirement: ['feature', 'gap'],
  open_question: ['feature', 'gap'],
};

function usage(message) {
  if (message) process.stderr.write(`Error: ${message}\n`);
  process.stderr.write('Usage: fluencyloop site [--port <0-65535>] [--ensure [--open|--open-once]|--status|--stop] [--json]\n');
  process.exitCode = 1;
}

function parseArgs(argv) {
  const options = {
    root: '', port: DEFAULT_PORT, portSpecified: false, ensure: false, status: false, stop: false, open: false, openOnce: false, json: false,
    sessionStart: '', sessionEnd: '',
    managedState: '', managedId: '', managedStartup: '', managedSession: '',
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--root' || arg === '--port' || arg === '--managed-state' || arg === '--managed-id' || arg === '--managed-startup'
      || arg === '--managed-session' || arg === '--session-start' || arg === '--session-end') {
      const value = argv[index + 1];
      if (!value) throw new Error(`${arg} needs a value`);
      index += 1;
      if (arg === '--root') options.root = path.resolve(value);
      else if (arg === '--managed-session' || arg === '--session-start' || arg === '--session-end') {
        if (!/^[A-Za-z0-9._-]{1,256}$/.test(value)) throw new Error(`${arg} needs a safe session identifier`);
        if (arg === '--session-start') options.sessionStart = value;
        else if (arg === '--session-end') options.sessionEnd = value;
        else options.managedSession = value;
      }
      else if (arg === '--managed-state') options.managedState = path.resolve(value);
      else if (arg === '--managed-id') options.managedId = value;
      else if (arg === '--managed-startup') options.managedStartup = value;
      else {
        if (!/^\d+$/.test(value)) throw new Error('--port must be an integer from 0 to 65535');
        options.port = Number(value);
        options.portSpecified = true;
        if (options.port > 65535) throw new Error('--port must be an integer from 0 to 65535');
      }
    } else if (arg === '--ensure') options.ensure = true;
    else if (arg === '--open') options.open = true;
    else if (arg === '--open-once') options.openOnce = true;
    else if (arg === '--status') options.status = true;
    else if (arg === '--stop') options.stop = true;
    else if (arg === '--json') options.json = true;
    else {
      throw new Error(`unknown option: ${arg}`);
    }
  }
  if (!options.root) throw new Error('the project root is required');
  if ([options.ensure, options.status, options.stop, options.sessionStart, options.sessionEnd].filter(Boolean).length > 1) {
    throw new Error('choose only one lifecycle action');
  }
  if (options.open && options.openOnce) throw new Error('choose either --open or --open-once');
  if ((options.open || options.openOnce) && !options.ensure) throw new Error('--open and --open-once require --ensure');
  return options;
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function canonicalRoot(root) {
  return fs.realpathSync(root);
}

function fluencyHome() {
  return process.env.FLUENCYLOOP_HOME
    ? path.resolve(process.env.FLUENCYLOOP_HOME)
    : path.join(os.homedir(), '.fluencyloop');
}

function managedPaths(root) {
  const id = crypto.createHash('sha256').update(root).digest('hex').slice(0, 32);
  const directory = path.join(fluencyHome(), 'sites');
  return {
    id,
    directory,
    state: path.join(directory, id + '.json'),
    lock: path.join(directory, id + '.lock'),
    log: path.join(directory, id + '.log'),
  };
}

function ensureManagedDirectory(paths) {
  fs.mkdirSync(paths.directory, { recursive: true, mode: 0o700 });
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return null;
  }
}

function writeJsonAtomically(file, value) {
  const temporary = file + '.' + process.pid + '.' + crypto.randomUUID() + '.tmp';
  fs.writeFileSync(temporary, JSON.stringify(value) + '\n', { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(temporary, file);
}

function removeFile(file) {
  try {
    fs.unlinkSync(file);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

async function withSiteLock(paths, action) {
  ensureManagedDirectory(paths);
  const deadline = Date.now() + MANAGED_START_TIMEOUT_MS;
  let descriptor;
  while (descriptor === undefined && Date.now() < deadline) {
    try {
      descriptor = fs.openSync(paths.lock, 'wx', 0o600);
      fs.writeFileSync(descriptor, String(process.pid) + '\n', 'utf8');
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
      try {
        const age = Date.now() - fs.statSync(paths.lock).mtimeMs;
        if (age > MANAGED_START_TIMEOUT_MS) removeFile(paths.lock);
      } catch (_) {
        // Another manager may have completed while this process was checking the lock.
      }
      await sleep(50);
    }
  }
  if (descriptor === undefined) throw new Error('timed out waiting for the managed site lock');
  try {
    return await action();
  } finally {
    fs.closeSync(descriptor);
    removeFile(paths.lock);
  }
}

function metadataFor(root, paths) {
  const metadata = readJson(paths.state);
  if (!metadata || metadata.id !== paths.id || metadata.root !== root || !Number.isInteger(metadata.pid)
    || !Number.isInteger(metadata.port) || typeof metadata.url !== 'string') {
    return null;
  }
  return metadata;
}

function probeSite(metadata) {
  return new Promise((resolve) => {
    let settled = false;
    const finish = (healthy) => {
      if (!settled) {
        settled = true;
        resolve(healthy);
      }
    };
    let target;
    try {
      target = new URL(metadata.url + '/health');
    } catch (_) {
      finish(false);
      return;
    }
    const request = http.get({
      hostname: target.hostname,
      port: target.port,
      path: target.pathname,
      timeout: 750,
    }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => {
        try {
          const health = JSON.parse(body);
          finish(response.statusCode === 200 && health.status === 'ok' && health.site_id === metadata.id);
        } catch (_) {
          finish(false);
        }
      });
    });
    request.once('timeout', () => request.destroy());
    request.once('error', () => finish(false));
  });
}

function resultFor(metadata, extra = {}) {
  return {
    available: true,
    running: Boolean(metadata),
    url: metadata ? metadata.url : null,
    port: metadata ? metadata.port : null,
    session_count: metadata && metadata.sessions ? Object.keys(metadata.sessions).length : 0,
    ...extra,
  };
}

function recordSession(metadata, sessionId) {
  if (!sessionId) return;
  if (!metadata.sessions || typeof metadata.sessions !== 'object' || Array.isArray(metadata.sessions)) metadata.sessions = {};
  metadata.sessions[sessionId] = Date.now();
}

function hasActiveSessions(metadata) {
  return Boolean(metadata && metadata.sessions && typeof metadata.sessions === 'object'
    && !Array.isArray(metadata.sessions) && Object.keys(metadata.sessions).length > 0);
}

async function currentManagedSite(root, paths) {
  const metadata = metadataFor(root, paths);
  if (!metadata) return null;
  if (await probeSite(metadata)) return metadata;
  removeFile(paths.state);
  return null;
}

function touchManagedActivity(managed) {
  if (!managed || !managed.state || !managed.id) return;
  const metadata = readJson(managed.state);
  if (!metadata || metadata.id !== managed.id || metadata.pid !== process.pid) return;
  const now = Date.now();
  if (now - Number(metadata.last_activity || 0) < MANAGED_TOUCH_INTERVAL_MS) return;
  metadata.last_activity = now;
  writeJsonAtomically(managed.state, metadata);
}

function removeManagedState(managed) {
  if (!managed || !managed.state) return;
  const metadata = readJson(managed.state);
  if (metadata && metadata.id === managed.id && metadata.pid === process.pid) removeFile(managed.state);
}

async function stopManagedSite(root, paths) {
  return withSiteLock(paths, async () => {
    const metadata = await currentManagedSite(root, paths);
    if (!metadata) return resultFor(null, { stopped: false });
    try {
      process.kill(metadata.pid, 'SIGTERM');
    } catch (error) {
      if (error.code !== 'ESRCH') throw error;
    }
    const deadline = Date.now() + MANAGED_START_TIMEOUT_MS;
    while (Date.now() < deadline) {
      if (!(await probeSite(metadata))) break;
      await sleep(50);
    }
    if (!(await probeSite(metadata))) {
      removeFile(paths.state);
      return resultFor(null, { stopped: true });
    }
    throw new Error('managed site did not stop before the timeout');
  });
}

function spawnManagedSite(root, paths, requestedPort, sessionId = '') {
  const startup = crypto.randomUUID();
  const output = fs.openSync(paths.log, 'a', 0o600);
  const childArgs = [
    __filename,
    '--root', root,
    '--port', String(requestedPort),
    '--managed-state', paths.state,
    '--managed-id', paths.id,
    '--managed-startup', startup,
  ];
  // The child must own the first lease before its idle timer starts. Otherwise a slow parent can
  // observe a healthy server after an aggressively configured idle timeout has already stopped it.
  if (sessionId) childArgs.push('--managed-session', sessionId);
  const child = childProcess.spawn(process.execPath, childArgs, {
    detached: true,
    stdio: ['ignore', output, output],
  });
  child.unref();
  fs.closeSync(output);
  return startup;
}

async function ensureManagedSite(root, paths, requestedPort, sessionId = '') {
  return withSiteLock(paths, async () => {
    let metadata = await currentManagedSite(root, paths);
    if (metadata && metadata.version === SITE_VERSION) {
      recordSession(metadata, sessionId);
      metadata.last_activity = Date.now();
      writeJsonAtomically(paths.state, metadata);
      return resultFor(metadata, { reused: true });
    }
    if (metadata) {
      try {
        process.kill(metadata.pid, 'SIGTERM');
      } catch (error) {
        if (error.code !== 'ESRCH') throw error;
      }
      const deadline = Date.now() + MANAGED_START_TIMEOUT_MS;
      while (Date.now() < deadline && await probeSite(metadata)) await sleep(50);
      if (await probeSite(metadata)) throw new Error('managed site did not stop before the timeout');
      removeFile(paths.state);
    }
    const startup = spawnManagedSite(root, paths, requestedPort, sessionId);
    const deadline = Date.now() + MANAGED_START_TIMEOUT_MS;
    while (Date.now() < deadline) {
      metadata = metadataFor(root, paths);
      if (metadata && metadata.startup === startup && await probeSite(metadata)) {
        recordSession(metadata, sessionId);
        writeJsonAtomically(paths.state, metadata);
        return resultFor(metadata, { reused: false });
      }
      await sleep(50);
    }
    throw new Error('managed site did not start before the timeout');
  });
}

async function releaseManagedSession(root, paths, sessionId) {
  return withSiteLock(paths, async () => {
    const metadata = await currentManagedSite(root, paths);
    if (!metadata) return resultFor(null, { released: false });
    if (metadata.sessions && typeof metadata.sessions === 'object' && !Array.isArray(metadata.sessions)) {
      delete metadata.sessions[sessionId];
    }
    // The final lease release begins the regular idle countdown, rather than making the reader
    // disappear the moment an agent closes a session.
    metadata.last_activity = Date.now();
    writeJsonAtomically(paths.state, metadata);
    return resultFor(metadata, { released: true });
  });
}

function printManagedResult(result, json) {
  if (json) {
    process.stdout.write(JSON.stringify(result) + '\n');
    return;
  }
  if (result.running) process.stdout.write('FluencyLoop site: ' + result.url + '\n');
  else process.stdout.write('FluencyLoop site is not running.\n');
}

// Open only a loopback URL that this process just ensured. The platform opener receives the URL
// as a literal argument, never as a shell fragment, so project data cannot become a command.
function openLocalBrowser(url) {
  let command;
  let args;
  if (process.platform === 'darwin') {
    command = 'open'; args = [url];
  } else if (process.platform === 'win32') {
    command = 'cmd.exe'; args = ['/c', 'start', '', url];
  } else {
    command = 'xdg-open'; args = [url];
  }
  try {
    const opener = childProcess.spawn(command, args, { detached: true, stdio: 'ignore' });
    opener.once('error', () => {});
    opener.unref();
    return true;
  } catch (_) {
    return false;
  }
}

// Automated workflow entries may each request an opening. Persist the first successful request
// with the managed reader so a plan -> feature -> feature sequence keeps one useful browser tab.
// A stopped reader receives fresh metadata and can open again when it is started next.
async function openManagedBrowserOnce(root, paths) {
  return withSiteLock(paths, async () => {
    const metadata = await currentManagedSite(root, paths);
    if (!metadata || metadata.browser_opened) return false;
    metadata.browser_opened = true;
    writeJsonAtomically(paths.state, metadata);
    const opened = openLocalBrowser(metadata.url);
    if (!opened) {
      metadata.browser_opened = false;
      writeJsonAtomically(paths.state, metadata);
    }
    return opened;
  });
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
  // Keep the project root available to page renderers without exposing an absolute local path in
  // the public site-data endpoint.
  Object.defineProperty(data, 'root', { value: root, enumerable: false });
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

// A concept's name is this product's own vocabulary, which a newcomer has never met. Its tags name
// the widely-known ideas behind it, so they are the one axis shared across unrelated features —
// which is what makes them worth filtering on.
function parseTags(concept) {
  return String(concept?.tags || '').split(/\r?\n/).map((tag) => tag.trim()).filter(Boolean);
}

// Colour comes from position in the sorted project-wide tag list, not from a hash of the name:
// two tags can never collide onto one colour while the palette has room, and a given project
// renders the same colours on every request.
function buildTagIndex(concepts) {
  const names = new Set();
  for (const concept of concepts) for (const tag of parseTags(concept)) names.add(tag);
  return [...names]
    .sort((left, right) => left.localeCompare(right))
    .map((name, index) => ({ name, slug: slugFor(name), tone: index % TAG_TONES }));
}

function uniqueTags(tags) {
  return [...new Map(tags.map((tag) => [tag.slug, tag])).values()]
    .sort((left, right) => left.name.localeCompare(right.name));
}

function buildNavigation(data) {
  const records = data.store.records;
  const concepts = sortByLabel(byType(records, 'concept'));
  const tagIndex = buildTagIndex(concepts);
  const tagByName = new Map(tagIndex.map((tag) => [tag.name, tag]));
  const tagsOf = (concept) => parseTags(concept).map((name) => tagByName.get(name)).filter(Boolean);
  const conceptByName = new Map(concepts.map((concept) => [concept.name, concept]));
  const explanationByRecord = new Map(byType(records, 'record_explanation').map((record) => [record.record, record]));
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
      // A feature carries the tags of every concept it touches, so the same shared vocabulary
      // filters features and decisions as well as the concepts that define it.
      tags: uniqueTags([...feature.concepts].flatMap((name) => tagsOf(conceptByName.get(name)))),
      decisions: sortByLabel(byType(records, 'decision').filter((decision) => decision.feature === feature.slug)),
      requirements: sortByLabel(byType(records, 'requirement').filter((item) => item.feature === feature.slug)),
      openQuestions: sortByLabel(byType(records, 'open_question').filter((item) => item.feature === feature.slug)),
      distillation: distillations.get(`features/${feature.slug}.md`) || null,
    };
  }).sort((left, right) => left.slug.localeCompare(right.slug));

  return {
    product: distillations.get('product.md') || null,
    tags: tagIndex,
    concepts: concepts.map((concept) => ({
      ...concept,
      slug: slugFor(concept.name),
      tags: tagsOf(concept),
      explanation: explanationByRecord.get(concept.name) || null,
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
  return `/records/${encodeURIComponent(concept.slug || slugFor(concept.name))}`;
}

const RECORD_DIAGRAM_PATH = /^docs\/fluencyloop\/diagrams\/records\/[A-Za-z0-9][A-Za-z0-9._-]*\.html$/;
const PRODUCT_OVERVIEW_DIAGRAM_PATH = 'docs/fluencyloop/diagrams/product-overview.html';
const LEGACY_DARK_DIAGRAM_TOKENS = `<style id="fluencyloop-embedded-dark-theme">
:root[data-fluencyloop-theme="dark"] {
  color-scheme: dark;
  --color-paper: #151a21;
  --color-paper-2: #1b212a;
  --color-ink: #e8edf3;
  --color-muted: #9aa6b4;
  --color-soft: #6d7a89;
  --color-rule: #38434f;
  --color-accent: #5fd0bd;
  --color-accent-tint: #173c39;
}
</style>`;

function safeDiagram(root, relativePath, directory) {
  const candidate = path.resolve(root, relativePath);
  if (!candidate.startsWith(directory + path.sep) || !fs.existsSync(candidate)) {
    return { unavailable: 'Diagram file is unavailable.' };
  }
  const content = fs.readFileSync(candidate, 'utf8');
  // Diagrams are project documentation, not an execution surface. Keep the route suitable for a
  // sandboxed iframe and reject active or remote-resource markup even when a manually authored
  // artifact slipped past the writer.
  if (/<\/?(?:script|iframe|object|embed)\b/i.test(content)
    || /\son[a-z]+\s*=/i.test(content)
    || /(?:src|href)\s*=\s*["'](?:https?:)?\/\//i.test(content)
    || /url\(\s*["']?(?:https?:)?\/\//i.test(content)) {
    return { unavailable: 'Diagram unavailable: embedded diagrams must be self-contained. Remove remote fonts, URLs, and executable content.' };
  }
  return { path: candidate };
}

function themedDiagramMarkup(content, theme) {
  const selectedTheme = theme === 'dark' ? 'dark' : 'light';
  // The reader controls the presentation preference, while the diagram remains a static,
  // sandboxed document. A generated diagram opts in by using CSS variables under this attribute.
  // Remove an existing value rather than allowing project content to override the reader.
  const withLegacyDarkTokens = selectedTheme === 'dark'
    ? content.replace(/<\/head\s*>/i, `${LEGACY_DARK_DIAGRAM_TOKENS}</head>`)
    : content;
  return withLegacyDarkTokens.replace(/<html\b([^>]*)>/i, (_match, attributes) => {
    const withoutTheme = attributes.replace(/\sdata-fluencyloop-theme\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, '');
    return `<html${withoutTheme} data-fluencyloop-theme="${selectedTheme}">`;
  });
}

function diagramCompanion(root, explanation) {
  if (!explanation || typeof explanation.diagram_path !== 'string' || !RECORD_DIAGRAM_PATH.test(explanation.diagram_path)) return null;
  const directory = path.resolve(root, 'docs', 'fluencyloop', 'diagrams', 'records');
  const companion = safeDiagram(root, explanation.diagram_path, directory);
  if (!companion.path) return companion;
  return { ...companion, type: explanation.diagram_type || 'diagram', alt: explanation.diagram_alt || 'Diagram supporting the record explanation.' };
}

function productOverviewDiagram(root) {
  const directory = path.resolve(root, 'docs', 'fluencyloop', 'diagrams');
  const companion = safeDiagram(root, PRODUCT_OVERVIEW_DIAGRAM_PATH, directory);
  if (!companion.path) return companion;
  return { ...companion, alt: 'System diagram supporting the technical overview.' };
}

function recordExplanationMarkup(data, concept) {
  const explanation = concept.explanation;
  if (!explanation) {
    return concept.distillation
      ? markdown(concept.distillation.content)
      : emptyState('No architectural record explanation has been written yet.');
  }
  const companion = diagramCompanion(data.root, explanation);
  const diagram = companion?.path
    ? `<figure class="record-diagram"><iframe src="${escapeHtml(`${conceptPath(concept)}/diagram`)}" title="${escapeHtml(companion.alt)}" sandbox loading="lazy" referrerpolicy="no-referrer"></iframe><figcaption>${escapeHtml(companion.alt)}</figcaption></figure>`
    : companion?.unavailable ? `<aside class="diagram-unavailable" role="note"><strong>Diagram unavailable.</strong><p>${escapeHtml(companion.unavailable)}</p></aside>` : '';
  return `<div class="record-explanation">
    <h3>Context</h3><p>${escapeHtml(explanation.context)}</p>
    <h3>Decision</h3><p>${escapeHtml(explanation.decision)}</p>
    <h3>How it works</h3><p>${escapeHtml(explanation.mechanism)}</p>
    <h3>Consequences</h3><p>${escapeHtml(explanation.consequences)}</p>
    ${diagram}
  </div>`;
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

function inlineMarkdown(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>');
}

// Distillations are regular Markdown, not source code. Keep the renderer deliberately small and
// dependency-free, while making headings, paragraphs, lists, emphasis, and inline code readable.
function prose(content) {
  const lines = content.trim().split(/\r?\n/);
  if (!content.trim()) return '';
  const rendered = [];
  let paragraph = [];
  let list = [];
  const flushParagraph = () => {
    if (paragraph.length) rendered.push(`<p>${inlineMarkdown(paragraph.join(' '))}</p>`);
    paragraph = [];
  };
  const flushList = () => {
    if (list.length) rendered.push(`<ul>${list.map((item) => `<li>${inlineMarkdown(item)}</li>`).join('')}</ul>`);
    list = [];
  };
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    const item = /^[-*]\s+(.+)$/.exec(line);
    if (!line) { flushParagraph(); flushList(); continue; }
    if (heading) {
      flushParagraph(); flushList();
      // The page already supplies the document title, so omit a leading H1 rather than repeating it.
      if (!(index === 0 && heading[1].length === 1)) {
        const level = Math.min(heading[1].length + 1, 6);
        rendered.push(`<h${level}>${inlineMarkdown(heading[2])}</h${level}>`);
      }
      continue;
    }
    if (item) { flushParagraph(); list.push(item[1]); continue; }
    flushList();
    paragraph.push(line);
  }
  flushParagraph(); flushList();
  return rendered.join('');
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
  return `<p class="empty-state">${escapeHtml(message)}</p>`;
}

// Every catalog row states when the record was written and which commit it describes. Those two
// facts are what let a reader judge whether the record still applies to the code in front of them.
function recordMeta(record) {
  if (!record) return '<div class="record-meta"></div>';
  const date = record.ts
    ? `<time class="record-date" datetime="${escapeHtml(record.ts)}" title="Recorded ${escapeHtml(record.ts)}">${escapeHtml(record.ts)}</time>`
    : '';
  let commit = '';
  if (record.commit === 'uncommitted') commit = '<span class="record-commit is-pending">uncommitted</span>';
  else if (record.commit) commit = `<code class="record-commit">${escapeHtml(record.commit.slice(0, 7))}</code>`;
  return `<div class="record-meta">${date}${commit}</div>`;
}

// `clickable` renders each tag as the same data-tag-filter button the toolbar chips use, so a
// row's tags plug straight into installCatalogFilters()'s existing [data-tag-filter] wiring with
// no separate handler — clicking a row's tag filters the catalog exactly like clicking it in the
// toolbar. Detail-page headers (outside any [data-catalog]) stay plain static chips: a
// data-tag-filter button there would look clickable but do nothing, since no catalog script runs
// on that page to wire it up.
function tagList(tags, clickable = false, limit = Infinity) {
  if (!tags || !tags.length) return '';
  const visibleTags = tags.slice(0, limit);
  const hiddenTags = tags.slice(limit);
  const overflow = hiddenTags.length
    ? `<li><span class="tag-overflow" title="Also tagged: ${escapeHtml(hiddenTags.map((tag) => tag.name).join(', '))}">+${hiddenTags.length} more</span></li>`
    : '';
  if (!clickable) {
    return `<ul class="tag-list">${visibleTags
      .map((tag) => `<li><span class="tag tone-${tag.tone}" data-tag="${escapeHtml(tag.slug)}">${escapeHtml(tag.name)}</span></li>`)
      .join('')}${overflow}</ul>`;
  }
  return `<ul class="tag-list">${visibleTags
    .map((tag) => `<li><button type="button" class="tag tag-button tone-${tag.tone}" data-tag-filter="${escapeHtml(tag.slug)}" aria-pressed="false">${escapeHtml(tag.name)}</button></li>`)
    .join('')}${overflow}</ul>`;
}

function recordRow(item) {
  const tags = item.tags || [];
  return `<li class="record-row" data-record-row data-tags="${escapeHtml(tags.map((tag) => tag.slug).join(' '))}">
    <span class="record-kind">${escapeHtml(item.label)}</span>
    <div class="record-body">
      <h3 class="record-title">${item.href ? link(item.href, item.title) : escapeHtml(item.title)}</h3>
      ${item.summary ? `<p class="record-summary">${escapeHtml(item.summary)}</p>` : ''}
      ${tagList(tags, true, CATALOG_TAG_LIMIT)}
    </div>
    ${recordMeta(item.record)}
  </li>`;
}

function recordList(items, emptyMessage) {
  if (!items.length) return emptyState(emptyMessage);
  return `<ol class="record-list">${items.map(recordRow).join('')}</ol>`;
}

// The toolbar is progressive enhancement: the server always renders every row, and the script
// below hides the ones that stop matching. Without JavaScript the catalog is simply complete.
function catalogToolbar(tags) {
  const chips = tags.length
    ? `<div class="tag-filter" role="group" aria-label="Filter by architectural record">
        <button type="button" class="tag tag-button is-all" data-tag-filter="all" aria-pressed="true">All</button>
        ${tags.map((tag) => `<button type="button" class="tag tag-button tone-${tag.tone}" data-tag-filter="${escapeHtml(tag.slug)}" aria-pressed="false">${escapeHtml(tag.name)}</button>`).join('')}
      </div>`
    : '';
  return `<div class="catalog-toolbar">
    <label class="catalog-search">
      <span class="visually-hidden">Search records</span>
      <input type="search" data-catalog-search placeholder="Search records" autocomplete="off" spellcheck="false">
    </label>
    ${chips}
  </div>`;
}

function filterableCatalog(tags, items, emptyMessage) {
  if (!items.length) return emptyState(emptyMessage);
  return `<div class="catalog" data-catalog>
    ${catalogToolbar(tags)}
    <p class="catalog-status" data-catalog-status role="status" aria-live="polite"></p>
    ${recordList(items, emptyMessage)}
  </div>`;
}

function conceptItem(concept) {
  return {
    label: 'Record',
    title: concept.name,
    href: conceptPath(concept),
    summary: concept.problem,
    tags: concept.tags,
    record: concept,
  };
}

function featureItem(feature) {
  return {
    label: 'Feature',
    title: feature.slug,
    href: featurePath(feature),
    summary: feature.record ? feature.record.intent : '',
    tags: feature.tags,
    record: feature.record,
  };
}

function decisionItem(decision, tags) {
  return {
    label: 'Decision',
    title: decision.title,
    href: decisionPath(decision),
    summary: decision.why,
    tags,
    record: decision,
  };
}

// Newest first: a catalog is read to find what changed recently, and `ts` is the only date a
// record carries. Records without one sort last rather than disappearing.
function newestFirst(items) {
  return [...items].sort((left, right) => String(right.record?.ts || '').localeCompare(String(left.record?.ts || '')));
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
      <nav aria-label="Primary">
        <a class="site-mark" href="/" aria-label="Product overview">FL</a>
        <span class="project-name">${escapeHtml(data.project)}</span>
        <span class="nav-links">${link('/', 'Overview')}${link('/records', 'Records')}${link('/features', 'Features')}</span>
        <button type="button" data-theme-toggle aria-label="Switch theme" aria-pressed="false">Theme</button>
      </nav>
      ${breadcrumb}
      ${storeWarning}
      ${body}
    </main>
    <script src="/assets/site.js" defer></script>
  </body>
</html>`;
}

function renderConstraints(requirements, openQuestions) {
  const answered = requirements.length
    ? `<ul class="constraint-list">${requirements.map((item) => `<li><p class="constraint-gap">${escapeHtml(item.gap)}</p><p class="constraint-detail"><span>Answer</span> ${escapeHtml(item.answer)}</p><p class="constraint-detail"><span>Consequence</span> ${escapeHtml(item.consequence)}</p></li>`).join('')}</ul>`
    : emptyState('No answered requirements were recorded at this level.');
  const open = openQuestions.length
    ? `<ul class="constraint-list">${openQuestions.map((item) => `<li><p class="constraint-gap">${escapeHtml(item.gap)}</p><p class="constraint-detail"><span>Why it matters</span> ${escapeHtml(item.why_it_matters)}</p></li>`).join('')}</ul>`
    : emptyState('No open questions were recorded at this level.');
  return `<h3>Requirements</h3>${answered}<h3>Open questions</h3>${open}`;
}

function renderProduct(data) {
  const navigation = data.navigation;
  const concepts = recordList(
    newestFirst(navigation.concepts.map(conceptItem)),
    navigation.hasCapturedHistoryWithoutConcepts
      ? 'No architectural records have been recorded yet. This project has imported decision history — ask your assistant to "fluencyloop backfill" it to synthesize the architecture, or capture one directly with fluencyloop concept.'
      : 'No architectural records have been recorded yet. Capture one with fluencyloop concept.',
  );
  const features = recordList(newestFirst(navigation.features.map(featureItem)), 'No features have been recorded yet.');
  const overview = navigation.product
    ? markdown(navigation.product.content)
    : emptyState(navigation.hasCapturedHistoryWithoutConcepts
      ? 'No product overview has been distilled yet. Ask your assistant to "fluencyloop backfill" the imported history to synthesize one, or it will appear automatically once a feature materially changes the product shape.'
      : 'No product overview has been distilled yet. It will appear when a feature materially changes the product shape.');
  const overviewCompanion = navigation.product && productOverviewDiagram(data.root);
  const overviewDiagram = overviewCompanion?.path
    ? `<figure class="record-diagram overview-diagram"><iframe src="/overview/diagram" title="${escapeHtml(overviewCompanion.alt)}" sandbox loading="lazy" referrerpolicy="no-referrer"></iframe><figcaption>${escapeHtml(overviewCompanion.alt)}</figcaption></figure>`
    : overviewCompanion?.unavailable ? `<aside class="diagram-unavailable" role="note"><strong>Diagram unavailable.</strong><p>${escapeHtml(overviewCompanion.unavailable)}</p></aside>` : '';
  const distillations = data.distillations.length
    ? `<ul class="path-list">${data.distillations.map((item) => `<li><code>${escapeHtml(item.path)}</code></li>`).join('')}</ul>`
    : emptyState('No distillations have been written yet.');
  return layout(data, 'Product overview', `
    <header class="record-header"><p class="eyebrow">Product overview</p><h1>${escapeHtml(data.project)}</h1></header>
    <section><h2>Technical overview</h2>${overview}${overviewDiagram}</section>
    <section><h2>Architectural records</h2>${concepts}</section>
    <section><h2>Features as deltas</h2>${features}</section>
    <section><h2>Initiative constraints</h2>${renderConstraints(navigation.requirements, navigation.openQuestions)}</section>
    <section><h2>Available distillations</h2>${distillations}</section>
  `);
}

function renderConceptList(data) {
  const concepts = data.navigation.concepts.length
    ? filterableCatalog(data.navigation.tags, newestFirst(data.navigation.concepts.map(conceptItem)), '')
    : emptyState(data.navigation.hasCapturedHistoryWithoutConcepts
      ? 'No architectural records have been recorded yet. This project has imported decision history — ask your assistant to "fluencyloop backfill" it to synthesize the architecture, or capture one directly with fluencyloop concept.'
      : 'No architectural records have been recorded yet. The product overview remains available while the store is empty.');
  const relationships = data.navigation.relations.length
    ? `<ul class="relation-list">${data.navigation.relations.map((relation) => `<li>${endpointLink(data.navigation, relation.from)} <span class="relation-kind">${escapeHtml(relation.kind)}</span> &rarr; ${endpointLink(data.navigation, relation.to)}</li>`).join('')}</ul>`
    : emptyState('No relationships have been recorded yet.');
  return layout(data, 'Architectural records', `<h1>Architectural records</h1><section><h2>Records</h2>${concepts}</section><section><h2>Relationship graph</h2>${relationships}</section>`, [
    { href: '/', label: 'Product overview' }, { label: 'Architectural records' },
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
    ? `<ul class="relation-list">${concept.relations.map((relation) => `<li>${endpointLink(data.navigation, relation.from)} <span class="relation-kind">${escapeHtml(relation.kind)}</span> &rarr; ${endpointLink(data.navigation, relation.to)}</li>`).join('')}</ul>`
    : emptyState('This architectural record has no recorded relationships yet.');
  const features = recordList(
    newestFirst(concept.features.map((feature) => featureItem(data.navigation.features.find((item) => item.slug === feature.slug) || feature))),
    'No feature is currently linked to this concept.',
  );
  const explanation = recordExplanationMarkup(data, concept);
  return layout(data, concept.name, `
    <header class="record-header">
      <p class="eyebrow">Architectural record</p>
      <h1>${escapeHtml(concept.name)}</h1>
      ${tagList(concept.tags)}
      ${recordMeta(concept)}
    </header>
    <section><h2>Problem in this product</h2><p>${escapeHtml(concept.problem)}</p><h2>How it works</h2><p>${escapeHtml(concept.how)}</p>
    <h2>Realized by</h2>${realizedBy.length ? `<ul>${realizedBy.map((item) => `<li>${escapeHtml(item)}</li>`).join('')}</ul>` : emptyState('No implementation area was recorded.')}</section>
    <section><h2>Architectural record explanation</h2>${explanation}</section>
    <section><h2>Relationships</h2>${relationships}</section>
    <section><h2>Features that change this record</h2>${features}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/records', label: 'Architectural records' }, { label: concept.name }]);
}

function renderFeatureList(data) {
  const features = filterableCatalog(
    data.navigation.tags,
    newestFirst(data.navigation.features.map(featureItem)),
    'No features have been recorded yet.',
  );
  return layout(data, 'Features', `<h1>Features as deltas</h1>${features}`, [
    { href: '/', label: 'Product overview' }, { label: 'Features' },
  ]);
}

function renderFeature(data, feature) {
  const concepts = recordList(
    newestFirst(feature.concepts.map((concept) => conceptItem(data.navigation.concepts.find((item) => item.name === concept.name) || concept))),
    'This feature has no linked architectural records yet.',
  );
  const decisions = recordList(
    newestFirst(feature.decisions.map((decision) => decisionItem(decision, feature.tags))),
    'No decisions have been recorded for this feature yet.',
  );
  const delta = feature.distillation
    ? markdown(feature.distillation.content)
    : emptyState('No feature delta has been distilled yet.');
  return layout(data, feature.slug, `
    <header class="record-header">
      <p class="eyebrow">Feature</p>
      <h1>${escapeHtml(feature.slug)}</h1>
      ${tagList(feature.tags)}
      ${recordMeta(feature.record)}
    </header>
    ${feature.record && feature.record.intent ? `<p>${escapeHtml(feature.record.intent)}</p>` : ''}
    <section><h2>Feature delta</h2>${delta}</section>
    <section><h2>Architectural records changed</h2>${concepts}</section>
    <section><h2>Constraints for this feature</h2>${renderConstraints(feature.requirements, feature.openQuestions)}</section>
    <section><h2>Decisions</h2>${decisions}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/features', label: 'Features' }, { label: feature.slug }]);
}

function renderDecision(data, feature, decision) {
  const concepts = recordList(
    newestFirst(feature.concepts.map((concept) => conceptItem(data.navigation.concepts.find((item) => item.name === concept.name) || concept))),
    'No architectural record link was recorded for this feature.',
  );
  return layout(data, decision.title, `
    <header class="record-header">
      <p class="eyebrow">Decision in ${link(featurePath(feature), feature.slug)}</p>
      <h1>${escapeHtml(decision.title)}</h1>
      ${tagList(feature.tags)}
      ${recordMeta(decision)}
    </header>
    <section class="detail-section">
      <h2>Why</h2><p>${escapeHtml(decision.why)}</p>
      ${decision.alternative ? `<h2>Alternative rejected</h2><p>${escapeHtml(decision.alternative)}</p>` : ''}
      <h2>Where</h2><p><code>${escapeHtml(decision.where)}</code></p>
    </section>
    <section class="detail-section"><h2>Architectural records served</h2>${concepts}</section>
  `, [{ href: '/', label: 'Product overview' }, { href: '/features', label: 'Features' }, { href: featurePath(feature), label: feature.slug }, { label: decision.title }]);
}

function send(response, status, contentType, body) {
  response.writeHead(status, { 'Content-Type': contentType, 'Cache-Control': 'no-store' });
  response.end(body);
}

function sendDiagram(response, body) {
  response.writeHead(200, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    // The artifact is documentation rendered in an iframe, never an application surface.
    'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:",
  });
  response.end(body);
}

function redirect(response, location) {
  response.writeHead(308, { Location: location, 'Cache-Control': 'no-store' });
  response.end();
}

function createServer(root, managed = null) {
  return http.createServer((request, response) => {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      send(response, 405, 'text/plain; charset=utf-8', 'Method not allowed\n');
      return;
    }
    try {
      const requestUrl = new URL(request.url, 'http://127.0.0.1');
      const pathname = requestUrl.pathname;
      const diagramTheme = requestUrl.searchParams.get('theme') === 'dark' ? 'dark' : 'light';
      if (pathname === '/health') {
        const health = { status: 'ok' };
        if (managed) health.site_id = managed.id;
        send(response, 200, 'application/json; charset=utf-8', request.method === 'HEAD' ? '' : JSON.stringify(health) + '\n');
        return;
      }
      // Lifecycle probes use /health; they must not extend the site's idle timer.
      touchManagedActivity(managed);
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
      if (pathname === '/concepts' || pathname.startsWith('/concepts/')) {
        redirect(response, `/records${pathname.slice('/concepts'.length)}${requestUrl.search}`);
        return;
      }
      const segments = pathname.split('/').filter(Boolean).map((segment) => decodeURIComponent(segment));
      let page = null;
      if (segments.length === 0) {
        page = renderProduct(data);
      } else if (segments.length === 2 && segments[0] === 'overview' && segments[1] === 'diagram') {
        const companion = data.navigation.product && productOverviewDiagram(data.root);
        if (companion?.path) {
          sendDiagram(response, request.method === 'HEAD' ? '' : themedDiagramMarkup(fs.readFileSync(companion.path, 'utf8'), diagramTheme));
          return;
        }
      } else if (segments.length === 1 && segments[0] === 'records') {
        page = renderConceptList(data);
      } else if (segments.length === 3 && segments[0] === 'records' && segments[2] === 'diagram') {
        const concept = data.navigation.concepts.find((item) => item.slug === segments[1]);
        const companion = concept && diagramCompanion(data.root, concept.explanation);
        if (companion?.path) {
          sendDiagram(response, request.method === 'HEAD' ? '' : themedDiagramMarkup(fs.readFileSync(companion.path, 'utf8'), diagramTheme));
          return;
        }
      } else if (segments.length === 2 && segments[0] === 'records') {
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

function managedConfiguration(options) {
  if (!options.managedState) return null;
  return {
    state: options.managedState,
    id: options.managedId,
    startup: options.managedStartup,
    session: options.managedSession,
  };
}

function recordManagedStart(root, managed, port) {
  if (!managed) return;
  const metadata = {
    id: managed.id,
    startup: managed.startup,
    root,
    pid: process.pid,
    port,
    url: 'http://127.0.0.1:' + port,
    version: SITE_VERSION,
    last_activity: Date.now(),
    browser_opened: false,
    sessions: {},
  };
  recordSession(metadata, managed.session);
  ensureManagedDirectory({ directory: path.dirname(managed.state) });
  writeJsonAtomically(managed.state, metadata);
}

function manageIdleLifetime(server, managed) {
  if (!managed) return;
  const interval = setInterval(() => {
    const metadata = readJson(managed.state);
    if (!metadata || metadata.id !== managed.id || metadata.pid !== process.pid) return;
    if (hasActiveSessions(metadata)) return;
    if (Date.now() - Number(metadata.last_activity || 0) < MANAGED_IDLE_MS) return;
    server.close(() => {
      removeManagedState(managed);
      process.exit(0);
    });
  }, MANAGED_IDLE_CHECK_MS);
  interval.unref();
}

async function start(root, requestedPort, managed = null) {
  let port = requestedPort;
  while (port <= 65535) {
    const server = createServer(root, managed);
    try {
      await listen(server, port);
      const address = server.address();
      recordManagedStart(root, managed, address.port);
      process.stdout.write('FluencyLoop site: http://127.0.0.1:' + address.port + '\n');
      const stop = () => server.close(() => {
        removeManagedState(managed);
        process.exit(0);
      });
      process.once('SIGINT', stop);
      process.once('SIGTERM', stop);
      manageIdleLifetime(server, managed);
      return;
    } catch (error) {
      if (error.code === 'EADDRINUSE' && port !== 0) {
        port += 1;
        continue;
      }
      throw error;
    }
  }
  throw new Error('no free loopback port found from ' + requestedPort + ' through 65535');
}

let options;
try {
  options = parseArgs(process.argv.slice(2));
} catch (error) {
  usage(error.message);
}
if (options) {
  const root = canonicalRoot(options.root);
  const paths = managedPaths(root);
  const manager = options.ensure || options.status || options.stop || options.sessionStart || options.sessionEnd;
  const operation = options.ensure || options.sessionStart
    ? ensureManagedSite(root, paths, options.portSpecified ? options.port : MANAGED_DEFAULT_PORT, options.sessionStart)
    : options.status
      ? currentManagedSite(root, paths).then((metadata) => resultFor(metadata, { reused: Boolean(metadata) }))
      : options.stop
        ? stopManagedSite(root, paths)
        : options.sessionEnd
          ? releaseManagedSession(root, paths, options.sessionEnd)
          : start(root, options.port, managedConfiguration(options));
  operation.then(async (result) => {
    if (options.openOnce && result.running && result.url) {
      result.browser_opened = await openManagedBrowserOnce(root, paths);
    } else if (options.open && result.running && result.url) {
      result.browser_opened = openLocalBrowser(result.url);
    }
    if (manager) printManagedResult(result, options.json);
  }).catch((error) => {
    process.stderr.write('Could not start FluencyLoop site: ' + error.message + '\n');
    process.exitCode = 1;
  });
}
