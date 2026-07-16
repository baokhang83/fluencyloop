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
assert hooks["hooks"]["SessionStart"][0]["matcher"] == "startup"
assert handler["type"] == "command"
assert 'plugin_root="${PLUGIN_ROOT:-}"' in handler["command"]
assert "CLAUDE_PLUGIN_ROOT" not in handler["command"]
assert "refresh-marketplace.sh" in handler["command"]
assert "refresh-marketplace.ps1" in handler["commandWindows"]
assert (dist / "hooks" / "refresh-marketplace.sh").is_file()
assert (dist / "hooks" / "refresh-marketplace.ps1").is_file()

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
feature_text = read_text(root / "claude-skills" / "feature" / "SKILL.md")
assert "If `git_repo` or `fluency` is" in feature_text
assert "without asking the developer" in feature_text
assert "must be paths under `docs/fluencyloop/`" in feature_text
codex_feature_text = read_text(dist / "skills" / "feature" / "SKILL.md")
assert "### Codex teaching gate - visible before the journal" in codex_feature_text
assert "before any `fluencyloop decision`" in codex_feature_text
assert "No reply is not a `wave`" in codex_feature_text
assert "without a teaching turn" in codex_feature_text
assert "### Codex design teaching gate - before implementation" in codex_feature_text
assert "conversation pause, not a build or merge gate" in codex_feature_text
assert "request sandbox elevation before its first" in codex_feature_text
assert "never make explanation sound like a burden" in codex_feature_text
assert "I am not comfortable" in codex_feature_text
assert "standalone comprehension question and wait" in codex_feature_text
assert "do not run another implementation" in codex_feature_text
for feature_text in [feature_text, codex_feature_text]:
    assert "Levels and signals are different vocabularies" in feature_text
    assert "never valid signal types" in feature_text
    assert "never run `fluencyloop calibration signal <dimension> learning` or `new`" in feature_text
    assert "Only that later response can justify a signal" in feature_text
codex_plan_text = read_text(dist / "skills" / "plan" / "SKILL.md")
assert "### Codex architecture teaching gate - before decomposition" in codex_plan_text
assert "before writing the task breakdown, roadmap" in codex_plan_text
assert "Do not decompose the work" in codex_plan_text
assert "without explaining the architecture in the conversation" in codex_plan_text
assert "request sandbox elevation before its first" in codex_plan_text
assert "conversation pause, not a build or merge gate" in codex_plan_text
assert "comfortable\" as `new`" in codex_plan_text
assert "standalone comprehension" in codex_plan_text
codex_backfill_text = read_text(dist / "skills" / "backfill" / "SKILL.md")
assert "## 0. Preconditions" in codex_backfill_text
assert "state required by `fluencyloop feature`" in codex_backfill_text
assert "request sandbox elevation before its first" in codex_backfill_text
codex_review_text = read_text(dist / "skills" / "review" / "SKILL.md")
assert "feature-handoff: automatic" in codex_review_text
assert "without a second" in codex_review_text
assert 'gh pr create --base "<base_ref>"' in codex_review_text
for text in [codex_feature_text, codex_plan_text, codex_backfill_text]:
    assert "attempt an ASCII rendering" not in text
    assert "Markdown: Open Preview" in text
for path in [
    dist / "skills" / "feature" / "SKILL.md",
    dist / "skills" / "plan" / "SKILL.md",
    dist / "skills" / "backfill" / "SKILL.md",
    root / "claude-skills" / "feature" / "SKILL.md",
    root / "claude-skills" / "plan" / "SKILL.md",
    root / "claude-skills" / "backfill" / "SKILL.md",
]:
    text = read_text(path)
    assert "ASCII" in text
    assert "Mermaid source" in text
readme = read_text(root / "README.md")
assert "**Enable auto-update**" in readme
assert "`/reload-plugins` to activate it in the current session" in readme
assert "claude-code-permissions.md" in readme
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
]
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

@test "Claude plugin launcher creates feature documents under docs" {
  setup_repo

  run bash "$REPO_ROOT/bin/fluencyloop" init --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"docs_dir"'* ]]
  [ -d "$TESTREPO/docs/fluencyloop" ]

  run bash "$REPO_ROOT/bin/fluencyloop" feature --json "write documentation"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"design"'* ]]
  [ -f "$TESTREPO/docs/fluencyloop/features/write-documentation/design.md" ]
  [ ! -e "$TESTREPO/.fluencyloop/features/write-documentation" ]
}

@test "Codex plugin bundles the CLI beside its skills" {
    run bash "$DIST/fluencyloop" version
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$DIST/VERSION")" ]
}

@test "Codex startup refresh hook is safe outside an installed plugin root" {
    run env PLUGIN_ROOT="$DIST" bash "$DIST/hooks/refresh-marketplace.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Codex startup command ignores a Claude root and no-ops without a Codex root" {
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

    run env -i PATH="$PATH" CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/not-a-codex-plugin" bash -c "$hook_command"
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
