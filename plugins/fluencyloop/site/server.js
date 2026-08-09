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
    path: path.relative(directory, file),
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
  return {
    project: path.basename(root),
    store: readStore(path.join(docs, 'store')),
    distillations: readDistillations(path.join(docs, 'distillations')),
    calibration: readCalibration(),
  };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  })[character]);
}

function recordLabel(record) {
  return record.title || record.name || record.slug || record.number || record.gap || record.type;
}

function renderPage(data) {
  const records = data.store.records.map((record) =>
    `<li><strong>${escapeHtml(record.type)}</strong> — ${escapeHtml(recordLabel(record))}</li>`).join('') ||
    '<li>No store records yet.</li>';
  const distillations = data.distillations.map((item) => `<li>${escapeHtml(item.path)}</li>`).join('') ||
    '<li>No distillations yet.</li>';
  const tailoredTopics = Object.keys(data.calibration).length;
  const storeWarning = data.store.errors.length
    ? `<p role="alert">${data.store.errors.length} unreadable store record(s) were skipped.</p>`
    : '';
  return `<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(data.project)} — FluencyLoop</title></head>
  <body>
    <main>
      <h1>${escapeHtml(data.project)} — FluencyLoop</h1>
      <p>Reading ${data.store.records.length} current store record(s) from the project.</p>
      <p>Personalization is applied locally for ${tailoredTopics} calibrated topic(s).</p>
      ${storeWarning}
      <h2>Current records</h2><ul>${records}</ul>
      <h2>Distillations</h2><ul>${distillations}</ul>
    </main>
  </body>
</html>`;
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
      if (pathname === '/') {
        send(response, 200, 'text/html; charset=utf-8', request.method === 'HEAD' ? '' : renderPage(data));
        return;
      }
      if (pathname === '/api/site-data') {
        send(response, 200, 'application/json; charset=utf-8', request.method === 'HEAD' ? '' : `${JSON.stringify(data)}\n`);
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
