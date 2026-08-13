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

Do not load the full guide, ask the user to choose a palette, tour templates, or review diagram
alternatives. FluencyLoop owns the surrounding reader design. Produce one restrained,
self-contained embedded HTML file with inline SVG and CSS.

Use the native diagram renderer, not the general diagram workflow:

1. Choose one supported layout without asking: `linear` for a 2–6 step path, `hub` for a shared
   service/boundary with 2–7 participants, or `layered` for independent adjacent-layer mappings.
   It supports 2–8 nodes and at most 10 edges. A fan-out or merge uses `hub`, never `layered`.
2. Run exactly one `fluencyloop diagram` command. Give each node its short id, label, and detail as
   separate fields, then give the directed edges. For example:

   ```bash
   fluencyloop diagram --output docs/fluencyloop/diagrams/product-overview.html --layout hub \
     --title "Dog selection" --hub selection \
     --node list --label "Dog list" --detail "Chooses a dog" \
     --node selection --label "Selection service" --detail "Owns selected dog" \
     --node detail --label "Dog detail" --detail "Reads selected dog" \
     --edge list selection --edge selection detail
   ```

   Keep labels at 28 characters or fewer and details at 42 or fewer. The renderer owns canvas
   height, card positions, routes, attachment points, arrows, dark theme, and no-scroll geometry.
   Never edit its generated HTML.
3. If the renderer rejects a graph, omit the diagram. Do not load a type reference, inspect CSS,
   search the project for styling, browse templates, or escalate to custom SVG during a
   FluencyLoop feature; prose remains the complete explanation.
4. Do not run Playwright, browser automation, screenshots, theme checks, or iterative visual
   inspection. The renderer validates its topology before writing. Confirm only that the file is
   nonempty, then use `fluencyloop site --ensure --open-once --json` when available. Node remains
   optional.

## General diagrams

For any other target, read [the full diagram guide](references/full-guide.md) before generating.
It contains the style-guide gate, type-selection table, visual system, and output checklist. Then
read only the one matching `references/type-*.md` file; do not scan the template gallery.
