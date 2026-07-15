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
version = (dist / "VERSION").read_text().strip()
claude_plugin = json.loads((root / ".claude-plugin" / "plugin.json").read_text())
claude_marketplace = json.loads((root / ".claude-plugin" / "marketplace.json").read_text())
codex_plugin = json.loads((dist / ".codex-plugin" / "plugin.json").read_text())
codex_marketplace = json.loads((root / ".agents" / "plugins" / "marketplace.json").read_text())

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

for alias, source in {
    "plan": "fluencyloop-plan",
    "feature": "fluencyloop-feature",
    "review": "fluencyloop-review",
    "backfill": "fluencyloop-backfill",
}.items():
    alias_text = (root / "claude-skills" / alias / "SKILL.md").read_text()
    source_text = (dist / "skills" / source / "SKILL.md").read_text()
    assert f"name: {alias}" in alias_text
    assert f"name: {source}" in source_text
    assert "## Bundled CLI (Codex)" in source_text
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

@test "Codex plugin bundles the CLI beside its skills" {
    run bash "$DIST/fluencyloop" version
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$DIST/VERSION")" ]
}
