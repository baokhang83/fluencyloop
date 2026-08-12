#!/usr/bin/env node
'use strict';

// diagram-renderer.js — FluencyLoop's deliberately small diagram compiler. Agents provide a
// bounded graph; this file owns coordinates, attachment points, arrows, themes, and the fixed
// document height used by the sandboxed site iframe.

const fs = require('fs');
const path = require('path');

const usage = `Usage: fluencyloop diagram --output docs/fluencyloop/diagrams/<file>.html
  --layout <linear|hub|layered> --title <title>
  --node <id> --label <label> --detail <detail> [--node ...]
  [--edge <from> <to> ...] [--hub <id>]

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
      graph.edges.push({ from, to });
      break;
    }
    case '--hub': graph.hub = next(); break;
    case '--help': process.stdout.write(`${usage}\n`); process.exit(0); break;
    default: fail(`unknown option: ${arg}`);
  }
}

if (!graph.output || !graph.layout || !graph.title) fail('--output, --layout, and --title are required.');
if (!['linear', 'hub', 'layered'].includes(graph.layout)) fail(`unknown layout: ${graph.layout}`);
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
const HEIGHT = graph.layout === 'hub' ? 520 : 440;

function card(node, box, shared = false) {
  node.box = box;
  const klass = shared ? 'card shared' : 'card';
  const nameY = box.y + box.h / 2 - 8;
  return `<rect x="${box.x}" y="${box.y}" width="${box.w}" height="${box.h}" rx="10" class="${klass}"/>
    <text x="${box.x + 20}" y="${nameY}" class="name">${escapeHtml(node.label)}</text>
    <text x="${box.x + 20}" y="${nameY + 28}" class="detail">${escapeHtml(node.detail)}</text>`;
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
    return `<path d="M${from.x + from.w} ${from.y + CARD_H / 2} H${to.x}" class="flow"/>`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box)) };
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
  hub.box = { x: 380, y: 96, w: CARD_W, h: 380 };
  const spaced = (items, x) => items.forEach((node, index) => {
    const center = Math.round(136 + index * (300 / Math.max(1, items.length - 1)));
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
    const y = Math.round(126 + index * ((HEIGHT - 126 - CARD_H) / Math.max(1, group.length - 1)));
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
    return `<path d="M${from.x + from.w} ${from.y + CARD_H / 2} H${lane} V${to.y + CARD_H / 2} H${to.x}" class="flow"/>`;
  });
  return { paths, cards: graph.nodes.map((node) => card(node, node.box)) };
}

const rendered = graph.layout === 'linear' ? linearLayout() : graph.layout === 'hub' ? hubLayout() : layeredLayout();
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(graph.title)}</title>
<style>
:root{color-scheme:light;--diagram-canvas:#f7f4ee;--diagram-surface:#fffdfa;--diagram-ink:#202630;--diagram-muted:#66717d;--diagram-rule:#d7d1c7;--diagram-accent:#d85e40}
:root[data-fluencyloop-theme="dark"]{color-scheme:dark;--diagram-canvas:#171c23;--diagram-surface:#222934;--diagram-ink:#edf1f5;--diagram-muted:#aab4c0;--diagram-rule:#4a5663;--diagram-accent:#ff8d6d}
html,body{width:100%;height:${HEIGHT}px;margin:0;overflow:hidden;background:var(--diagram-canvas)}svg{display:block;width:100%;height:${HEIGHT}px;font-family:system-ui,-apple-system,"Segoe UI",sans-serif}.eyebrow{fill:var(--diagram-muted);font-size:12px;font-weight:700;letter-spacing:.12em}.title{fill:var(--diagram-ink);font-size:24px;font-weight:700}.card{fill:var(--diagram-surface);stroke:var(--diagram-rule);stroke-width:2}.shared{stroke:var(--diagram-accent);stroke-width:3}.name{fill:var(--diagram-ink);font-size:17px;font-weight:700}.detail{fill:var(--diagram-muted);font-size:13px}.flow{fill:none;stroke:var(--diagram-accent);stroke-width:3;stroke-linejoin:round;stroke-linecap:round;marker-end:url(#arrow)}</style>
</head><body><svg viewBox="0 0 ${WIDTH} ${HEIGHT}" role="img" aria-labelledby="diagram-title"><title id="diagram-title">${escapeHtml(graph.title)}</title><defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="var(--diagram-accent)"/></marker></defs><text x="48" y="48" class="eyebrow">ARCHITECTURE</text><text x="48" y="84" class="title">${escapeHtml(graph.title)}</text>${rendered.paths.join('')}${rendered.cards.join('')}</svg></body></html>`;

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, html, 'utf8');
process.stdout.write(`Rendered ${graph.nodes.length}-node ${graph.layout} diagram to ${output}\n`);
