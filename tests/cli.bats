#!/usr/bin/env bats
# fluencyloop — the plugin-bundled CLI dispatcher: version, help, and safe handling of bad input.

load test_helper

@test "version prints the VERSION file" {
    run bash "$DIST/fluencyloop" version
    [ "$status" -eq 0 ]
    [ "$output" = "$(cat "$DIST/VERSION")" ]
}

@test "help lists the core commands" {
    run bash "$DIST/fluencyloop" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature"* ]]
    [[ "$output" == *"knowledge"* ]]
    [[ "$output" == *"concept"* ]]
    [[ "$output" == *"requirement"* ]]
    [[ "$output" == *"principle"* ]]
    [[ "$output" == *"import"* ]]
    [[ "$output" == *"check"* ]]
    [[ "$output" == *"site"* ]]
    [[ "$output" != *"self upgrade"* ]]
}

@test "an unknown command exits non-zero and prints usage" {
    run bash "$DIST/fluencyloop" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "check --json is wired through the dispatcher inside a repo" {
    setup_initialized_repo
    run bash "$DIST/fluencyloop" check --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys;json.load(sys.stdin)"
}

@test "site without Node exits cleanly with an actionable message" {
    # Node is outside /usr/bin and /bin on supported CI runners and local macOS; the rest of the
    # CLI dependencies remain available there, so this is a real missing-runtime exercise.
    run env PATH=/usr/bin:/bin bash "$DIST/fluencyloop" site
    [ "$status" -eq 1 ]
    [[ "$output" == *"Node.js 18 or newer"* ]]
    [[ "$output" == *"only for 'fluencyloop site'"* ]]
    [[ "$output" == *"The rest of FluencyLoop works without Node.js"* ]]
    [[ "$output" == *"https://nodejs.org/"* ]]
}
