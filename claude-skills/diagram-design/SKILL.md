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
`docs/fluencyloop/diagrams/records/`. It is a focused companion inside FluencyLoop's local reader,
not a branded design-system deliverable.

Do not load the full guide, ask the user to choose a palette, tour templates, or review diagram
alternatives. FluencyLoop owns the surrounding reader design. Produce one restrained,
self-contained embedded HTML file with inline SVG and CSS.

Work in one bounded pass:

1. Choose the type without asking: use **architecture** for component ownership or system shape,
   **flowchart** for a directed interaction or decision path, and **sequence** only when message
   order between distinct actors is the point. For an architectural record, apply the same rule to
   its ADR mechanism. Load only that one type reference.
2. Use 4–7 nodes and 3–8 connectors. Show only the relationship that earns the diagram; a product
   overview must not become a feature inventory.
3. Write directly to the requested path. For `product-overview.html`, keep `product.md` as prose;
   do not add a Mermaid duplicate of the HTML diagram. Use only inline SVG and CSS with system
   font stacks: no Google Fonts `<link>`, remote `src`/`href`, CSS `url(...)`, scripts, or iframes.
4. Confirm the file is nonempty, then run `fluencyloop site --ensure --open --json` when available
   so the reader opens at its local URL. Do not block the feature if Node is unavailable; say that
   the prose is available and the diagram will appear when the optional site can run.

## General diagrams

For any other target, read [the full diagram guide](references/full-guide.md) before generating.
It contains the style-guide gate, type-selection table, visual system, and output checklist. Then
read only the one matching `references/type-*.md` file; do not scan the template gallery.
