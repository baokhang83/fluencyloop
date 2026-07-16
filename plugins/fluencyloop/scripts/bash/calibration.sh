#!/usr/bin/env bash
# calibration.sh — the per-developer knowledge profile + its engagement ledger. Global
# (FLUENCYLOOP_HOME, default ~/.fluencyloop), never committed.
#
# Profile: under `## Profile`, one `dimension: level` line per domain, level in
# {fluent, familiar, learning, new}. The loop parses it to set teaching depth deterministically.
#
# Adaptation: the loop appends cheap one-line signals (`signal <dim> <wave|deeper|correct>`) to
# an append-only ledger; `compact` deterministically rolls repeated signals into level changes
# (promote on wave-throughs, demote on deeper-asks / corrections).
#
# Usage: calibration.sh [init | show [--json] | edit
#                        | signal <dimension> <wave|deeper|correct> | compact [--dry-run]]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

CAL="$(calibration_file)"
SIG="$(signals_file)"
ORDER=(new learning familiar fluent)   # low -> high; promote = +1, demote = -1
THRESHOLD=2                            # net signals of one sign needed to move a level

# Write the documented, self-describing starter profile (never clobbers an existing file).
seed() {
    mkdir -p "$(dirname "$CAL")"
    cat > "$CAL" <<'EOF'
# FluencyLoop calibration

<!--
Your per-developer knowledge profile. Global, never committed. The loop reads it to set how deep
to teach. Structured for deterministic parsing: under `## Profile`, one `dimension: level` line
per domain; level is one of fluent | familiar | learning | new. Anything after the level (a
free-text note and a · date) is optional and ignored by the parser. Levels adapt over time:
`fluencyloop calibration compact` rolls demonstrated-engagement signals into promotions/demotions.
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

# Emit `dimension level` pairs from `## Profile`. Portable awk (no gawk-only features): skips
# HTML-comment blocks (so the seed's `<!-- example -->` lines don't count), other headings, and
# any line that isn't `<dimension>: <level>`.
_profile_pairs() {
    [ -f "$CAL" ] || return 0
    awk '
        {
            if (incomment) { if ($0 ~ /-->/) incomment=0; next }
            if ($0 ~ /<!--/) { if ($0 !~ /-->/) incomment=1; next }
            if ($0 ~ /^## Profile/) { p=1; next }
            if ($0 ~ /^## /) { p=0 }
            if (p && $0 ~ /^[A-Za-z0-9][A-Za-z0-9._+-]*:[[:space:]]*(fluent|familiar|learning|new)([[:space:]]|$)/) {
                dim=$0; sub(/:.*/, "", dim); gsub(/[[:space:]]/, "", dim)
                lvl=$0; sub(/^[^:]*:[[:space:]]*/, "", lvl); sub(/[[:space:]].*/, "", lvl)
                print dim, lvl
            }
        }
    ' "$CAL"
}

levels_json() {
    _profile_pairs | awk 'BEGIN{printf "{"} {printf "%s\"%s\":\"%s\"", (n++?",":""), $1, $2} END{print "}"}'
}

current_level() { _profile_pairs | awk -v d="$1" '$1==d{print $2; exit}'; }

# Shift a level one step (up|down), clamped to the ends of ORDER.
shift_level() {
    local cur="$1" dir="$2" idx=0 i
    for i in 0 1 2 3; do [ "${ORDER[$i]}" = "$cur" ] && idx=$i; done
    if [ "$dir" = up ]; then idx=$((idx + 1)); [ "$idx" -gt 3 ] && idx=3
    else idx=$((idx - 1)); [ "$idx" -lt 0 ] && idx=0; fi
    printf '%s' "${ORDER[$idx]}"
}

# Set dimension's level in `## Profile`, preserving any trailing note; append the line if the
# dimension isn't there yet. Comment-aware, literal dimension match (no regex-metachar surprises).
apply_level() {
    local dim="$1" newlvl="$2" tmp; tmp="$(mktemp)"
    awk -v dim="$dim" -v newlvl="$newlvl" '
        BEGIN { done=0 }
        {
            line=$0
            if (incomment) { if (line ~ /-->/) incomment=0; print; next }
            if (line ~ /<!--/) { if (line !~ /-->/) incomment=1; print; next }
            if (line ~ /^## Profile/) { p=1; print; next }
            if (line ~ /^## /) { if (p && !done) { print dim ": " newlvl; done=1 } p=0; print; next }
            if (p && !done) {
                d=line; sub(/:.*/, "", d); gsub(/[[:space:]]/, "", d)
                if (d==dim && line ~ /:[[:space:]]*(fluent|familiar|learning|new)([[:space:]]|$)/) {
                    rest=line; sub(/^[^:]*:[[:space:]]*[A-Za-z]+/, "", rest)
                    print dim ": " newlvl rest; done=1; next
                }
            }
            print
        }
        END { if (!done) print dim ": " newlvl }
    ' "$CAL" > "$tmp" && mv "$tmp" "$CAL"
}

reset_signals() {
    mkdir -p "$(dirname "$SIG")"
    printf '# FluencyLoop calibration signals — append-only; rolled into levels by: fluencyloop calibration compact\n' > "$SIG"
}

SUB="${1:-show}"; shift || true

case "$SUB" in
    init)
        if [ -f "$CAL" ]; then echo "Calibration profile already exists: $CAL"
        else seed; echo "Created calibration profile: $CAL"; fi
        ;;
    show)
        if [ "${1:-}" = "--json" ]; then levels_json
        elif [ -f "$CAL" ]; then cat "$CAL"
        else echo "No calibration profile yet — run 'fluencyloop calibration init'." >&2; exit 1; fi
        ;;
    edit)
        [ -f "$CAL" ] || seed
        exec "${EDITOR:-vi}" "$CAL"
        ;;
    signal)
        # Accept one OR MANY <dimension> <type> pairs in a single call, so a slice's signals are
        # one command (one approval prompt), not N.
        if [ "$#" -lt 2 ] || [ $(( $# % 2 )) -ne 0 ]; then
            echo "Usage: fluencyloop calibration signal <dimension> <wave|deeper|correct> [<dim> <type> ...]" >&2; exit 1
        fi
        i=1
        for a in "$@"; do
            if [ $(( i % 2 )) -eq 0 ]; then
                case "$a" in
                    wave|deeper|correct) ;;
                    fluent|familiar|learning|new)
                        echo "signal type must be wave|deeper|correct; '$a' is a calibration level, not a signal" >&2; exit 1 ;;
                    *)
                        echo "signal type must be wave|deeper|correct (got '$a')" >&2; exit 1 ;;
                esac
            fi
            i=$((i + 1))
        done
        [ -f "$SIG" ] || reset_signals
        today_str="$(today)"
        while [ "$#" -ge 2 ]; do
            printf '%s %s %s\n' "$today_str" "$1" "$2" >> "$SIG"
            shift 2
        done
        ;;
    compact)
        dry=false; [ "${1:-}" = "--dry-run" ] && dry=true
        if [ ! -f "$SIG" ]; then echo "No signals to compact."; exit 0; fi
        # Net score per dimension: wave +1, deeper/correct -1.
        scores="$(awk '
            /^#/ { next } NF < 3 { next }
            { s=$3; v=0; if (s=="wave") v=1; else if (s=="deeper"||s=="correct") v=-1; else next; agg[$2]+=v }
            END { for (d in agg) print d, agg[d] }
        ' "$SIG")"
        changed=0
        while read -r dim score; do
            [ -z "$dim" ] && continue
            if [ "$score" -ge "$THRESHOLD" ]; then dir=up
            elif [ "$score" -le "-$THRESHOLD" ]; then dir=down
            else continue; fi
            cur="$(current_level "$dim")"; [ -z "$cur" ] && cur=new
            new="$(shift_level "$cur" "$dir")"
            [ "$new" = "$cur" ] && continue
            $dry || apply_level "$dim" "$new"
            printf '%s %s: %s -> %s\n' "$([ "$dir" = up ] && echo '▲' || echo '▼')" "$dim" "$cur" "$new"
            changed=$((changed + 1))
        done <<EOF
$scores
EOF
        [ "$changed" -eq 0 ] && echo "No level changes (signals below the ±$THRESHOLD threshold)."
        $dry || reset_signals
        ;;
    *)
        echo "Usage: fluencyloop calibration [init | show [--json] | edit | signal <dim> <wave|deeper|correct> | compact [--dry-run]]" >&2
        exit 1
        ;;
esac
