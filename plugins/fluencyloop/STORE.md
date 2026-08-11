# FluencyLoop store schema

The FluencyLoop store is append-only JSONL. Each line is one compact JSON object, written by a
shell script with `store_append` or `FlStoreAppend`. Shell writers only append; they never parse
or rewrite the store. The site and the model are readers.

This is the sole schema reference for `docs/fluencyloop/store/`. Do not duplicate its field list in
skills, templates, or scripts.

## Version and reader rule

The current schema version is `"1"`. Every new record writes `schema_version`; a record without
that field is read as generation 1, matching the existing `state.json` compatibility rule.

A correction is a new record, never an edit to an old line. A reader selects the **last** line for
the record type and identity below; later lines therefore supersede earlier lines. File order is
the order of authority. `ts` is context, not an ordering key.

The identity always includes `type`, even where the table lists only the remaining fields.

| type | identity after `type` | writer |
|---|---|---|
| `feature` | `slug` | A3 |
| `session` | `feature`, `slug` | A3 |
| `decision` | `feature`, `session`, `where`, `title` | A3 |
| `component` | `feature`, `session`, `name` | A4 |
| `condition` | `feature`, `session`, `subject` | A4 |
| `concept` | `name` | A5 |
| `relation` | `from`, `to`, `kind` | A5 |
| `record_explanation` | `record` | Architectural-record explanation writer |
| `principle` | `number` | C1 |
| `requirement` | `feature`, `gap` | B2 |
| `open_question` | `feature`, `gap` | B2 |

Identity fields must be stable strings. When a record is repository-wide rather than tied to a
feature or session, use `"global"` for `feature` and `"none"` for `session`. Use the current HEAD
SHA for `commit`; use `"uncommitted"` only when no commit can truthfully identify the observed
work. Those explicit values keep the envelope present without making an empty value meaningful.

## Common envelope

Every record has these fields. Values are strings because the shell append primitive assembles
string key/value pairs. `ts` is the ISO calendar date produced by `today()` or `FlToday`.

| field | meaning | writer |
|---|---|---|
| `schema_version` | Store schema generation; currently `"1"`. | All milestone writers |
| `type` | One of the ten record types in this document. | All milestone writers |
| `ts` | Date the record was observed or corrected, in `YYYY-MM-DD` form. | All milestone writers |
| `feature` | Feature slug, or `"global"` for repository-wide records. | All milestone writers |
| `session` | Session slug, or `"none"` outside a session. | All milestone writers |
| `commit` | HEAD SHA that identifies the observed work, or `"uncommitted"`. | All milestone writers |

All payload fields below are written by the named 0.3 issue; none are reserved in generation 1.
Writers omit optional payload values rather than writing empty strings, as required by the append
primitive. Identity fields and the common envelope are never optional.

`imported_from` is an optional A6 payload marker on records reconstructed from legacy Markdown. It
is a stable legacy path plus a record identifier: decision/component/condition records use their
source file and ordinal, while the synthetic feature and backfill-session declarations use the
feature directory. The importer scans only for that literal marker to avoid writing a duplicate on
a later run.

## Records

### `feature`

Declares a feature and the branch context in which it began. `slug` equals the envelope's
`feature` value.

| payload field | meaning | writer |
|---|---|---|
| `slug` | Stable feature slug. | A3 |
| `intent` | The feature's stated outcome. | A3 |
| `branch` | Git branch for the feature. | A3 |
| `base_ref` | Branch the feature was cut from. | A3 |

```json
{"schema_version":"1","type":"feature","ts":"2026-08-08","feature":"a2-store-schema","session":"none","commit":"7f8ff2e","slug":"a2-store-schema","intent":"document the record schema","branch":"feature/store-record-schema","base_ref":"dev"}
```

### `session`

Declares one build session. Its payload `slug` equals the envelope's `session` value.

| payload field | meaning | writer |
|---|---|---|
| `slug` | Stable session slug within the feature. | A3 |
| `intent` | The slice of work covered by this session. | A3 |

```json
{"schema_version":"1","type":"session","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","slug":"001-schema-contract","intent":"define the append-only reader contract"}
```

### `decision`

Captures a taught implementation fork. Its payload is unchanged from the existing
`fluencyloop decision` CLI surface.

| payload field | meaning | writer |
|---|---|---|
| `title` | Short name for the decision. | A3 |
| `where` | Stable file or area, never a line number. | A3 |
| `why` | Rationale for the choice. | A3 |
| `alternative` | Rejected option and why it was rejected. Optional. | A3 |
| `design` | Design reference such as `../design.md#store`. Optional. | A3 |
| `constitution` | Cited constitution principle, such as `§2`. Optional. | A3 |
| `trust` | `verified` or `unverified`, describing the decision's evidence. | A3 |

```json
{"schema_version":"1","type":"decision","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","title":"read corrections from the last line","where":"plugins/fluencyloop/STORE.md","why":"append-only writers cannot safely rewrite prior JSONL","alternative":"rewrite the earlier record, rejected because shell writers only append","design":"docs/fluencyloop/features/a2-store-schema/design.md#store","constitution":"§2","trust":"verified"}
```

### `component`

Captures a component explained at session close.

`fluencyloop knowledge` uses `|` between its input fields. Write a literal pipe as `\|` and a
literal backslash as `\\`; the stored record contains the literal characters. Components use
`name|role|conditions` with an optional final `|status` (`documented` is the default), and gotchas
use `subject|why`.

| payload field | meaning | writer |
|---|---|---|
| `name` | Component or mechanism name. | A4 |
| `role` | What it does in the product. | A4 |
| `conditions` | Conditions under which its role matters. | A4 |
| `status` | `documented` or `follow-up`. | A4 |

```json
{"schema_version":"1","type":"component","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","name":"store reader","role":"selects the current record for each identity","conditions":"must use file order for supersession","status":"documented"}
```

### `condition`

Captures a hard-won condition: the non-obvious fact and what breaks without it.

| payload field | meaning | writer |
|---|---|---|
| `subject` | The condition or constraint. | A4 |
| `why` | Why it exists or what fails otherwise. | A4 |

```json
{"schema_version":"1","type":"condition","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","subject":"read the final matching line","why":"the first line can have been superseded by a correction"}
```

### `concept`

Defines an architectural concept in the product's own terms. Concepts live in the global stream
but retain the feature and session that last established them.

| payload field | meaning | writer |
|---|---|---|
| `name` | Stable concept name. | A5 |
| `problem` | Product problem the concept solves. | A5 |
| `how` | How the concept works. | A5 |
| `realized_by` | One or more components or code areas that realize it, newline-delimited. | A5 |
| `tags` | One or more widely-known architectural concepts this is an instance of, newline-delimited. Optional. | A5 |

A concept's `name` is the product's own vocabulary, which a newcomer has never seen. `tags` name the
general, widely-recognized ideas behind it, so a reader can attach the unfamiliar name to something
already known. Each tag is at most three words, and names the general pattern rather than restating
the concept: `append-only log`, `event sourcing`, `read model`, `idempotency`, `cache invalidation`.

```json
{"schema_version":"1","type":"concept","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","name":"supersede on read","problem":"correct append-only records without rewriting history","how":"the reader keeps the last record for an identity","realized_by":"the site store reader","tags":"append-only log\nevent sourcing"}
```

### `relation`

Connects two concepts, components, or features. `kind` states the directed relationship.

| payload field | meaning | writer |
|---|---|---|
| `from` | Source identity or name. | A5 |
| `to` | Target identity or name. | A5 |
| `kind` | Relationship from `from` to `to`. | A5 |

```json
{"schema_version":"1","type":"relation","ts":"2026-08-08","feature":"a2-store-schema","session":"001-schema-contract","commit":"7f8ff2e","from":"supersede on read","to":"store reader","kind":"realized_by"}
```

### `record_explanation`

Explains an architectural record in reader-facing ADR terms. The record lives in the global stream
because it supersedes by the architectural record's stable `record` name, while `feature` and
`session` retain the work that last explained it. An explanation is required whenever a feature
creates or materially refines an architectural record.

| payload field | meaning | writer |
|---|---|---|
| `record` | Exact architectural-record name being explained. | Architectural-record explanation writer |
| `context` | The situation and problem that made the decision necessary. | Architectural-record explanation writer |
| `decision` | The design choice the record establishes. | Architectural-record explanation writer |
| `mechanism` | How the choice works in this project. | Architectural-record explanation writer |
| `consequences` | Important benefits, trade-offs, or operating constraints. | Architectural-record explanation writer |
| `diagram_path` | Project-relative self-contained HTML/SVG companion under `docs/fluencyloop/diagrams/records/`. Optional. | Architectural-record explanation writer |
| `diagram_type` | Diagram grammar selected because it clarifies the record. Required with `diagram_path`. | Architectural-record explanation writer |
| `diagram_alt` | Concise text alternative for the companion. Required with `diagram_path`. | Architectural-record explanation writer |

Do not add a diagram merely to decorate the record. If prose explains the decision more clearly,
omit all three diagram fields. A diagram companion contains no remote assets or executable script.

```json
{"schema_version":"1","type":"record_explanation","ts":"2026-08-11","feature":"record-explanations","session":"001-store-contract","commit":"7f8ff2e","record":"supersede on read","context":"The store cannot rewrite a historical JSONL line after it is shared.","decision":"Treat the last matching line as the current record.","mechanism":"Readers scan the append-only stream in file order and retain the final identity match.","consequences":"Corrections remain auditable and mergeable; every reader must apply the same identity rule."}
```

### `principle`

Captures one developer-authored constitution principle. Constitution distillation remains in
`constitution.md`; this record makes the principle linkable in the site.

| payload field | meaning | writer |
|---|---|---|
| `number` | Numbered citation, such as `§2`. | C1 |
| `title` | Short principle title. | C1 |
| `rule` | Checkable, non-negotiable rule. | C1 |
| `why` | Failure the rule prevents. | C1 |

```json
{"schema_version":"1","type":"principle","ts":"2026-08-08","feature":"global","session":"none","commit":"7f8ff2e","number":"§2","title":"Append-only store","rule":"Store writers append one JSON object per line and never rewrite an existing record.","why":"history remains mergeable and corrections stay auditable"}
```

### `requirement`

Captures an answered planning gap and the effect its answer has on the work.

| payload field | meaning | writer |
|---|---|---|
| `gap` | Unstated or conflicting requirement that needed an answer. | B2 |
| `answer` | Developer-provided answer. | B2 |
| `consequence` | What the answer changes in the work. | B2 |

```json
{"schema_version":"1","type":"requirement","ts":"2026-08-08","feature":"a2-store-schema","session":"none","commit":"7f8ff2e","gap":"How does a correction preserve history?","answer":"Append a new record and select the last matching identity on read.","consequence":"Readers need deterministic identity keys for every record type."}
```

### `open_question`

Captures a planning gap that remained unanswered instead of silently assigning it a default.

| payload field | meaning | writer |
|---|---|---|
| `gap` | Unanswered requirement or contradiction. | B2 |
| `why_it_matters` | Consequence of leaving it open. | B2 |

```json
{"schema_version":"1","type":"open_question","ts":"2026-08-08","feature":"a2-store-schema","session":"none","commit":"7f8ff2e","gap":"Which visual form best explains a concept?","why_it_matters":"The site must choose prose, a table, or a diagram deliberately rather than requiring a fixed diagram."}
```
