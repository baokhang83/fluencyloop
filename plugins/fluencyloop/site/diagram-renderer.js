#!/usr/bin/env node
'use strict';

// diagram-renderer.js — FluencyLoop's deliberately small diagram compiler. Agents provide a
// bounded graph; this file owns coordinates, attachment points, arrows, themes, and the fixed
// document height used by the sandboxed site iframe.

const fs = require('fs');
const path = require('path');

const usage = `Usage: fluencyloop diagram --output docs/fluencyloop/diagrams/<file>.html
  --layout <linear|hub|merge|layered> --title <title>
  --node <id> --label <label> --detail <detail> [--node ...]
  [--edge <from> <to> [--edge-label <text>] ...] [--hub <id>]

Limits: 2–8 nodes, at most 10 edges, labels up to 20 characters, details up to 32 characters.`;

function fail(message) {
  process.stderr.write(`Error: ${message}\n${usage}\n`);
  process.exit(1);
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

const args = process.argv.slice(2);
const graph = { output: '', layout: '', title: '', nodes: [], edges: [], hub: '' };
let active = null;
let latestEdge = null;
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  const next = () => {
    index += 1;
    if (index >= args.length || args[index].startsWith('--')) fail(`${arg} requires a value.`);
    return args[index];
  };
  switch (arg) {
    case '--output': graph.output = next(); break;
    case '--layout': graph.layout = next(); break;
    case '--title': graph.title = next(); break;
    case '--node': {
      const id = next();
      if (!/^[A-Za-z][A-Za-z0-9_-]*$/.test(id)) fail(`invalid node id: ${id}`);
      if (graph.nodes.some((node) => node.id === id)) fail(`duplicate node id: ${id}`);
      active = { id, label: '', detail: '' };
      graph.nodes.push(active);
      break;
    }
    case '--label': if (!active) fail('--label must follow --node.'); active.label = next(); break;
    case '--detail': if (!active) fail('--detail must follow --node.'); active.detail = next(); break;
    case '--edge': {
      const from = next();
      const to = next();
      latestEdge = { from, to, label: '' };
      graph.edges.push(latestEdge);
      break;
    }
    case '--edge-label': if (!latestEdge) fail('--edge-label must follow --edge.'); latestEdge.label = next(); break;
    case '--hub': graph.hub = next(); break;
    case '--help': process.stdout.write(`${usage}\n`); process.exit(0); break;
    default: fail(`unknown option: ${arg}`);
  }
}

if (!graph.output || !graph.layout || !graph.title) fail('--output, --layout, and --title are required.');
if (!['linear', 'hub', 'merge', 'layered'].includes(graph.layout)) fail(`unknown layout: ${graph.layout}`);
if (graph.nodes.length < 2 || graph.nodes.length > 8) fail('provide 2–8 nodes.');
if (graph.edges.length > 10) fail('provide at most 10 edges.');
if (graph.title.length > 56) fail('title is too long; use a concise site heading.');
for (const node of graph.nodes) {
  if (!node.label || !node.detail) fail(`node ${node.id} requires --label and --detail.`);
  if (node.label.length > 20 || node.detail.length > 32) fail(`node ${node.id} text is too long; use concise site labels.`);
}
if (graph.layout === 'linear' && graph.nodes.length >= 5
  && graph.nodes.some((node) => node.label.length > 14 || node.detail.length > 18)) {
  fail('a five-or-more-node linear layout needs short labels; choose layered or hub for longer text.');
}
const nodeById = new Map(graph.nodes.map((node) => [node.id, node]));
for (const edge of graph.edges) {
  if (!nodeById.has(edge.from) || !nodeById.has(edge.to) || edge.from === edge.to) fail(`invalid edge: ${edge.from} → ${edge.to}`);
  if (edge.label.length > 24) fail(`edge label is too long: ${edge.label}`);
}
if (!graph.edges.length) fail('provide at least one --edge.');

const output = path.resolve(process.cwd(), graph.output);
const diagramsRoot = path.resolve(process.cwd(), 'docs', 'fluencyloop', 'diagrams');
if (!output.startsWith(`${diagramsRoot}${path.sep}`) || path.extname(output) !== '.html') {
  fail('--output must be an .html file under docs/fluencyloop/diagrams/.');
}

const WIDTH = 960;
const CARD_W = 200;
const CARD_H = 104;
// `site.css` gives every embedded companion a 33rem (528px) frame. Match it exactly: a renderer
// that is merely shorter looks like an unfinished white panel, even when its SVG is technically
// valid.
const HEIGHT = 528;
// Keep a small, stable reading key inside the fixed iframe. Layouts use the remaining canvas so
// the key never becomes an afterthought below a cropped or scrollable diagram.
const KEY_H = 52;
const CONTENT_BOTTOM = HEIGHT - KEY_H;

function card(node, box, shared = false) {
  node.box = box;
  const klass = shared ? 'card shared' : 'card';
  const compact = box.w < 180 ? ' compact' : '';
  const nameY = box.y + box.h / 2 - 8;
  return `<rect x="${box.x}" y="${box.y}" width="${box.w}" height="${box.h}" rx="10" class="${klass}"/>
    <text x="${box.x + 20}" y="${nameY}" class="name${compact}">${escapeHtml(node.label)}</text>
    <text x="${box.x + 20}" y="${nameY + 28}" class="detail${compact}">${escapeHtml(node.detail)}</text>`;
}

function edgeLabel(edge, x, y) {
  if (!edge.label) return '';
  const width = Math.max(60, edge.label.length * 7 + 18);
  return `<rect x="${Math.round(x - width / 2)}" y="${Math.round(y - 18)}" width="${width}" height="22" rx="11" class="edge-label-bg"/>
    <text x="${Math.round(x)}" y="${Math.round(y - 3)}" class="edge-label" text-anchor="middle">${escapeHtml(edge.label)}</text>`;
}

function readingKey() {
  const ruleY = HEIGHT - KEY_H + 6;
  const baseline = HEIGHT - 16;
  return `<line x1="48" y1="${ruleY}" x2="912" y2="${ruleY}" class="key-rule"/>
    <text x="48" y="${baseline}" class="key-heading">READING KEY</text>
    <line x1="154" y1="${baseline - 5}" x2="186" y2="${baseline - 5}" class="key-flow"/>
    <text x="198" y="${baseline}" class="key-text">arrow: directed relationship</text>
    <rect x="454" y="${baseline - 15}" width="14" height="14" rx="3" class="key-focus"/>
    <text x="480" y="${baseline}" class="key-text">accent border: focal boundary</text>`;
}

function linearLayout() {
  const n = graph.nodes.length;
  const width = Math.min(CARD_W, Math.floor((WIDTH - 96 - (n - 1) * 24) / n));
  if (width < 112) fail('linear layout cannot fit these nodes.');
  const gap = (WIDTH - 96 - n * width) / (n - 1);
  graph.nodes.forEach((node, index) => { node.box = { x: Math.round(48 + index * (width + gap)), y: 190, w: width, h: CARD_H }; });
  const paths = graph.edges.map((edge) => {
    const from = nodeById.get(edge.from).box; const to = nodeById.get(edge.to).box;
    if (to.x <= from.x) fail('linear edges must point from left to right.');
    if (graph.nodes.some((node) => node.box.x > from.x && node.box.x < to.x)) fail('linear edges may connect adjacent nodes only.');
    if (to.y !== from.y) fail('linear layout requires aligned nodes.');
    const midX = Math.round((from.x + from.w + to.x) / 2);
    return `<path d="M${from.x + from.w} ${from.y + CARD_H / 2} H${to.x}" class="flow"/>${edgeLabel(edge, midX, from.y + CARD_H / 2 - 10)}`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box)) };
}

function mergeLayout() {
  const hub = nodeById.get(graph.hub);
  if (!hub) fail('merge layout requires --hub <node-id>.');
  const outgoing = new Map(graph.nodes.map((node) => [node.id, []]));
  const incoming = new Map(graph.nodes.map((node) => [node.id, []]));
  graph.edges.forEach((edge) => { outgoing.get(edge.from).push(edge); incoming.get(edge.to).push(edge); });
  if (outgoing.get(hub.id).length) fail('merge edges must converge on --hub, never leave it.');
  if (graph.edges.length !== graph.nodes.length - 1
    || graph.nodes.some((node) => node !== hub && outgoing.get(node.id).length !== 1)) {
    fail('merge layout needs one directed path from every participant into --hub.');
  }
  if (graph.edges.some((edge) => !edge.label)) {
    fail('merge layout requires --edge-label after every --edge so each converging relationship is clear.');
  }
  const depth = new Map([[hub.id, 0]]);
  const resolving = new Set();
  const resolveDepth = (node) => {
    if (depth.has(node.id)) return depth.get(node.id);
    if (resolving.has(node.id)) fail('merge layout does not support cycles.');
    resolving.add(node.id);
    const next = outgoing.get(node.id)[0];
    if (!next) fail('merge layout has a participant that cannot reach --hub.');
    const value = resolveDepth(nodeById.get(next.to)) + 1;
    resolving.delete(node.id);
    depth.set(node.id, value);
    return value;
  };
  graph.nodes.forEach(resolveDepth);
  const maxDepth = Math.max(...depth.values());
  if (maxDepth > 3) fail('merge layout supports paths up to four cards deep; use a concise overview.');
  // Four columns still need visible lanes for arrows and labels. Compact only as much as this
  // bounded topology needs, rather than letting full-width cards consume every inter-card gap.
  const mergeCardW = Math.min(CARD_W, Math.floor((WIDTH - 96 - maxDepth * 64) / (maxDepth + 1)));
  if (mergeCardW < 150) fail('merge layout cannot give this graph readable lanes; use a concise overview.');
  const leaves = graph.nodes.filter((node) => !incoming.get(node.id).length);
  const y = new Map();
  // Leave a deliberate title band above and a quiet breathing band below the graph. The embedded
  // frame is fixed-height, so filling it with the diagram canvas is part of the composition.
  leaves.forEach((node, index) => y.set(node.id, Math.round(168 + index * ((HEIGHT - 320) / Math.max(1, leaves.length - 1)))));
  const resolveY = (node) => {
    if (y.has(node.id)) return y.get(node.id);
    const parents = incoming.get(node.id).map((edge) => nodeById.get(edge.from));
    const value = Math.round(parents.reduce((sum, parent) => sum + resolveY(parent), 0) / parents.length);
    y.set(node.id, value);
    return value;
  };
  graph.nodes.forEach(resolveY);
  const colGap = (WIDTH - 96 - mergeCardW) / maxDepth;
  graph.nodes.forEach((node) => {
    const centerY = resolveY(node);
    node.box = { x: Math.round(48 + (maxDepth - depth.get(node.id)) * colGap), y: centerY - CARD_H / 2, w: mergeCardW, h: CARD_H };
  });
  const inputPorts = new Map();
  graph.nodes.forEach((node) => {
    const edges = [...incoming.get(node.id)].sort((a, b) => nodeById.get(a.from).box.y - nodeById.get(b.from).box.y);
    edges.forEach((edge, index) => inputPorts.set(edge, node.box.y + node.box.h * (index + 1) / (edges.length + 1)));
  });
  const paths = graph.edges.map((edge) => {
    const from = nodeById.get(edge.from).box; const to = nodeById.get(edge.to).box;
    const startY = from.y + from.h / 2; const endY = inputPorts.get(edge);
    const lane = Math.round((from.x + from.w + to.x) / 2);
    const label = Math.abs(endY - startY) > 24
      ? edgeLabel(edge, lane, (startY + endY) / 2)
      : edgeLabel(edge, (from.x + from.w + to.x) / 2, startY - 10);
    return `<path d="M${from.x + from.w} ${startY} H${lane} V${endY} H${to.x}" class="flow"/>${label}`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box, node === hub)) };
}

function hubLayout() {
  const hub = nodeById.get(graph.hub);
  if (!hub) fail('hub layout requires --hub <node-id>.');
  if (graph.edges.some((edge) => edge.from !== hub.id && edge.to !== hub.id)) fail('hub edges must connect to --hub.');
  const leaves = graph.nodes.filter((node) => node !== hub);
  const left = leaves.slice(0, Math.ceil(leaves.length / 2));
  const right = leaves.slice(left.length);
  const degree = new Map(leaves.map((node) => [node.id, 0]));
  graph.edges.forEach((edge) => {
    const leafId = edge.from === hub.id ? edge.to : edge.from;
    degree.set(leafId, degree.get(leafId) + 1);
  });
  if ([...degree.values()].some((count) => count > 1)) fail('hub layout permits one edge per participant so every route stays distinct.');
  // Every leaf gets its own horizontal port. No elbows means no crossing, shared attachment
  // point, or marker that can render inside a non-endpoint card.
  const LEAF_H = 80;
  hub.box = { x: 380, y: 88, w: CARD_W, h: 360 };
  const spaced = (items, x) => items.forEach((node, index) => {
    const center = Math.round(132 + index * (268 / Math.max(1, items.length - 1)));
    node.box = { x, y: center - LEAF_H / 2, w: CARD_W, h: LEAF_H };
  });
  spaced(left, 48); spaced(right, 712);
  const paths = graph.edges.map((edge) => {
    const fromNode = nodeById.get(edge.from); const toNode = nodeById.get(edge.to);
    const leaf = fromNode === hub ? toNode : fromNode;
    const leafOnLeft = leaf.box.x < hub.box.x;
    const y = leaf.box.y + LEAF_H / 2;
    const start = fromNode === hub
      ? { x: leafOnLeft ? hub.box.x : hub.box.x + hub.box.w, y }
      : { x: leafOnLeft ? leaf.box.x + leaf.box.w : leaf.box.x, y };
    const end = toNode === hub
      ? { x: leafOnLeft ? hub.box.x : hub.box.x + hub.box.w, y }
      : { x: leafOnLeft ? leaf.box.x + leaf.box.w : leaf.box.x, y };
    return `<path d="M${start.x} ${start.y} H${end.x}" class="flow"/>`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box, node === hub)) };
}

function layeredLayout() {
  const parents = new Map(graph.nodes.map((node) => [node.id, []]));
  graph.edges.forEach((edge) => parents.get(edge.to).push(edge.from));
  const ranks = new Map(graph.nodes.map((node) => [node.id, 0]));
  for (let pass = 0; pass < graph.nodes.length; pass += 1) {
    let changed = false;
    for (const edge of graph.edges) {
      const next = ranks.get(edge.from) + 1;
      if (next > ranks.get(edge.to)) { ranks.set(edge.to, next); changed = true; }
    }
    if (!changed) break;
    if (pass === graph.nodes.length - 1) fail('layered layout does not support cycles.');
  }
  const maxRank = Math.max(...ranks.values());
  if (maxRank > 3) fail('layered layout supports at most four layers.');
  const groups = Array.from({ length: maxRank + 1 }, () => []);
  graph.nodes.forEach((node) => groups[ranks.get(node.id)].push(node));
  groups.forEach((group, rank) => group.forEach((node, index) => {
    const y = Math.round(126 + index * ((CONTENT_BOTTOM - 126 - CARD_H) / Math.max(1, group.length - 1)));
    const x = Math.round(48 + rank * ((WIDTH - 96 - CARD_W) / Math.max(1, maxRank)));
    node.box = { x, y, w: CARD_W, h: CARD_H };
  }));
  for (const edge of graph.edges) {
    if (ranks.get(edge.to) !== ranks.get(edge.from) + 1) fail('layered edges must connect adjacent layers.');
  }
  const boundaryEdges = new Map();
  graph.edges.forEach((edge) => {
    const key = `${ranks.get(edge.from)}:${ranks.get(edge.to)}`;
    boundaryEdges.set(key, [...(boundaryEdges.get(key) || []), edge]);
  });
  for (const edges of boundaryEdges.values()) {
    const seenSources = new Set(); const seenTargets = new Set();
    for (const edge of edges) {
      if (seenSources.has(edge.from) || seenTargets.has(edge.to)) fail('layered layout requires one edge per node boundary; choose hub for a fan-out or merge.');
      seenSources.add(edge.from); seenTargets.add(edge.to);
    }
    const ordered = [...edges].sort((a, b) => nodeById.get(a.from).box.y - nodeById.get(b.from).box.y);
    const targetOrder = [...ordered].sort((a, b) => nodeById.get(a.to).box.y - nodeById.get(b.to).box.y);
    if (ordered.some((edge, index) => edge !== targetOrder[index])) fail('layered edges would cross; choose hub or simplify the relationship.');
  }
  const paths = graph.edges.map((edge) => {
    const from = nodeById.get(edge.from).box; const to = nodeById.get(edge.to).box;
    const lane = Math.round((from.x + from.w + to.x) / 2);
    return `<path d="M${from.x + from.w} ${from.y + CARD_H / 2} H${lane} V${to.y + CARD_H / 2} H${to.x}" class="flow"/>${edgeLabel(edge, lane, Math.min(from.y, to.y) - 8)}`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box)) };
}

const rendered = graph.layout === 'linear' ? linearLayout() : graph.layout === 'hub' ? hubLayout() : graph.layout === 'merge' ? mergeLayout() : layeredLayout();
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(graph.title)}</title>
<style>
:root{color-scheme:light;--diagram-canvas:#f7f4ee;--diagram-surface:#fffdfa;--diagram-ink:#202630;--diagram-muted:#66717d;--diagram-rule:#d7d1c7;--diagram-accent:#d85e40}
:root[data-fluencyloop-theme="dark"]{color-scheme:dark;--diagram-canvas:#171c23;--diagram-surface:#222934;--diagram-ink:#edf1f5;--diagram-muted:#aab4c0;--diagram-rule:#4a5663;--diagram-accent:#ff8d6d}
html,body{width:100%;height:${HEIGHT}px;margin:0;overflow:hidden;background:var(--diagram-canvas)}svg{display:block;width:100%;height:${HEIGHT}px;font-family:system-ui,-apple-system,"Segoe UI",sans-serif}.eyebrow{fill:var(--diagram-muted);font-size:12px;font-weight:700;letter-spacing:.12em}.title{fill:var(--diagram-ink);font-size:24px;font-weight:700}.card{fill:var(--diagram-surface);stroke:var(--diagram-rule);stroke-width:2}.shared{stroke:var(--diagram-accent);stroke-width:3}.name{fill:var(--diagram-ink);font-size:17px;font-weight:700}.name.compact{font-size:15px}.detail{fill:var(--diagram-muted);font-size:13px}.detail.compact{font-size:12px}.flow{fill:none;stroke:var(--diagram-accent);stroke-width:3;stroke-linejoin:round;stroke-linecap:round;marker-end:url(#arrow)}.edge-label-bg{fill:var(--diagram-canvas);stroke:var(--diagram-rule);stroke-width:1}.edge-label{fill:var(--diagram-muted);font-size:11px;font-weight:700;letter-spacing:.04em}.key-rule{stroke:var(--diagram-rule);stroke-width:1}.key-heading{fill:var(--diagram-muted);font-size:10px;font-weight:700;letter-spacing:.12em}.key-flow{fill:none;stroke:var(--diagram-accent);stroke-width:2;marker-end:url(#arrow)}.key-focus{fill:var(--diagram-surface);stroke:var(--diagram-accent);stroke-width:2}.key-text{fill:var(--diagram-muted);font-size:11px}</style>
</head><body><svg viewBox="0 0 ${WIDTH} ${HEIGHT}" role="img" aria-labelledby="diagram-title"><title id="diagram-title">${escapeHtml(graph.title)}</title><defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="var(--diagram-accent)"/></marker></defs><text x="48" y="48" class="eyebrow">ARCHITECTURE</text><text x="48" y="84" class="title">${escapeHtml(graph.title)}</text>${rendered.paths.join('')}${rendered.cards.join('')}${readingKey()}</svg></body></html>`;

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, html, 'utf8');
process.stdout.write(`Rendered ${graph.nodes.length}-node ${graph.layout} diagram to ${output}\n`);
