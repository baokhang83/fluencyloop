# Plan: Explain architectural records with reader-focused prose and diagrams

started: 2026-08-11

## Goal & scope

- **Goal:** Every new or materially refined architectural record has a concise explanation that
  lets a project reader understand the problem, decision, mechanism, and consequences without
  reopening the feature transcript. Add a diagram only when it materially improves that
  understanding.
- **In scope:** An append-only explanation record and writer, a safe self-contained diagram
  artifact convention, record-detail rendering, and the feature/backfill guidance that produces
  them. Vendor a pinned, attributed copy of `cathrynlavery/diagram-design` so Codex and Claude
  clients receive the same diagram capability with FluencyLoop.
- **Out of scope / non-goals:** Backfilling prose and diagrams for every existing record;
  generating diagrams from code automatically; embedding remote assets or executable JavaScript;
  forcing a visual where prose communicates the decision more clearly.

## Open questions

- No product question remains. The agreed policy is explanation always, diagram only when it
  materially clarifies the record. Existing records can be enriched in a later deliberate pass.

## Architecture

### Concepts

- **Record explanation** — an append-only store record keyed by architectural-record identity;
  carries reader-facing context, decision, mechanism, and consequences. A later explanation
  supersedes an earlier one without altering the underlying architectural record.
- **Diagram companion** — an optional, self-contained HTML/SVG artifact committed under the
  project’s FluencyLoop documentation. Its metadata belongs in the explanation record; no
  diagram metadata means no visual is rendered.
- **Reader renderer** — the local site resolves the latest explanation and safely exposes the
  matching companion on the record detail page, with a prose-only state when no visual exists.
- **Vendored diagram skill** — a pinned snapshot of `cathrynlavery/diagram-design` (upstream
  commit `8827b277395988877ba997b714b43513f764b569`, MIT) packaged beside FluencyLoop skills.
  Feature and backfill workflows consult it only after deciding that a diagram earns its space.
- **Authoring policy** — the feature and backfill skills require the explanation whenever they
  create or materially refine a record. They select the smallest appropriate diagram type,
  preserve an accessible text alternative, and omit a diagram when prose is stronger.

### Relationships and flows

| from | relationship | to | why it matters |
|------|--------------|----|----------------|
| Feature/backfill workflow | appends | Record explanation | Keeps authoring append-only and makes a reader explanation a durable project record. |
| Record explanation | optionally references | Diagram companion | Separates factual explanation from a potentially unnecessary visual artifact. |
| Reader renderer | resolves latest | Record explanation + diagram | Shows a coherent ADR explanation and never fails when a diagram is absent or missing. |
| Vendored diagram skill | guides | Feature/backfill workflow | Gives every supported client the same selection and quality rules without per-user installation. |

## Task breakdown

| id | task (feature intent) | size | depends on |
|----|-----------------------|------|------------|
| T1 | Vendor the pinned MIT diagram-design skill in both client-facing FluencyLoop packages, with attribution and an explicit update policy | M | — |
| T2 | Add the append-only architectural-record explanation schema, writer, and cross-platform tests | M | — |
| T3 | Serve and render explanation prose plus optional safe diagram companions on architectural-record detail pages | M | T2 |
| T4 | Teach feature and backfill workflows to write explanations and use the vendored diagram skill only when a visual materially clarifies the record | M | T1, T2 |
| T5 | Add representative end-to-end fixtures and a documented optional backfill path for existing records | S | T3, T4 |

## Roadmap & critical path

- **Foundation:** T1 and T2 in parallel.
- **Reader:** T3 once the explanation schema exists.
- **Authoring:** T4 once both the vendor skill and writer exist.
- **Confidence and adoption:** T5 after the reader and authoring flows land.
- **Critical path:** T2 → T3 → T5. T1 → T4 is a second gated path; both must complete before
  the capability is ready for normal feature work.

## Constitution check

- **Append-only store:** explanations are new records with a stable identity; corrections append
  and readers select the latest line.
- **Local, dependency-free reader:** diagrams are project-owned HTML/SVG with no remote assets
  or runtime script; the site remains a local reader, not a diagram renderer.
- **Reader clarity:** no decorative diagrams. The author must first establish that prose alone
  would leave an important relationship, flow, state, or boundary unclear.

## Tickets

- Issues and milestone are intentionally deferred until this plan is reviewed. Each task above
  is designed to become one `dev`-targeting feature branch and pull request.
