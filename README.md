
<p align="center">
  <img src="https://github.com/user-attachments/assets/6fda25ee-ec82-48b2-81cf-51052b7045a5" alt="FluencyLoop — stay fluent in the code your AI agent writes" width="300" style="max-width: 100%; height: auto;"/>
</p>

<h1 align="center">FluencyLoop</h1>

<p align="center">
  <a href="https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml"><img src="https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <a href="https://github.com/baokhang83/fluencyloop/releases/latest"><img src="https://img.shields.io/github/v/release/baokhang83/fluencyloop?display_name=tag&amp;sort=semver" alt="Latest release"/></a>
  <a href="https://github.com/baokhang83/fluencyloop/stargazers"><img src="https://img.shields.io/github/stars/baokhang83/fluencyloop?style=social" alt="GitHub stars"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/baokhang83/fluencyloop" alt="Apache-2.0 license"/></a>
  <a href="CONTRIBUTING.md#project-status"><img src="https://img.shields.io/badge/status-beta-blue" alt="Status beta"/></a>
</p>

<p align="center">FluencyLoop captures the decisions behind each feature while your agent builds it,<br/>so the codebase stays explainable after the chat ends.</p>

## Table of contents

- [🧭 The workflow](#workflow)
- [✨ What it gives you](#what-it-gives-you)
- [🧱 What gets committed](#what-gets-committed)
- [📦 Install](#install)
- [🗑️ Uninstall](#uninstall)
- [💬 Help shape FluencyLoop](#help-shape-fluencyloop)
- [✅ Requirements](#requirements)
- [📚 More detail](#more-detail)
- [📄 License](#license)

<a id="workflow"></a>

## 🧭 The workflow

Initialize the project once, then run one feature loop per branch. Use **plan** only when the work
is too large for a single feature.

| Step | Claude Code | Codex | What it does |
|------|-------------|-------|--------------|
| **1. Initialize** | `fluencyloop init` | `fluencyloop init` | Creates the project state and an empty constitution. Plan and feature also do this automatically if needed. |
| **2. Plan (optional)** | `/fluencyloop:plan <initiative description>` | `$fluencyloop:plan <initiative description>` | Designs the architecture and breaks a large initiative into feature-sized tasks. |
| **3. Build + learn** | `/fluencyloop:feature <feature description>` | `$fluencyloop:feature <feature description>` | Creates a feature branch and design, builds in slices, teaches each real decision, and journals it. |
| **4. Review** | `/fluencyloop:review` | `$fluencyloop:review` | Assembles the branch's sessions and decisions into a reviewer-facing PR view. |

For normal-sized work, the practical path is **init → feature → review**. For a large initiative,
run **plan** first, then repeat **feature → review** for each task in its roadmap.

If work was merged without the loop, use `/fluencyloop:backfill` in Claude Code or
`$fluencyloop:backfill` in Codex to reconstruct its design and decisions. Reconstructed decisions
are recorded as unverified by default; verification is optional and never blocks the backfill.

FluencyLoop also bundles `diagram-design` for architectural explanations. It is available to both
clients after the normal plugin update; FluencyLoop uses it only when a diagram makes a record
clearer than prose alone.

<a id="what-it-gives-you"></a>

## ✨ What it gives you

### 📜 A living constitution

The constitution is a short set of checkable engineering principles for the project. It starts
from the first real plan or feature and grows when a decision reveals a repeatable stance. Every
later design and review is checked against it, but it never blocks a conventional merge.

### 🧠 Knowledge transfer, taught to your level

FluencyLoop teaches at the moment a meaningful decision is made. It explains the mechanism, the
reason for the chosen path, and the rejected alternative, then checks that the explanation landed
before continuing when the topic is unfamiliar.

It maintains a private, per-developer knowledge base of domain familiarity and demonstrated
engagement. That profile carries across projects and features, keeping explanations concise on
familiar ground and deeper where knowledge is still forming. It is never committed to a project;
only person-neutral knowledge-transfer notes about the software enter the documentation.

### 🗂️ Project records that follow the code

Plans, feature sessions, decisions, knowledge, architectural records, and requirements live beside
the code under `docs/fluencyloop/store/` as append-only JSONL. Small, bounded Markdown
distillations add product-level prose where it helps; the legacy feature Markdown remains read-only
input for migration.

### 🖥️ A local project knowledge site (http://127.0.0.1:44444)

When Node.js is available, FluencyLoop turns those committed records into a local website for the
project. It is a useful map of the software rather than a folder browser: the overview explains the
product shape, Architectural Records capture the durable ideas and their tags, Features show what
changed over time, and each feature leads to the decisions and knowledge that explain it.

The site resolves the latest version of append-only records, groups related work, makes category
tags clickable filters, and keeps the date and commit beside every item. It is deliberately local:
it binds only to `127.0.0.1`, reads the repository on your machine, and sends no project knowledge
to a service. Open it during implementation, review, or onboarding to answer the practical
questions: *What is this product? What ideas shape it? When did this change, and why?*

### ⚖️ Decision tracking with rationale

Each real fork records what was chosen, where it applies, why it was chosen, which alternative was
rejected, how it relates to the constitution and design, and whether the rationale was verified.
Reviewers get the decisions that shaped the feature instead of only a list of changed files.

<a id="what-gets-committed"></a>

## 🧱 What gets committed

```text
docs/fluencyloop/
├── constitution.md
├── store/
│   ├── concepts.jsonl
│   └── features/<feature>.jsonl
├── distillations/
│   ├── product.md
│   ├── features/<feature>.md
│   └── concepts/<record>.md
└── diagrams/
    ├── product-overview.html
    └── records/<record>.html
```

`.fluencyloop/` contains project workflow state. The per-developer calibration profile lives in
`~/.fluencyloop/`; it controls teaching depth and is never committed. Store records describe the
work, never the person.

<a id="install"></a>

## 📦 Install

### Claude Code

```text
/plugin marketplace add baokhang83/fluencyloop
/plugin install fluencyloop@fluencyloop
```

Use the namespaced slash commands shown above. The plugin bundles its deterministic CLI, so there
is no separate system-wide FluencyLoop installation.

<details>
<summary>Claude Code updates and Windows approvals</summary>

FluencyLoop's startup hook checks its own marketplace on each new session and, when an update is
available, installs it for the next session without changing the active one. Run
`/reload-plugins` to activate it in the current session instead. The check runs at startup only;
resuming, clearing, or compacting a session does not repeat it.

To update at any time by hand, run `/plugin marketplace update fluencyloop`, then
`/plugin update fluencyloop@fluencyloop`, and finally `/reload-plugins`.

The startup check is best-effort and deliberately silent, because a session must never fail to
start over an update it could not fetch. If the `claude` CLI is absent from the `PATH`, or the
network or a policy blocks the marketplace, the session starts normally and reports nothing. Run
`claude plugin list` to see the version you are actually running, and use the manual commands
above if it looks stale.

Claude Code's own **Enable auto-update** toggle (`/plugin` → **Marketplaces** → **fluencyloop**)
is a separate control that stays off by default. FluencyLoop refreshes only its own package and
does not read or change that setting.

On native Windows, use the project-scoped setup in
[Claude Code approvals](docs/claude-code-permissions.md) to reduce routine FluencyLoop, editing,
and read-only Git prompts without granting broad Git or Bash access.
</details>

### Codex

```bash
codex plugin marketplace add baokhang83/fluencyloop
codex plugin add fluencyloop@fluencyloop
```

Use the `$fluencyloop:<stage>` skills shown above. The plugin maintains its own `fluencyloop`
command shim on macOS, Linux, Git Bash, and WSL; no separate runtime installation is required.

<details>
<summary>Codex updates</summary>

Codex asks you to review FluencyLoop's startup hook once. Approve it from `/hooks` to enable
automatic updates. Each new session checks only FluencyLoop's marketplace and, when an update is
available, installs it for the next session without changing the active one.

Like the Claude Code check, this one is best-effort and silent: an unapproved hook, a missing
`codex` CLI, or a blocked marketplace leaves the session running its current version without
reporting anything. Run `fluencyloop version` to see the version the Codex install is actually
running. To update by hand, run `codex plugin marketplace upgrade fluencyloop`, then
`codex plugin add fluencyloop@fluencyloop`; the next session picks it up.

</details>

<a id="uninstall"></a>

## 🗑️ Uninstall

Removing FluencyLoop removes the client plugin and its cached files. It does not modify your
projects, their `.fluencyloop/` state, or committed `docs/fluencyloop/` records.

### Claude Code

```text
/plugin uninstall fluencyloop@fluencyloop
/plugin marketplace remove fluencyloop
```

### Codex

```bash
codex plugin remove fluencyloop@fluencyloop
codex plugin marketplace remove fluencyloop
```

<a id="help-shape-fluencyloop"></a>

## 💬 Help shape FluencyLoop

Have you tried FluencyLoop, stopped during setup, or only looked through the workflow? Share where
you are and what helped or got in the way in
[the adoption feedback discussion](https://github.com/baokhang83/fluencyloop/discussions/69).
Critical feedback is especially useful and a one-line response is enough.

<a id="requirements"></a>

## ✅ Requirements

FluencyLoop requires [Claude Code](https://claude.com/claude-code) or
[Codex](https://developers.openai.com/codex/), `git`, and either Bash on macOS/Linux/Git Bash/WSL
or PowerShell (`pwsh`) on native Windows.

Node.js is **optional**. The feature loop, planning, store, importer, review, and doctor work
without it. Only the local `fluencyloop site` knowledge website needs **Node.js 18 or newer**,
using built-in Node modules; when it is missing, that command explains how to install it without
interrupting the rest of the loop.

When a Claude Code or Codex session opens in an initialized project with Node available,
FluencyLoop quietly starts its local knowledge website and reports the exact loopback URL at the first
FluencyLoop interaction. It prefers `http://127.0.0.1:44444` and safely uses the next port when
that one is busy. The site stays available while one or more agent sessions are active in that
project, then returns to its normal inactivity timeout after the final session ends.

You can manage the site directly too:

```bash
fluencyloop site --ensure    # start or reuse the project knowledge site
fluencyloop site --status    # print the current URL and lifecycle state
fluencyloop site --stop      # stop this project's managed site
```

The store-facing commands are `fluencyloop session`, `fluencyloop decision`,
`fluencyloop knowledge`, `fluencyloop concept`, `fluencyloop record-explanation`, and
`fluencyloop requirement`. The installed Claude Code and Codex skills select them as part of the
normal plan, feature, backfill, and review workflows.

<a id="more-detail"></a>

## 📚 More detail

Read [MANIFESTO.md](MANIFESTO.md) for the product principles, calibration and privacy model, and
the boundary between deterministic tooling and agent reasoning. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the repository layout, test commands, and distribution notes.

<a id="license"></a>

## 📄 License

[Apache-2.0](LICENSE).
