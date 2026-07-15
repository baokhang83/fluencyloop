#!/usr/bin/env bats
# Claude Code plugin package: metadata stays aligned with the CLI release and the bundled
# launcher can find the distribution scripts after marketplace installation.

load test_helper

@test "Claude plugin manifest and marketplace describe the distributable package" {
    run python3 - "$DIST" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
version = (root / "VERSION").read_text().strip()
plugin = json.loads((root / ".claude-plugin" / "plugin.json").read_text())
marketplace = json.loads((root / ".claude-plugin" / "marketplace.json").read_text())

assert plugin["name"] == "fluencyloop"
assert plugin["version"] == version
assert plugin["license"] == "Apache-2.0"
assert marketplace["name"] == "fluencyloop"
assert len(marketplace["plugins"]) == 1
entry = marketplace["plugins"][0]
assert entry["name"] == "fluencyloop"
assert entry["source"] == "."
assert entry["version"] == version
for alias, source in {
    "plan": "fluencyloop-plan",
    "feature": "fluencyloop-feature",
    "review": "fluencyloop-review",
    "backfill": "fluencyloop-backfill",
}.items():
    alias_text = (root / "claude-skills" / alias / "SKILL.md").read_text()
    source_text = (root / "skills" / source / "SKILL.md").read_text()
    assert alias_text.replace(f"name: {alias}", f"name: {source}", 1) == source_text, alias
assert marketplace["plugins"][0]["skills"] == [
    "./claude-skills/plan",
    "./claude-skills/feature",
    "./claude-skills/review",
    "./claude-skills/backfill",
]
PY
    [ "$status" -eq 0 ]
}

@test "Claude plugin launcher runs the bundled CLI" {
    run bash "$DIST/bin/fluencyloop" version
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$DIST/VERSION")" ]
}
