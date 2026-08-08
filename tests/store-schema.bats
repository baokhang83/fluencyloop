#!/usr/bin/env bats
# STORE.md is the one schema reference. Every documented record example must remain valid JSON.

load test_helper

@test "STORE.md documents one valid JSON example for every record type" {
    run python3 - "$DIST/STORE.md" <<'PY'
import json
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
examples = [json.loads(block) for block in re.findall(r"```json\n(.*?)\n```", text, re.DOTALL)]
expected = {
    "feature", "session", "decision", "component", "condition",
    "concept", "relation", "principle", "requirement", "open_question",
}

assert len(examples) == len(expected), f"expected {len(expected)} examples, got {len(examples)}"
assert {example.get("type") for example in examples} == expected
for example in examples:
    missing = {"schema_version", "type", "ts", "feature", "session", "commit"} - example.keys()
    assert not missing, f"{example.get('type', '<unknown>')} is missing envelope fields: {sorted(missing)}"
PY
    [ "$status" -eq 0 ]
}
