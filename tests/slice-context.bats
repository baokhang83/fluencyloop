#!/usr/bin/env bats
# slice-context.sh — the current slice's hunks + metadata (token-cheap review input).

load test_helper

setup() {
    setup_initialized_repo
    printf 'a\nb\n' > app.txt
    git add -A && git commit -q -m "seed app + fluencyloop init"
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
}

json() { bash "$BIN/slice-context.sh" --json; }

@test "slice-context --json returns valid JSON with hunks + metadata" {
    printf 'a\nb changed\nc\n' > app.txt
    run json
    [ "$status" -eq 0 ]
    # Pipe the command directly (not `echo "$output"`): a shell builtin piping a large payload to
    # native Windows Python under Git Bash can drop the data; a subprocess pipe is reliable.
    json | python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in ("feature","base_kind","base","files_changed","insertions","deletions","files","untracked","diff"):
    assert k in d, k
assert "b changed" in d["diff"], d["diff"]
'
}

@test "includes tracked edits + untracked files; excludes FluencyLoop's own paths" {
    printf 'a\nb changed\n' > app.txt
    printf 'x\n' > new.txt          # untracked
    json | python3 -c '
import json,sys
d=json.load(sys.stdin)
paths=[f["path"] for f in d["files"]]
assert "app.txt" in paths, paths
assert d["untracked"]==["new.txt"], d["untracked"]
assert not any(".fluencyloop" in p or "docs/fluencyloop" in p for p in paths+d["untracked"]), d
'
}

@test "base_kind is base-ref before any journaled session" {
    printf 'a\nb changed\n' > app.txt
    [ "$(json | python3 -c 'import json,sys;print(json.load(sys.stdin)["base_kind"])')" = "base-ref" ]
}

@test "after a journaled session, the slice scopes to changes since it" {
    printf 'a\nb\nc\n' > app.txt
    bash "$BIN/new-session.sh" --slug add-caching "slice one" >/dev/null
    git add -A && git commit -q -m "slice one + journal"
    printf 'a\nb\nc\nd\n' > app.txt          # second slice
    [ "$(json | python3 -c 'import json,sys;print(json.load(sys.stdin)["base_kind"])')" = "last-session" ]
    json | python3 -c 'import json,sys;d=json.load(sys.stdin);assert "+d" in d["diff"], d["diff"]'
}

@test "plain form prints a header and the diff" {
    printf 'a\nb changed\n' > app.txt
    run bash "$BIN/slice-context.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Slice context"* ]]
    [[ "$output" == *"b changed"* ]]
}

@test "an unborn repository returns its staged and untracked first files without using HEAD" {
    rm -rf "$TESTREPO/.git"
    printf 'package main\n' > main.go
    printf 'module example.com/hello\n' > go.mod

    run bash "$DIST/fluencyloop" init --json
    [ "$status" -eq 0 ]
    git add main.go

    run bash "$DIST/fluencyloop" slice-context --json
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["base_kind"] == "unborn", d
assert d["base"] == "unborn", d
assert d["files_changed"] >= 2, d
assert "package main" in d["diff"], d["diff"]
assert "module example.com/hello" in d["diff"], d["diff"]
assert "main.go" in {f["path"] for f in d["files"]}, d["files"]
assert "go.mod" in d["untracked"], d["untracked"]
'
}

# --- decision pre-filter -------------------------------------------------

likely() { json | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['likely_decision'], d['decision_signals'])"; }

@test "pre-filter: JSON carries likely_decision / decision_score / decision_signals" {
    printf 'a\nb changed\n' > app.txt
    json | python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in ("likely_decision","decision_score","decision_signals"): assert k in d, k
assert isinstance(d["likely_decision"], bool) and isinstance(d["decision_score"], int), d
'
}

@test "pre-filter: a comment-only tweak is NOT a likely decision" {
    printf 'a\nb\n// just a note\n' > app.txt
    [[ "$(likely)" == "False"* ]]
}

@test "pre-filter: a new import IS a likely decision (dep-or-import)" {
    printf 'import x from "x";\na\nb\n' > app.txt
    [[ "$(likely)" == "True"*"dep-or-import"* ]]
}

@test "pre-filter: a new exported function IS a likely decision (new-api)" {
    printf 'export function foo(){ return 1; }\n' > app.txt
    [[ "$(likely)" == "True"*"new-api"* ]]
}

@test "pre-filter: substantive branching logic IS a likely decision (control-flow)" {
    printf 'let t=0;\nfor(let i=0;i<9;i++){\n if(i>4){t+=i;}else{t-=i;}\n}\nlet a=t;\nlet b=a+1;\nlet c=b+1;\nlet d=c+1;\n' > app.txt
    [[ "$(likely)" == "True"*"control-flow"* ]]
}
