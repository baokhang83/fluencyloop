---
name: diagram-design
description: Create technical and product diagrams as standalone HTML files with inline SVG. Use for architecture, flow, sequence, state, data, process, and other diagrams; choose the appropriate type and follow its reference. For FluencyLoop product-overview and architectural-record diagrams, use the embedded fast path.
---

# Diagram Design

Create one self-contained HTML file with inline SVG and CSS. Use a diagram only when it explains a
relationship, flow, or structure better than prose or a table.

## FluencyLoop embedded diagram fast path

Use this path when FluencyLoop asks for either
`docs/fluencyloop/diagrams/product-overview.html` or a file under
`docs/fluencyloop/diagrams/records/`. For a product overview, its prose is always
`docs/fluencyloop/distillations/product.md`; its companion is always
`docs/fluencyloop/diagrams/product-overview.html`. Never write `docs/fluencyloop/product.md`.
It is a focused companion inside FluencyLoop's local site, not a branded design-system deliverable.

FluencyLoop owns the surrounding site design, but the diagram must still describe the product
faithfully. Use a self-contained HTML document with inline SVG and CSS: no scripts, remote URLs,
remote fonts, iframes, or embedded executable content. Support the reader's themes with local
light tokens and a `:root[data-fluencyloop-theme="dark"]` token override.

Choose the rendering path by topology, not by the convenience of the renderer:

1. Use the native renderer only when one of its layouts faithfully captures every material node
   and relationship: `linear` for a 2–6 step path, `hub` for a shared service/boundary with 2–7
   direct participants, `merge` for inputs or short chains that end at one result, or `layered`
   for one-to-one adjacent-layer mappings. It supports 2–8 nodes and at most 10 edges. A graph
   with parallel flows that merge and then continue to another boundary does **not** fit these
   layouts; never recast the architecture merely to make the command pass.
2. For a fitting native graph, run exactly one `fluencyloop diagram` command. Give each node its
   short id, label, and detail as separate fields, then give the directed edges. For example:

   ```bash
   fluencyloop diagram --output docs/fluencyloop/diagrams/product-overview.html --layout hub \
     --title "Dog selection" --hub selection \
     --node list --label "Dog list" --detail "Chooses a dog" \
     --node selection --label "Selection service" --detail "Owns selected dog" \
     --node detail --label "Dog detail" --detail "Reads selected dog" \
     --edge list selection --edge selection detail
   ```

   Add `--edge-label <short relationship>` directly after an edge in a `merge` diagram. Keep node
   labels at 20 characters or fewer, details at 32 or fewer, and relationship labels at 24 or
   fewer. The renderer owns canvas height, card positions, routes, attachment points, arrows,
   relationship labels, dark theme, and no-scroll geometry. Never edit its generated HTML.
3. For any graph that does not fit, use the general workflow: read
   [the full guide](references/full-guide.md), then read exactly one relevant type reference
   (`type-architecture.md` for component topology or `type-data-flow.md` for role-scoped flows).
   Apply its hierarchy, connector, and pre-output rules. For this embedded fallback, retain the
   FluencyLoop contract above instead of the full guide's remote-font, first-time style gate, or
   page-chrome examples. The generated artifact must be a static, local, theme-aware HTML/SVG
   document at the fixed FluencyLoop path.
4. Do not omit a diagram solely because the native renderer rejects a valid graph. Omit it only
   when prose or a table communicates the relationship better. Confirm the generated file is
   nonempty, contains no active or remote content, and can be opened through
   `fluencyloop site --ensure --open-once --json` when available. Node remains optional.

### Self-containment gate — verify before recording

An embedded diagram that the reader rejects is not delivered. The full guide's Google-font
`<link>` example and any remote-font, icon, image, stylesheet, or script snippet are forbidden in
this path. Use only inline SVG and CSS with a system/local font stack; an SVG fragment reference
such as `url(#arrow)` is fine, but an external URL is not.

Before writing diagram metadata or reporting completion, run a static scan of the finished HTML.
It must reject `<link>`, `<script>`, `<iframe>`, `<object>`, and `<embed>` tags; event-handler
attributes; remote or protocol-relative `src`, `href`, or CSS `url(...)`; and CSS `@import`.
Then open the diagram through its local reader route and confirm it renders with no `Diagram
unavailable` notice. If either check fails, remove the external or executable content and repeat
both checks after every revision. Do not record or hand off a diagram merely because its file
exists.

### Embedded iframe contract — no scrollbars

The local reader already supplies the figure frame and caption. The embedded document contains only
the diagram: no HTML page title, eyebrow, header, footer, outer `.frame` wrapper, or body padding.
It **must** include a visible, concise title as an SVG `<text>` element near the top. An HTML
`<title>` is metadata, not a visible title. Reserve a dedicated top band of at least 40 SVG units
for it; do not let a zone, connector, or node occupy that band. Set `html, body { margin: 0;
padding: 0; overflow: hidden; }` and render the SVG with `display: block; width: 100%;
max-width: 100%; height: auto; min-width: 0`. Never add `overflow: auto`,
`overflow-x: auto`, or a positive SVG `min-width` to an embedded diagram.

Before handoff, inspect the iframe at the reader's actual dimensions. Its document must satisfy
`scrollWidth <= clientWidth` and `scrollHeight <= clientHeight`; there must be no horizontal or
vertical scrollbar. Calculate the SVG's rendered height from its `viewBox` and available iframe
width, and keep it within the reader's fixed 33rem height. If the composition does not fit, reduce
its visual density, choose a wider/shorter layout, or split the explanation—never add a scroller.

### Geometry preflight — no cramped or escaping content

Before delivering an embedded diagram, validate the rendered SVG in the local reader at its actual
iframe width. This applies to native-renderer candidates and fallback HTML alike:

- Measure every visible text element with the chosen font and size (for example, with SVG
  `getBBox()` or `getComputedTextLength()` in a browser); character count is not a fit check. Its
  measured bounds must remain inside its intended node with at least 12 SVG units of horizontal
  and 8 units of vertical clearance. Widen or heighten the node, use deliberate two-line text, or
  choose a shorter faithful label — never let a label escape or clip.
- A node inside a dashed or solid region must leave at least 16 SVG units between its outer stroke
  and every region edge. Derive each region *after* placing its nodes: use at least 24 SVG units at
  its left, right, and bottom, and reserve at least 40 SVG units above its first node for the zone
  label and breathing room. Do not set a node edge equal to a region edge or hide a collision with
  clipping. If those bounds do not fit, rearrange the nodes or split the visual; never squeeze a
  dashed boundary against a node.
- Check both light and dark themes. If a native-renderer result fails either check, it does not fit
  this graph: use the general fallback rather than editing generated HTML or accepting cramped
  geometry. This is a design loop, not a one-shot fallback: measure the fallback, revise its
  node sizes, text treatment, region bounds, or layout, then measure again after every revision.
  Deliver it only after it passes every geometry check. If a clear fallback cannot pass, simplify
  the visual or keep the explanation in prose or a table; never ship a failed first pass.
- Inspect the completed reader rendering, not only the source. Confirm that the SVG title is
  visible and that every dashed boundary has clear space around its enclosed nodes. A missing title
  or even one node visually touching a boundary fails the preflight and requires another revision.

## Non-embedded diagrams

For any other target, read [the full diagram guide](references/full-guide.md) before generating.
It contains the style-guide gate, type-selection table, visual system, and output checklist. Then
read only the one matching `references/type-*.md` file; do not scan the template gallery.
