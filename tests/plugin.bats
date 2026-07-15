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
assert "${PLUGIN_ROOT}/hooks/refresh-marketplace.sh" in handler["command"]
assert "refresh-marketplace.ps1" in handler["commandWindows"]
assert (dist / "hooks" / "refresh-marketplace.sh").is_file()
assert (dist / "hooks" / "refresh-marketplace.ps1").is_file()

for alias, source in {
    "plan": "fluencyloop-plan",
    "feature": "fluencyloop-feature",
    "review": "fluencyloop-review",
    "backfill": "fluencyloop-backfill",
}.items():
    alias_text = read_text(root / "claude-skills" / alias / "SKILL.md")
    source_text = read_text(dist / "skills" / source / "SKILL.md")
    assert f"name: {alias}" in alias_text
    assert f"name: {source}" in source_text
    assert '"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" <arguments>' in alias_text
    assert "it is never a chat instruction" in alias_text
    assert "globally installed" in alias_text
    assert "## Bundled CLI (Codex)" in source_text
    assert '"$FLUENCYLOOP_SKILL_DIR/../../fluencyloop" <arguments>' in source_text
    assert 'pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:FLUENCYLOOP_SKILL_DIR/../../fluencyloop.ps1" <arguments>' in source_text
feature_text = read_text(root / "claude-skills" / "feature" / "SKILL.md")
assert "If `git_repo` or `fluency` is" in feature_text
assert "without asking the developer" in feature_text
assert "must be paths under `docs/fluencyloop/`" in feature_text
readme = read_text(root / "README.md")
assert "**Enable auto-update**" in readme
assert "`/reload-plugins` to activate it in the current session" in readme
router_text = read_text(dist / "skills" / "fluencyloop" / "SKILL.md")
assert '"$FLUENCYLOOP_SKILL_DIR/../../fluencyloop" <arguments>' in router_text
assert 'pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:FLUENCYLOOP_SKILL_DIR/../../fluencyloop.ps1" <arguments>' in router_text
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
