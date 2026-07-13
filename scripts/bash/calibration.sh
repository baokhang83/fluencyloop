#!/usr/bin/env bash
# calibration.sh — the per-developer knowledge profile. Global (FLUENCYLOOP_HOME, default
# ~/.fluencyloop/calibration.md), never committed. Structured so the loop derives teaching depth
# deterministically: under `## Profile`, one `dimension: level` line per domain, where level is
# one of fluent | familiar | learning | new. Text after the level (a note, a date) is ignored.
#
# Usage: calibration.sh [init | show [--json] | edit]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

CAL="$(calibration_file)"

# Write the documented, self-describing starter profile (never clobbers an existing file).
seed() {
    mkdir -p "$(dirname "$CAL")"
    cat > "$CAL" <<'EOF'
# FluencyLoop calibration

<!--
Your per-developer knowledge profile. Global, never committed. The loop reads it to set how deep
to teach. Structured for deterministic parsing: under `## Profile`, one `dimension: level` line
per domain; level is one of fluent | familiar | learning | new. Anything after the level (a
free-text note and a · date) is optional and ignored by the parser.
-->

## Levels

- **fluent**   — reasons about it unaided; teach terse, flag only what's checkable.
- **familiar** — knows the shape; confirm, don't re-derive.
- **learning** — actively building it; teach the why and check understanding.
- **new**      — first contact; teach from fundamentals.

## Profile

<!-- one `dimension: level` per line, e.g.
java: fluent
reactive: learning — Mono/Flux backpressure · 2026-01-01
k8s: new
-->
EOF
}

# Parse `## Profile` into a dimension->level JSON map. Deterministic and portable (no gawk-only
# features): skips HTML comment blocks (so the seed's `<!-- example -->` lines don't count),
# other headings, and any line that isn't `<dimension>: <level>`.
levels_json() {
    [ -f "$CAL" ] || { printf '{}\n'; return 0; }
    awk '
        {
            if (incomment) { if ($0 ~ /-->/) incomment=0; next }
            if ($0 ~ /<!--/) { if ($0 !~ /-->/) incomment=1; next }
            if ($0 ~ /^## Profile/) { p=1; next }
            if ($0 ~ /^## /) { p=0 }
            if (p && $0 ~ /^[A-Za-z0-9][A-Za-z0-9._+-]*:[[:space:]]*(fluent|familiar|learning|new)([[:space:]]|$)/) {
                dim=$0; sub(/:.*/, "", dim); gsub(/[[:space:]]/, "", dim)
                lvl=$0; sub(/^[^:]*:[[:space:]]*/, "", lvl); sub(/[[:space:]].*/, "", lvl)
                out = out (n++ ? "," : "") "\"" dim "\":\"" lvl "\""
            }
        }
        END { printf "{%s}\n", out }
    ' "$CAL"
}

SUB="${1:-show}"; shift || true
JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

case "$SUB" in
    init)
        if [ -f "$CAL" ]; then
            echo "Calibration profile already exists: $CAL"
        else
            seed
            echo "Created calibration profile: $CAL"
        fi
        ;;
    show)
        if $JSON_MODE; then
            levels_json
        elif [ -f "$CAL" ]; then
            cat "$CAL"
        else
            echo "No calibration profile yet — run 'fluencyloop calibration init'." >&2
            exit 1
        fi
        ;;
    edit)
        [ -f "$CAL" ] || seed
        exec "${EDITOR:-vi}" "$CAL"
        ;;
    *)
        echo "Usage: fluencyloop calibration [init | show [--json] | edit]" >&2
        exit 1
        ;;
esac
