#!/usr/bin/env bash
# slice-context.sh — the changed hunks + metadata for the current slice, so the model identifies
# decisions from the diff instead of re-reading whole files (token-cheap). The slice is everything
# since the last journaled session (the last commit touching the feature's sessions dir), or the
# feature's base ref if none yet, through the working tree — including untracked files.
#
# Usage: slice-context.sh [--json]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_fluency
cd "$(repo_root)"   # normalize pathspecs to the repo root regardless of where we're invoked

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# The slice is the developer's CODE, not FluencyLoop's own bookkeeping — exclude the tool's paths.
EXCLUDE=(-- . ':!.fluencyloop' ':!docs/fluencyloop')

FEATURE="$(state_get feature)"; [ -z "$FEATURE" ] && FEATURE="$(current_feature_slug)"
BASE_REF="$(state_get base_ref)"; [ -z "$BASE_REF" ] && BASE_REF="main"

# Where the slice starts: the last journaled session, else the feature's base ref, else HEAD.
SINCE=""; BASE_KIND="base-ref"
if [ -n "$FEATURE" ]; then
    SDIR="$(feature_path "$FEATURE")/sessions"
    LAST_JOURNAL="$(git log -1 --format=%H -- "$SDIR" 2>/dev/null || true)"
    [ -n "$LAST_JOURNAL" ] && { SINCE="$LAST_JOURNAL"; BASE_KIND="last-session"; }
fi
[ -z "$SINCE" ] && SINCE="$BASE_REF"
if ! git rev-parse --verify --quiet "$SINCE" >/dev/null 2>&1; then
    SINCE="HEAD"; BASE_KIND="head"
fi

# Untracked files are part of the slice — render each as an added-file diff (no index changes).
untracked_diff() {
    git ls-files --others --exclude-standard -z "${EXCLUDE[@]}" | while IFS= read -r -d '' f; do
        git diff --no-index -- /dev/null "$f" 2>/dev/null || true
    done
}

DIFF="$( git diff "$SINCE" "${EXCLUDE[@]}"; untracked_diff )"

read -r INS DEL TRACKED_FILES <<EOF
$(git diff --numstat "$SINCE" "${EXCLUDE[@]}" | awk '{i+=($1=="-"?0:$1); d+=($2=="-"?0:$2); n++} END{print i+0, d+0, n+0}')
EOF
UNTRACKED_COUNT="$(git ls-files --others --exclude-standard "${EXCLUDE[@]}" | awk 'END{print NR+0}')"
FILES_CHANGED=$((TRACKED_FILES + UNTRACKED_COUNT))
SHORT="$(git rev-parse --short "$SINCE" 2>/dev/null || printf '%s' "$SINCE")"

# --- decision pre-filter: cheap heuristics over the slice's ADDED lines, so the model only spends
# a full teaching pass where a real decision probably lives. New imports/deps, new public API /
# exports, new control flow, and change size each contribute; likely_decision = score >= 2.
HEUR="$(printf '%s\n' "$DIFF" | awk '
    function base(p,   n,a){ n=split(p,a,"/"); return a[n] }
    /^\+\+\+ / { f=$2; sub(/^b\//,"",f); bn=base(f)
        manifest = (bn ~ /^(package\.json|pom\.xml|go\.mod|Cargo\.toml|Gemfile|composer\.json|pyproject\.toml|requirements[^ ]*\.txt|Pipfile|build\.gradle(\.kts)?)$/)
        next }
    /^(---|diff |index |@@|new file|deleted file|similarity|rename|Binary)/ { next }
    /^\+/ {
        t=substr($0,2); gsub(/^[[:space:]]+/,"",t)
        if (t=="") next
        iscomment = (t ~ /^(\/\/|#|\*|\/\*|--|<!--)/)
        if (!iscomment) code++
        if (t ~ /^(import|from|#include|using|use)[[:space:]]/ || t ~ /require[[:space:]]*\(/) imp++
        if (manifest && !iscomment) dep++
        if (t ~ /^(export|public)[[:space:]]/ \
            || t ~ /^(export[[:space:]]+)?(default[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]/ \
            || t ~ /^(public[[:space:]]+|export[[:space:]]+|abstract[[:space:]]+)*(class|interface|enum|trait|struct)[[:space:]]/ \
            || t ~ /^(pub[[:space:]]+)?fn[[:space:]]/ || t ~ /^func[[:space:]]/ || t ~ /^def[[:space:]]/ \
            || t ~ /^@[A-Za-z_.]*(route|mapping|[GgPpDd][a-z]+)[(:]?/) api++
        if (t ~ /(^|[^A-Za-z_])(if|else|for|while|switch|case|try|catch|except|match)([^A-Za-z_]|$)/) ctl++
    }
    END {
        score=0; sig=""
        if (imp>0 || dep>0)   { score+=2; sig=sig "dep-or-import " }
        if (api>0)            { score+=2; sig=sig "new-api " }
        if (ctl>0 && code>=8) { score+=2; sig=sig "control-flow " }
        if (code>=15)         { score+=1; sig=sig "size " }
        if (code>=40)         { score+=1 }
        if (code==0)          { score=0; sig="trivial" }
        sub(/[[:space:]]+$/,"",sig)
        printf "%d %s %s\n", score, (score>=2 ? "true" : "false"), sig
    }
')"
read -r DEC_SCORE DEC_LIKELY DEC_SIGNALS <<<"$HEUR" || true
: "${DEC_SCORE:=0}" "${DEC_LIKELY:=false}"
DEC_SIGNALS_JSON="$(printf '%s' "${DEC_SIGNALS:-}" | awk '{for(i=1;i<=NF;i++) printf "%s\"%s\"",(i>1?",":""),$i}')"

if $JSON_MODE; then
    files="$(git diff --name-status "$SINCE" "${EXCLUDE[@]}" | awk -F'\t' '
        NF>=2 { p=$NF; gsub(/\\/,"\\\\",p); gsub(/"/,"\\\"",p)
                printf "%s{\"status\":\"%s\",\"path\":\"%s\"}", (n++?",":""), $1, p }')"
    untracked="$(git ls-files --others --exclude-standard "${EXCLUDE[@]}" | awk '
        { p=$0; gsub(/\\/,"\\\\",p); gsub(/"/,"\\\"",p); printf "%s\"%s\"", (n++?",":""), p }')"
    # JSON-escape the diff text (backslash, quote, tab, CR; newlines join records).
    diff_esc="$(printf '%s' "$DIFF" | awk '
        { s=$0; gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/,"\\t",s); gsub(/\r/,"\\r",s)
          printf "%s%s", (NR>1?"\\n":""), s }')"
    printf '{"feature":"%s","base_kind":"%s","base":"%s","files_changed":%s,"insertions":%s,"deletions":%s,"likely_decision":%s,"decision_score":%s,"decision_signals":[%s],"files":[%s],"untracked":[%s],"diff":"%s"}\n' \
        "$(json_escape "$FEATURE")" "$BASE_KIND" "$(json_escape "$SHORT")" \
        "$FILES_CHANGED" "$INS" "$DEL" "$DEC_LIKELY" "$DEC_SCORE" "$DEC_SIGNALS_JSON" \
        "$files" "$untracked" "$diff_esc"
else
    echo "# Slice context — feature: ${FEATURE:-<none>} (since $BASE_KIND $SHORT)"
    echo "# $FILES_CHANGED file(s), +$INS -$DEL"
    echo "# likely_decision: $DEC_LIKELY (score $DEC_SCORE${DEC_SIGNALS:+: $DEC_SIGNALS})"
    echo
    printf '%s\n' "$DIFF"
fi
