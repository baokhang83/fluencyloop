#!/usr/bin/env bats
# Agent plugin packages: metadata stays aligned with the bundled runtime, and neither agent
# relies on the retired machine-wide installer.

load test_helper

@test "Claude Code and Codex marketplace packages describe the same runtime" {
    run python3 - "$REPO_ROOT" "$DIST" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
dist = pathlib.Path(sys.argv[2])

def read_text(path):
    return path.read_text(encoding="utf-8")

version = read_text(dist / "VERSION").strip()
claude_plugin = json.loads(read_text(root / ".claude-plugin" / "plugin.json"))
claude_marketplace = json.loads(read_text(root / ".claude-plugin" / "marketplace.json"))
codex_plugin = json.loads(read_text(dist / ".codex-plugin" / "plugin.json"))
codex_marketplace = json.loads(read_text(root / ".agents" / "plugins" / "marketplace.json"))

assert claude_plugin["name"] == codex_plugin["name"] == "fluencyloop"
assert claude_plugin["version"] == codex_plugin["version"] == version
assert claude_plugin["license"] == codex_plugin["license"] == "Apache-2.0"
assert claude_marketplace["name"] == codex_marketplace["name"] == "fluencyloop"

claude_entry, = claude_marketplace["plugins"]
assert claude_entry["source"] == "."
assert claude_entry["version"] == version
codex_entry, = codex_marketplace["plugins"]
assert codex_entry["name"] == "fluencyloop"
assert codex_entry["source"] == {"source": "local", "path": "./plugins/fluencyloop"}
assert codex_entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}
assert codex_entry["category"] == "Productivity"
assert codex_plugin["skills"] == "./skills/"

hooks = json.loads(read_text(dist / "hooks" / "hooks.json"))
handler, = hooks["hooks"]["SessionStart"][0]["hooks"]
assert hooks["hooks"]["SessionStart"][0]["matcher"] == "startup|resume"
assert handler["type"] == "command"
assert 'plugin_root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"' in handler["command"]
assert "CLAUDE_PLUGIN_ROOT" in handler["commandWindows"]
assert "refresh-marketplace.sh" in handler["command"]
assert "refresh-marketplace.ps1" in handler["commandWindows"]
assert '[ -f "$hook" ]' in handler["command"]
assert "Test-Path -LiteralPath $hook -PathType Leaf" in handler["commandWindows"]
assert (dist / "hooks" / "refresh-marketplace.sh").is_file()
assert (dist / "hooks" / "refresh-marketplace.ps1").is_file()
assert "ensure_local_site" in read_text(dist / "hooks" / "refresh-marketplace.sh")
assert "site --ensure --open-once --json" in read_text(dist / "hooks" / "refresh-marketplace.sh")
assert "Ensure-LocalSite" in read_text(dist / "hooks" / "refresh-marketplace.ps1")
assert "site --ensure --open-once --json" in read_text(dist / "hooks" / "refresh-marketplace.ps1")
end_handler, = hooks["hooks"]["SessionEnd"][0]["hooks"]
assert end_handler["type"] == "command"
assert "--session-end" in end_handler["command"]
assert "--session-end" in end_handler["commandWindows"]
assert end_handler["timeout"] == 3

for alias, source in {
    "plan": "plan",
    "feature": "feature",
    "review": "review",
    "backfill": "backfill",
}.items():
    alias_text = read_text(root / "claude-skills" / alias / "SKILL.md")
    source_text = read_text(dist / "skills" / source / "SKILL.md")
    assert f"name: {alias}" in alias_text
    assert f"name: {source}" in source_text
    assert '"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" <arguments>' in alias_text
    assert "it is never a chat instruction" in alias_text
    assert "globally installed" in alias_text
    assert "## Bundled CLI (Codex)" in source_text
    assert "~/.local/bin/fluencyloop" in source_text
    assert "Invoke `fluencyloop …` directly" in source_text
    assert "## Local site — open once" in alias_text
    assert "site --ensure --open-once --json" in alias_text
    assert "FluencyLoop site: <url>" in alias_text
    assert "## Local site — open once" in source_text
    assert "site --ensure --open-once --json" in source_text
    assert "FluencyLoop site: <url>" in source_text
    assert "## Generated prose — ASD-STE100" in alias_text
    assert "## Generated prose — ASD-STE100" in source_text
    assert "Do not claim formal\nASD-STE100 compliance" in alias_text
    assert "Do not claim formal\nASD-STE100 compliance" in source_text
    if alias == "feature":
        assert "Apply this style to live decision-boundary teaching" in alias_text
        assert "Apply this style to live decision-boundary teaching" in source_text
router_text = read_text(dist / "skills" / "fluencyloop" / "SKILL.md")
assert "## Local site — open once" in router_text
assert "site --ensure --open-once --json" in router_text
assert "Literal CLI Fast Path above remains exempt" in router_text
feature_text = read_text(root / "claude-skills" / "feature" / "SKILL.md")
assert "**Refuse split state.**" in feature_text
assert "state_matches_branch" in feature_text
assert "Do not create a new feature, switch branches, or overwrite state" in feature_text
assert "Resume preconditions after the answer." in feature_text
assert "Immediately rerun `fluencyloop check --json`" in feature_text
assert "**Migrate imported history before normal feature work.**" in feature_text
assert "legacy_migration_pending" in feature_text
assert "Claude fast path" in feature_text
assert "fluencyloop import --assess-unconfirmed" in feature_text
assert "fluencyloop import --semantic-map" in feature_text
assert "fluencyloop import --mark-semantic-complete" in feature_text
assert "fluencyloop import --semantic-status --json" in feature_text
assert "Do not open 46" in feature_text
assert "unconfirmed assessment" in feature_text
assert "Separate means independent." in feature_text
assert "Create PR bodies through a file." in feature_text
assert "never exclude the\n  completed legacy migration" in feature_text
assert "If `git_repo` or `fluency` is" in feature_text
assert "without asking the developer" in feature_text
assert "`store` must be a path under `docs/fluencyloop/`" in feature_text
codex_feature_text = read_text(dist / "skills" / "feature" / "SKILL.md")
assert "**Refuse split state.**" in codex_feature_text
assert "state_matches_branch" in codex_feature_text
assert "Do not create a new feature, switch branches, or overwrite state" in codex_feature_text
assert "Resume preconditions after the answer." in codex_feature_text
assert "Immediately rerun `fluencyloop check --json`" in codex_feature_text
assert "complete the mandatory migration before calibration, preferences, ticket numbering" in codex_feature_text
assert "**Migrate imported history before normal feature work.**" in codex_feature_text
assert "legacy_migration_pending" in codex_feature_text
assert "ticket numbering" in codex_feature_text
assert "fluencyloop import --mark-semantic-complete" in codex_feature_text
assert "fluencyloop import --semantic-status --json" in codex_feature_text
assert "This is required for every imported feature" in codex_feature_text
assert "Do not probe writer commands." in codex_feature_text
assert "every `--assess` follows its own read" in codex_feature_text
assert "Separate means independent." in codex_feature_text
assert "Create PR bodies through a file." in codex_feature_text
assert "never exclude the\n  completed legacy migration" in codex_feature_text
assert "### Codex teaching gate - visible before the journal" in codex_feature_text
assert "before any `fluencyloop decision`" in codex_feature_text
assert "No reply is not a `wave`" in codex_feature_text
assert "without a teaching turn" in codex_feature_text
assert "### Codex design teaching gate - before implementation" in codex_feature_text
assert "conversation pause, not a build or merge gate" in codex_feature_text
assert "request sandbox elevation before its first" in codex_feature_text
assert "never make explanation sound like a burden" in codex_feature_text
assert "I am not comfortable" in codex_feature_text
assert "Understanding checks are self-report, never quizzes" in codex_feature_text
assert "Do you understand this explanation, or should I clarify anything?" in codex_feature_text
assert "topic-specific question" in codex_feature_text
assert "standalone comprehension question" not in codex_feature_text
assert "do not run another implementation" in codex_feature_text
for feature_skill_text in [feature_text, codex_feature_text]:
    assert "Understanding checks are self-report, never quizzes" in feature_skill_text
    assert "Do you understand this explanation, or should I clarify anything?" in feature_skill_text
    assert 'explaining it "in your own' in feature_skill_text
    assert "topic-specific question" in feature_skill_text
    assert "standalone comprehension question" not in feature_skill_text
    assert "Levels and signals are different vocabularies" in feature_skill_text
    assert "never valid signal types" in feature_skill_text
    assert "never run `fluencyloop calibration signal <dimension> learning` or `new`" in feature_skill_text
    assert "Only that later response can justify a signal" in feature_skill_text
    assert "### Distill once at feature wrap-up" in feature_skill_text
    assert "**only after the feature is complete**" in feature_skill_text
    assert "Never distill during a slice, after a decision, or as a turn-by-turn summary" in feature_skill_text
    assert "fluencyloop calibration show --json" in feature_skill_text
    assert "docs/fluencyloop/distillations/" in feature_skill_text
    assert "**Feature delta**" in feature_skill_text
    assert "**no overview rewrite**" in feature_skill_text
    assert "when this feature newly establishes a concept" in feature_skill_text
    assert "### Optional explanatory diagrams" in feature_skill_text
    assert "docs/fluencyloop/diagrams/product-overview.html" in feature_skill_text
    assert "sandboxed route" in feature_skill_text
    assert "Prose always carries the explanation." in feature_skill_text
    assert "**every feature gets one** is exactly the failure this option replaces." in feature_skill_text
    assert "Diagram: The reader selects the last record" in feature_skill_text
    assert "caption + prose" in feature_skill_text
    assert "### Product-overview diagram decision" in feature_skill_text
    assert "before drafting the overview" in feature_skill_text
    assert "Do not wait for the user to suggest a diagram" in feature_skill_text
    assert "diagram fast path**. Give it" in feature_skill_text
    assert "Do not ask the user to choose the style, type, or" in feature_skill_text
    assert "Keep `product.md` prose-only" in feature_skill_text
    assert "site --ensure --open-once --json" in feature_skill_text
    assert "**Do not distill decisions.**" in feature_skill_text
    assert "person-neutral" in feature_skill_text
for diagram_skill_text in [
    read_text(root / "claude-skills" / "diagram-design" / "SKILL.md"),
    read_text(dist / "skills" / "diagram-design" / "SKILL.md"),
]:
    assert "## FluencyLoop embedded diagram fast path" in diagram_skill_text
    assert "Do not load the full guide" in diagram_skill_text
    assert "Load only that one type reference" in diagram_skill_text
    assert "Use 4–7 nodes and 3–8 connectors" in diagram_skill_text
    assert "do not add a Mermaid duplicate" in diagram_skill_text
    assert "no Google Fonts `<link>`, remote `src`/`href`" in diagram_skill_text
    assert "Keep the existing light palette as the default" in diagram_skill_text
    assert "--diagram-canvas" in diagram_skill_text
    assert ':root[data-fluencyloop-theme="dark"]' in diagram_skill_text
    assert "do not use JavaScript or a system-preference media query" in diagram_skill_text
    assert "For an **architecture** diagram, default to\n   unlabelled arrows" in diagram_skill_text
    assert "label\n   every decision exit in a flowchart and every message in a sequence diagram" in diagram_skill_text
    assert "Never abbreviate a\n   label merely to make it fit" in diagram_skill_text
    assert "rounded orthogonal route" in diagram_skill_text
    assert "Never overlap connector paths or reuse an attach point" in diagram_skill_text
    assert "must never run behind a non-endpoint card" in diagram_skill_text
    assert "8px of visible\n   space from both the connector and every card" in diagram_skill_text
    assert "no text behind a card, connector overlap, or viewBox clipping" in diagram_skill_text
for full_guide_text in [
    read_text(root / "claude-skills" / "diagram-design" / "references" / "full-guide.md"),
    read_text(dist / "skills" / "diagram-design" / "references" / "full-guide.md"),
]:
    assert "## 0. First-time setup — style guide gate" in full_guide_text
    assert "Before generating your first diagram" in full_guide_text
claude_plan_text = read_text(root / "claude-skills" / "plan" / "SKILL.md")
codex_plan_text = read_text(dist / "skills" / "plan" / "SKILL.md")
assert "**Migrate imported history before planning.**" in claude_plan_text
assert "legacy_migration_pending" in claude_plan_text
assert "fluencyloop import --assess-unconfirmed" in claude_plan_text
assert "fluencyloop import --semantic-map" in claude_plan_text
assert "fluencyloop import --mark-semantic-complete" in claude_plan_text
assert "fluencyloop import --semantic-status --json" in claude_plan_text
assert "without\nopening every historical feature separately" in claude_plan_text
assert "**Migrate imported history before planning.**" in codex_plan_text
assert "legacy_migration_pending" in codex_plan_text
assert "fluencyloop import --mark-semantic-complete" in codex_plan_text
assert "fluencyloop import --semantic-status --json" in codex_plan_text
assert "Do not probe writer commands." in codex_plan_text
assert "every `--assess` follows its own read" in codex_plan_text
assert "### Codex architecture teaching gate - before decomposition" in codex_plan_text
assert "before writing the task breakdown, roadmap" in codex_plan_text
assert "Do not decompose the work" in codex_plan_text
assert "without explaining the architecture in the conversation" in codex_plan_text
assert "request sandbox elevation before its first" in codex_plan_text
assert "conversation pause, not a build or merge gate" in codex_plan_text
assert "comfortable\" as `new`" in codex_plan_text
assert "direct self-report" in codex_plan_text
assert "topic-specific question" in codex_plan_text
assert "standalone comprehension" not in codex_plan_text
for plan_skill_text in [claude_plan_text, codex_plan_text]:
    assert "Understanding checks are self-report, never quizzes" in plan_skill_text
    assert "Do you understand this" in plan_skill_text
    assert "explanation, or should I clarify anything?" in plan_skill_text
    assert "self-report-only" in plan_skill_text
    assert 'explaining it "in your own words,"' in plan_skill_text
    assert "topic-specific question" in plan_skill_text
    assert "standalone comprehension" not in plan_skill_text
    assert "## 1.5 Requirements analysis — surface material gaps" in plan_skill_text
    assert "Unstated requirements" in plan_skill_text
    assert "Contradictions with an existing explicit rule" in plan_skill_text
    assert "Forks whose different answers lead to materially different work" in plan_skill_text
    assert "Do **not** ask about anything with an obvious default" in plan_skill_text
    assert "Ask all material gaps **once, batched**" in plan_skill_text
    assert "Never resolve an unanswered gap silently" in plan_skill_text
    assert "Reuse **Question delivery — preserve the pause** above" in plan_skill_text
    assert "fluencyloop requirement --gap" in plan_skill_text
    assert "fluencyloop requirement --open" in plan_skill_text
    assert "Record the same outcome in the store exactly once per gap" in plan_skill_text
    assert "Never edit or delete the earlier `open_question`" in plan_skill_text
    assert "## 5. Elicit the constitution" in plan_skill_text
    for area in [
        "Guardrails", "Architecture principles", "Test methodology", "Data and state",
        "Dependencies", "Security and privacy",
    ]:
        assert area in plan_skill_text
    assert "The model raises each area; it never supplies the stance." in plan_skill_text
    assert "_No stance recorded yet._" in plan_skill_text
    assert "fluencyloop principle --number" in plan_skill_text
    assert "Source of truth:" in plan_skill_text
    assert "SpecKit" in plan_skill_text
    assert "Never author cold" not in plan_skill_text
plan_template = read_text(dist / "templates" / "plan.md")
assert "## Open questions" in plan_template
assert "rather than silently assuming an answer" in plan_template
constitution_template = read_text(dist / "templates" / "constitution.md")
for area in [
    "Guardrails", "Architecture principles", "Test methodology", "Data and state",
    "Dependencies", "Security and privacy",
]:
    assert area in constitution_template
assert constitution_template.count("_No stance recorded yet._") == 6
codex_backfill_text = read_text(dist / "skills" / "backfill" / "SKILL.md")
assert "## 0. Preconditions" in codex_backfill_text
assert "state required by `fluencyloop feature`" in codex_backfill_text
assert "request sandbox elevation before its first" in codex_backfill_text
claude_backfill_text = read_text(root / "claude-skills" / "backfill" / "SKILL.md")
for backfill_text in [codex_backfill_text, claude_backfill_text]:
    assert "fluencyloop decision" in backfill_text
    assert "fluencyloop knowledge" in backfill_text
    assert "fluencyloop concept" in backfill_text
    assert "--trust unverified" in backfill_text
    assert "Store parity, no Markdown." in backfill_text
    assert "Do not create or edit session journals" in backfill_text
    assert "confirm reconstructed decisions one at a time" not in backfill_text
    assert "must pass a human before it lands" not in backfill_text
    assert "No trust prompts." in backfill_text
    assert "## 2. Assemble records before writing" in backfill_text
    assert "Never invoke a bare writer to discover its syntax." in backfill_text
    assert "an empty command is neither a check" in backfill_text
    assert "Only after that plan exists, create the feature and session for a new backfill" in backfill_text
    assert "No empty writer calls." in backfill_text
    assert "### Legacy repository migration" in backfill_text
    assert "is **every imported feature**" in backfill_text
    assert "Do **not** call `fluencyloop feature` or `fluencyloop session`" in backfill_text
    assert "--feature \"<legacy-slug>\" --session 000-legacy-import" in backfill_text
    assert "never call a one-feature reconstruction a completed repository migration" in backfill_text
codex_review_text = read_text(dist / "skills" / "review" / "SKILL.md")
assert "feature-handoff: automatic" in codex_review_text
assert "without a second" in codex_review_text
assert 'gh pr create --base "<base_ref>"' in codex_review_text
for path in [
    dist / "skills" / "feature" / "SKILL.md",
    root / "claude-skills" / "feature" / "SKILL.md",
]:
    text = read_text(path)
    assert "Keep live feature design store-first." in text
    assert "Do **not** create or update `docs/fluencyloop/features/<slug>/`, `design.md`," in text
    assert "the only newly authored\nFluencyLoop Markdown" in text
    assert "append one matching `fluencyloop principle` record" in text
    assert "Before citing an existing `§N`" in text
    assert "Never create a placeholder principle" in text
    assert "Tags are mandatory for every new architectural record." in text
    assert "never append an untagged record" in text
    assert "it is not an architectural record yet" in text
for path in [
    dist / "skills" / "review" / "SKILL.md",
    root / "claude-skills" / "review" / "SKILL.md",
]:
    text = read_text(path)
    assert "from the feature declaration's `intent` field" in text
    assert "do not\n  create or link a generated `design.md`" in text
for path in [
    dist / "skills" / "plan" / "SKILL.md",
    root / "claude-skills" / "plan" / "SKILL.md",
]:
    text = read_text(path)
    assert "concepts and relationships" in text
    assert "Do not require class or sequence diagrams" in text
    assert "Diagrams are not banned" in text
    assert "artifact-design" not in text
    assert "Markdown: Open Preview" not in text
    assert "Mermaid" not in text
    assert "ASCII" not in text
plan_template = read_text(dist / "templates" / "plan.md")
assert "### Concepts" in plan_template
assert "### Relationships and flows" in plan_template
assert "```mermaid" not in plan_template
assert "classDiagram" not in plan_template
assert "sequenceDiagram" not in plan_template
readme = read_text(root / "README.md")
assert "**Enable auto-update**" in readme
assert "`/reload-plugins` to activate it in the current session" in readme
assert "claude-code-permissions.md" in readme
manifesto = read_text(root / "MANIFESTO.md")
assert "An understanding check is narrower still" in manifesto
assert "the check into a quiz" in manifesto
assert "topic-specific question" in manifesto
permissions_guide = read_text(root / "docs" / "claude-code-permissions.md")
assert "Bash(*.claude/plugins/cache/fluencyloop/fluencyloop/*/bin/fluencyloop *)" in permissions_guide
assert "Bash(git *)" in permissions_guide
for stage in ["plan", "feature", "review", "backfill"]:
    assert f"name: {stage}" in read_text(dist / "skills" / stage / "SKILL.md")
    assert f"name: {stage}" in read_text(root / "claude-skills" / stage / "SKILL.md")
    assert f"$fluencyloop:{stage}" in readme
    assert f"$fluencyloop-{stage}" not in readme
router_text = read_text(dist / "skills" / "fluencyloop" / "SKILL.md")
assert "## Literal CLI Fast Path (Codex)" in router_text
assert "Do not send an interim update" in router_text
assert "must not automatically start a feature or plan" in router_text
assert "request sandbox elevation for that exact command before its first" in router_text
assert "do not first attempt it in the" in router_text
assert "~/.local/bin/fluencyloop" in router_text
assert "Invoke `fluencyloop …` directly" in router_text
assert claude_entry["skills"] == [
    "./claude-skills/plan",
    "./claude-skills/feature",
    "./claude-skills/review",
    "./claude-skills/backfill",
    "./claude-skills/diagram-design",
]
for vendored in [
    root / "claude-skills" / "diagram-design",
    dist / "skills" / "diagram-design",
]:
    assert (vendored / "SKILL.md").is_file()
    assert "name: diagram-design" in read_text(vendored / "SKILL.md")
    assert "MIT License" in read_text(vendored / "LICENSE")
    assert "Third-party licenses" in read_text(vendored / "THIRD_PARTY_LICENSES.md")
    assert (vendored / "references" / "type-architecture.md").is_file()
    assert (vendored / "assets" / "template.html").is_file()
notice = read_text(root / "THIRD_PARTY_NOTICES.md")
assert "8827b277395988877ba997b714b43513f764b569" in notice
assert "cathrynlavery/diagram-design" in notice
assert not (root / "install.sh").exists()
assert not (root / "install.ps1").exists()
assert not (root / "skills").exists()
PY
    [ "$status" -eq 0 ]
}

@test "Claude plugin launcher runs the bundled CLI" {
  run bash "$REPO_ROOT/bin/fluencyloop" version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$DIST/VERSION")" ]
}

@test "Claude plugin launcher creates feature store records under docs" {
  setup_repo

  run bash "$REPO_ROOT/bin/fluencyloop" init --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs_dir"'* ]]
  [ -d "$TESTREPO/docs/fluencyloop" ]

  run bash "$REPO_ROOT/bin/fluencyloop" feature --json "write documentation"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"store"'* ]]
  [ -f "$TESTREPO/docs/fluencyloop/store/features/001-write-documentation.jsonl" ]
  [ ! -e "$TESTREPO/docs/fluencyloop/features/001-write-documentation/design.md" ]
  [ ! -e "$TESTREPO/.fluencyloop/features/001-write-documentation" ]
}

@test "Codex plugin bundles the CLI beside its skills" {
    run bash "$DIST/fluencyloop" version
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$DIST/VERSION")" ]
}

@test "Codex startup refresh hook is safe outside an installed plugin root" {
    setup_repo
    run env PLUGIN_ROOT="$DIST" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "startup hook ensures a site only in an initialized FluencyLoop repository" {
    local plugin_root="$BATS_TEST_TMPDIR/local-plugin"
    local calls="$BATS_TEST_TMPDIR/site-calls"
    mkdir -p "$plugin_root"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SITE_CALLS"\n' > "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"
    setup_initialized_repo

    run env PLUGIN_ROOT="$plugin_root" SITE_CALLS="$calls" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = 'site --ensure --open-once --json' ]
}

@test "startup hook ensures a site when CLAUDE_PLUGIN_ROOT is the flattened repo root" {
    # Claude's marketplace entry uses "source": ".", so CLAUDE_PLUGIN_ROOT is the repo root, not
    # plugins/fluencyloop/ — the launcher is nested one level deeper than Codex's PLUGIN_ROOT sees it.
    local plugin_root="$BATS_TEST_TMPDIR/flattened-root"
    local calls="$BATS_TEST_TMPDIR/site-calls"
    mkdir -p "$plugin_root/plugins/fluencyloop"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SITE_CALLS"\n' > "$plugin_root/plugins/fluencyloop/fluencyloop"
    chmod +x "$plugin_root/plugins/fluencyloop/fluencyloop"
    setup_initialized_repo

    run env -u PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="$plugin_root" SITE_CALLS="$calls" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = 'site --ensure --open-once --json' ]
}

@test "session hooks acquire and release a site lease from the host session id" {
    local plugin_root="$BATS_TEST_TMPDIR/local-plugin"
    local calls="$BATS_TEST_TMPDIR/site-calls"
    mkdir -p "$plugin_root"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SITE_CALLS"\n' > "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"
    setup_initialized_repo

    run bash -c 'printf "%s" "{\"session_id\":\"codex-session\"}" | env PLUGIN_ROOT="$1" SITE_CALLS="$2" bash "$3"' \
        _ "$plugin_root" "$calls" "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    run bash -c 'printf "%s" "{\"session_id\":\"codex-session\"}" | env PLUGIN_ROOT="$1" SITE_CALLS="$2" bash "$3" --session-end' \
        _ "$plugin_root" "$calls" "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]

    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = $'site --session-start codex-session --json\nsite --ensure --open-once --json\nsite --session-end codex-session --json' ]
}

@test "startup hook does not ensure a site in a non-FluencyLoop repository" {
    local plugin_root="$BATS_TEST_TMPDIR/local-plugin"
    local calls="$BATS_TEST_TMPDIR/site-calls"
    mkdir -p "$plugin_root"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SITE_CALLS"\n' > "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"
    setup_repo

    run env PLUGIN_ROOT="$plugin_root" SITE_CALLS="$calls" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$calls" ]
}

@test "startup command no-ops when no host exports a plugin root" {
    local hook_command

    run python3 - "$DIST/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
PY
    [ "$status" -eq 0 ]
    hook_command="$output"

    run env -i PATH="$PATH" bash -c "$hook_command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "startup command no-ops when its versioned plugin root was removed" {
    local hook_command

    run python3 - "$DIST/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
PY
    [ "$status" -eq 0 ]
    hook_command="$output"

    run env -i PATH="$PATH" PLUGIN_ROOT="$BATS_TEST_TMPDIR/missing/0.2.15" bash -c "$hook_command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "startup command recovers through a newly installed sibling version" {
    local hook_command
    local cache_root="$BATS_TEST_TMPDIR/plugins/cache/fluencyloop/fluencyloop"
    local removed_root="$cache_root/0.2.15"
    local current_root="$cache_root/0.2.17"
    mkdir -p "$current_root/hooks"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$PLUGIN_ROOT"\n' > "$current_root/hooks/refresh-marketplace.sh"

    run python3 - "$DIST/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
PY
    [ "$status" -eq 0 ]
    hook_command="$output"

    run env -i PATH="$PATH" PLUGIN_ROOT="$removed_root" bash -c "$hook_command"
    [ "$status" -eq 0 ]
    [ "$output" = "$current_root" ]
}

@test "startup recovery never executes a sibling marketplace plugin hook" {
    local hook_command
    local plugins_root="$BATS_TEST_TMPDIR/.tmp/marketplaces/fluencyloop/plugins"
    local missing_root="$plugins_root/fluencyloop"
    local unrelated_root="$plugins_root/unrelated"
    mkdir -p "$unrelated_root/hooks"
    printf '#!/usr/bin/env bash\nprintf "wrong plugin\\n"\n' > "$unrelated_root/hooks/refresh-marketplace.sh"

    run python3 - "$DIST/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
PY
    [ "$status" -eq 0 ]
    hook_command="$output"

    run env -i PATH="$PATH" PLUGIN_ROOT="$missing_root" bash -c "$hook_command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# A Claude root once interpolated into an unguarded path, so every Claude session started by
# failing the hook on a missing "/hooks/refresh-marketplace.sh".
@test "startup command resolves the hook from a Claude plugin root" {
    local hook_command

    setup_repo
    run python3 - "$DIST/hooks/hooks.json" <<'PY'
import json
import pathlib
import sys

hooks = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(hooks["hooks"]["SessionStart"][0]["hooks"][0]["command"])
PY
    [ "$status" -eq 0 ]
    hook_command="$output"

    run env -i PATH="$PATH" CLAUDE_PLUGIN_ROOT="$DIST" bash -c "$hook_command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Codex startup refresh hook updates only its supplying marketplace" {
    local plugin_root="$BATS_TEST_TMPDIR/plugins/cache/fluencyloop/fluencyloop/0.2.1"
    local calls="$BATS_TEST_TMPDIR/codex-calls"
    mkdir -p "$plugin_root"

    codex() {
        printf '%s\n' "$*" >> "$CODEX_CALLS"
    }
    export -f codex
    export CODEX_CALLS="$calls"

    run env PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = $'plugin marketplace upgrade fluencyloop --json\nplugin add fluencyloop@fluencyloop --json' ]
}

@test "Claude startup refresh hook updates only its supplying marketplace" {
    local plugin_root="$BATS_TEST_TMPDIR/claude/plugins/cache/fluencyloop/fluencyloop/0.2.1/plugins/fluencyloop"
    local calls="$BATS_TEST_TMPDIR/claude-calls"
    mkdir -p "$plugin_root"

    claude() {
        printf '%s\n' "$*" >> "$CLAUDE_CALLS"
    }
    export -f claude
    export CLAUDE_CALLS="$calls"

    run env -u PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = $'plugin marketplace update fluencyloop\nplugin update fluencyloop@fluencyloop' ]
}

# Both CLIs on one machine must not cross-refresh: the hosts keep separate package trees.
@test "Claude startup refresh hook never drives the Codex CLI" {
    local plugin_root="$BATS_TEST_TMPDIR/claude-only/plugins/cache/fluencyloop/fluencyloop/0.2.1/plugins/fluencyloop"
    local calls="$BATS_TEST_TMPDIR/codex-calls-from-claude"
    mkdir -p "$plugin_root"

    codex() {
        printf '%s\n' "$*" >> "$CODEX_CALLS"
    }
    claude() {
        :
    }
    export -f codex claude
    export CODEX_CALLS="$calls"

    run env -u PLUGIN_ROOT CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$calls" ]
}

# The PATH shim is how Codex resolves the CLI; the Claude skills address the bundled binary
# through CLAUDE_PLUGIN_ROOT instead. A Claude session must not repoint that command.
@test "Claude startup refresh hook leaves the Codex PATH shim alone" {
    local plugin_root="$BATS_TEST_TMPDIR/claude-shim/plugins/cache/fluencyloop/fluencyloop/0.2.1/plugins/fluencyloop"
    local home="$BATS_TEST_TMPDIR/home-claude-shim"
    mkdir -p "$plugin_root" "$home"
    printf '#!/usr/bin/env bash\n' > "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"

    claude() {
        :
    }
    export -f claude

    run env -u PLUGIN_ROOT HOME="$home" CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$home/.local/bin/fluencyloop" ]
}

@test "Codex startup refresh hook maintains its managed PATH shim" {
    local plugin_root="$BATS_TEST_TMPDIR/plugins/cache/fluencyloop/fluencyloop/0.2.9"
    local updated_plugin_root="$BATS_TEST_TMPDIR/plugins/cache/fluencyloop/fluencyloop/0.3.0"
    local home="$BATS_TEST_TMPDIR/home-managed"

    rm -rf "$home"
    mkdir -p "$plugin_root" "$updated_plugin_root" "$home"
    printf '#!/usr/bin/env bash\nprintf "0.2.9\\n"\n' > "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"
    printf '#!/usr/bin/env bash\nprintf "0.3.0\\n"\n' > "$updated_plugin_root/fluencyloop"
    chmod +x "$updated_plugin_root/fluencyloop"

    codex() { :; }
    export -f codex

    run env HOME="$home" PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -f "$home/.local/bin/fluencyloop" ]
    [ -x "$home/.local/bin/fluencyloop" ]

    run "$home/.local/bin/fluencyloop"
    [ "$status" -eq 0 ]
    [ "$output" = "0.2.9" ]

    # Installing an update can prune the active package after this hook wrote the shim. The shim
    # must find the replacement in the same managed cache without waiting for another session.
    rm -rf "$plugin_root"
    run "$home/.local/bin/fluencyloop"
    [ "$status" -eq 0 ]
    [ "$output" = "0.3.0" ]

    run env HOME="$home" PLUGIN_ROOT="$updated_plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]

    run "$home/.local/bin/fluencyloop"
    [ "$status" -eq 0 ]
    [ "$output" = "0.3.0" ]
}

@test "Codex startup refresh hook preserves a non-managed PATH command" {
    local plugin_root="$BATS_TEST_TMPDIR/plugins/cache/fluencyloop/fluencyloop/0.2.9"
    local home="$BATS_TEST_TMPDIR/home-unmanaged"
    local shim="$home/.local/bin/fluencyloop"

    rm -rf "$home"
    mkdir -p "$plugin_root" "$(dirname "$shim")"
    touch "$plugin_root/fluencyloop"
    chmod +x "$plugin_root/fluencyloop"
    printf '#!/usr/bin/env bash\necho custom\n' > "$shim"
    chmod +x "$shim"

    codex() { :; }
    export -f codex

    run env HOME="$home" PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$shim" ]

    run "$shim"
    [ "$status" -eq 0 ]
    [ "$output" = "custom" ]
}

@test "Codex startup refresh hook supports the marketplace snapshot root" {
    local plugin_root="$BATS_TEST_TMPDIR/.tmp/marketplaces/fluencyloop/plugins/fluencyloop"
    local calls="$BATS_TEST_TMPDIR/codex-marketplace-root-calls"
    mkdir -p "$plugin_root"

    codex() {
        printf '%s\n' "$*" >> "$CODEX_CALLS"
    }
    export -f codex
    export CODEX_CALLS="$calls"

    run env PLUGIN_ROOT="$plugin_root" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run cat "$calls"
    [ "$status" -eq 0 ]
    [ "$output" = $'plugin marketplace upgrade fluencyloop --json\nplugin add fluencyloop@fluencyloop --json' ]
}
