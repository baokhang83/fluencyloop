#!/usr/bin/env bats
# init.sh — scaffolding, idempotency, empty constitution stub.

load test_helper

setup() { setup_repo; }

@test "init scaffolds machine state and docs dirs" {
    run bash "$BIN/init.sh"
    [ "$status" -eq 0 ]
    [ -d "$TESTREPO/.fluencyloop/scripts" ]
    [ -d "$TESTREPO/.fluencyloop/templates" ]
    [ -d "$TESTREPO/docs/fluencyloop" ]
}

@test "init seeds an EMPTY constitution stub, not the authoring scaffold" {
    bash "$BIN/init.sh" >/dev/null
    run cat "$TESTREPO/docs/fluencyloop/constitution.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"None yet"* ]]
    # no pre-filled §1/§2/§3 authoring scaffold
    ! grep -qE '^### §[0-9]' "$TESTREPO/docs/fluencyloop/constitution.md"
}

@test "init is idempotent: a second run succeeds and doesn't clobber the constitution" {
    bash "$BIN/init.sh" >/dev/null
    echo "### §1 — real principle" >> "$TESTREPO/docs/fluencyloop/constitution.md"
    run bash "$BIN/init.sh"
    [ "$status" -eq 0 ]
    grep -q "real principle" "$TESTREPO/docs/fluencyloop/constitution.md"
}

@test "init adds the calibration .gitignore guard" {
    bash "$BIN/init.sh" >/dev/null
    grep -qxF '.fluencyloop/**/calibration.md' "$TESTREPO/.gitignore"
}

@test "init adds its line-ending pins exactly once" {
    bash "$BIN/init.sh" >/dev/null
    run bash "$BIN/init.sh"
    [ "$status" -eq 0 ]
    [ "$(grep -cxF '.fluencyloop/** text eol=lf' "$TESTREPO/.gitattributes")" -eq 1 ]
    [ "$(grep -cxF 'docs/fluencyloop/** text eol=lf' "$TESTREPO/.gitattributes")" -eq 1 ]
}

@test "init --vendor-skills defaults to Claude Code" {
    run bash "$BIN/init.sh" --vendor-skills
    [ "$status" -eq 0 ]
    [ -f "$TESTREPO/.claude/skills/fluencyloop/SKILL.md" ]
    [ ! -e "$TESTREPO/.codex/skills" ]
}

@test "init --vendor-skills can target Codex" {
    run bash "$BIN/init.sh" --vendor-skills --agent codex
    [ "$status" -eq 0 ]
    [ -f "$TESTREPO/.codex/skills/fluencyloop/SKILL.md" ]
    [ ! -e "$TESTREPO/.claude/skills" ]
}

@test "init sets push.autoSetupRemote for frictionless feature-branch pushes" {
    bash "$BIN/init.sh" >/dev/null
    [ "$(git -C "$TESTREPO" config --local push.autoSetupRemote)" = "true" ]
}

@test "init --json emits a valid contract" {
    run bash "$BIN/init.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field constitution_created)" = "true" ]
    [ -n "$(echo "$output" | json_field docs_dir)" ]
}
