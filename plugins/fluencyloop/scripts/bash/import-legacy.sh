#!/usr/bin/env bash
# import-legacy.sh — import rigid pre-0.3 session markdown into append-only store records.
# Originals under docs/fluencyloop/features are read-only. Each imported record carries a stable
# imported_from marker; re-runs recognise that exact raw marker without parsing JSON.
#
# Usage: import-legacy.sh [--auto]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Prevent require_fluency's first-use hook from re-entering this importer when it is invoked
# directly rather than by that hook.
export FLUENCYLOOP_IMPORTING=1

AUTO=false
for arg in "$@"; do
    case "$arg" in
        --auto) AUTO=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
require_fluency

LEGACY_ROOT="$(docs_dir)/features"
STORE_ROOT="$(store_dir)"
if [ ! -d "$LEGACY_ROOT" ]; then
    $AUTO || echo "Nothing to import — no legacy sessions under $LEGACY_ROOT."
    exit 0
fi

# Creating this new directory is what prevents automatic import from retrying forever when every
# legacy block is malformed. It never changes the legacy tree.
mkdir -p "$STORE_ROOT"
IMPORTED=0
SKIPPED=0

is_imported() {
    local store="$1" source="$2" marker
    [ -f "$store" ] || return 1
    marker="\"imported_from\":\"$(json_escape "$source")\""
    grep -Fq "$marker" "$store"
}

append_imported() {
    local store="$1" type="$2" feature="$3" session="$4" source="$5"
    shift 5
    if is_imported "$store" "$source"; then
        SKIPPED=$((SKIPPED + 1))
        return
    fi
    store_append_record "$store" "$type" "$feature" "$session" "$@" imported_from "$source"
    IMPORTED=$((IMPORTED + 1))
}

warn_skip() {
    echo "Warning: skipped malformed legacy record in $1" >&2
    SKIPPED=$((SKIPPED + 1))
}

# Markdown soft-wraps a paragraph across physical lines; a line break inside one renders as a
# single space. trim() and the continuation joins below reproduce that when reflowing a field
# the legacy writer wrapped, instead of reading only its first physical line.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# `where:` is written as a single backtick-quoted path by add-decision.sh, but backfilled
# decisions sometimes name two paths as two separate spans on the same line. Strip a wrapping
# pair only when the whole value is exactly that shape; otherwise keep the line as written rather
# than mis-strip and lose structure.
strip_wrapping_backticks() {
    # shellcheck disable=SC2016 # The regex deliberately matches literal Markdown backticks.
    local s="$1" re='^`([^`]*)`$'
    if [[ "$s" =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; else printf '%s' "$s"; fi
}

flush_decision() {
    [ "$IN_DECISION" = true ] || return 0
    DECISION_NUMBER=$((DECISION_NUMBER + 1))
    local source="$SOURCE_BASE#decision-$DECISION_NUMBER"
    if [ -z "$DECISION_TITLE" ] || [ -z "$DECISION_WHERE" ] || [ -z "$DECISION_WHY" ] || [ -z "$DECISION_TRUST" ] || [ "$DECISION_BAD" = true ]; then
        warn_skip "$SOURCE_BASE#decision-$DECISION_NUMBER"
    else
        append_imported "$STORE" decision "$FEATURE" "$SESSION" "$source" \
            title "$DECISION_TITLE" where "$DECISION_WHERE" why "$DECISION_WHY" \
            alternative "$DECISION_ALT" design "$DECISION_DESIGN" constitution "$DECISION_CONST" \
            trust "$DECISION_TRUST"
    fi
    IN_DECISION=false; LAST_FIELD=""
    DECISION_TITLE=""; DECISION_WHERE=""; DECISION_WHY=""; DECISION_ALT=""
    DECISION_DESIGN=""; DECISION_CONST=""; DECISION_TRUST=""; DECISION_BAD=false
}

# Appends a wrapped continuation line to whichever decision field last matched. `trust` has
# nowhere to put prose (the store field is the binary verified/unverified the marker already set)
# so its continuation is consumed and discarded rather than accumulated.
append_continuation() {
    local text="$1"
    case "$LAST_FIELD" in
        where) DECISION_WHERE="$DECISION_WHERE $text" ;;
        why) DECISION_WHY="$DECISION_WHY $text" ;;
        alternative) DECISION_ALT="$DECISION_ALT $text" ;;
        design) DECISION_DESIGN="$DECISION_DESIGN $text" ;;
        constitution) DECISION_CONST="$DECISION_CONST $text" ;;
        trust) : ;;
    esac
}

# A components/hard-won-condition bullet ends wherever `· status: (documented|follow-up)` lands,
# which the legacy writer sometimes put on the opening line and sometimes several wrapped lines
# later. flush_knowledge is only ever called once that suffix is present (or the bullet is
# abandoned by a heading/new bullet/EOF, in which case it is reported as malformed).
flush_knowledge() {
    [ "$IN_KNOWLEDGE" = true ] || return 0
    local marker suffix_re='^(.*)· status: (documented|follow-up)$' status=""
    if [ "$KN_SECTION" = components ]; then
        COMPONENT_NUMBER=$((COMPONENT_NUMBER + 1))
        marker="$SOURCE_BASE#component-$COMPONENT_NUMBER"
    else
        CONDITION_NUMBER=$((CONDITION_NUMBER + 1))
        marker="$SOURCE_BASE#condition-$CONDITION_NUMBER"
    fi
    if [[ "$KN_BODY" =~ $suffix_re ]]; then
        KN_BODY="$(trim "${BASH_REMATCH[1]}")"
        status="${BASH_REMATCH[2]}"
    fi
    if [ -z "$KN_NAME" ] || [ -z "$KN_BODY" ] || [ -z "$status" ]; then
        warn_skip "$marker"
    elif [ "$KN_SECTION" = components ]; then
        # The legacy template kept role and conditions in one prose field. Preserve that exact
        # text in both schema fields rather than guessing a split that was never encoded.
        append_imported "$STORE" component "$FEATURE" "$SESSION" "$marker" \
            name "$KN_NAME" role "$KN_BODY" conditions "$KN_BODY" status "$status"
    else
        append_imported "$STORE" condition "$FEATURE" "$SESSION" "$marker" \
            subject "$KN_NAME" why "$KN_BODY"
    fi
    IN_KNOWLEDGE=false; KN_NAME=""; KN_BODY=""; KN_SECTION=""
}

maybe_flush_knowledge() {
    local re='· status: (documented|follow-up)$'
    # Written as if/fi rather than `[[ ]] && flush_knowledge`: that form's exit status is the
    # test's when it is false, and a function returning that non-zero status trips `set -e` at
    # every bare call site — unlike the same test written inline, which set -e exempts.
    if [[ "$KN_BODY" =~ $re ]]; then flush_knowledge; fi
    return 0
}

import_session() {
    local file="$1" feature_dir
    feature_dir="$(dirname "$(dirname "$file")")"
    FEATURE="$(basename "$feature_dir")"
    SESSION="$(basename "$file" .md)"
    STORE="$(feature_store_path "$FEATURE")"
    SOURCE_BASE="$(repo_rel "$file")"
    DECISION_NUMBER=0; COMPONENT_NUMBER=0; CONDITION_NUMBER=0
    IN_DECISION=false; IN_COMMENT=false; SECTION=""; LAST_FIELD=""
    DECISION_TITLE=""; DECISION_WHERE=""; DECISION_WHY=""; DECISION_ALT=""
    DECISION_DESIGN=""; DECISION_CONST=""; DECISION_TRUST=""; DECISION_BAD=false
    IN_KNOWLEDGE=false; KN_NAME=""; KN_BODY=""; KN_SECTION=""
    local line bullet_re='^- \*\*(.+)\*\* — (.*)$'
    while IFS= read -r line || [ -n "$line" ]; do
        if $IN_COMMENT; then
            [[ "$line" == *"-->"* ]] && IN_COMMENT=false
            continue
        fi
        if [[ "$line" == *"<!--"* ]]; then
            [[ "$line" != *"-->"* ]] && IN_COMMENT=true
            continue
        fi
        if [[ "$line" == "## Decision: "* ]]; then
            flush_decision
            flush_knowledge
            IN_DECISION=true
            DECISION_TITLE="${line#\#\# Decision: }"
            SECTION=""
            continue
        fi
        if $IN_DECISION; then
            if [[ "$line" == "## "* ]]; then
                flush_decision
            else
                case "$line" in
                    '- **trust:** ✓'*) DECISION_TRUST="verified"; LAST_FIELD="trust"; continue ;;
                    '- **trust:** ⚠'*) DECISION_TRUST="unverified"; LAST_FIELD="trust"; continue ;;
                    '- **trust:** '*) DECISION_BAD=true; LAST_FIELD=""; continue ;;
                esac
                local re
                # shellcheck disable=SC2016 # The regex deliberately matches literal Markdown backticks.
                re='^- \*\*where:\*\* (.*)$'
                if [[ "$line" =~ $re ]]; then
                    DECISION_WHERE="$(strip_wrapping_backticks "${BASH_REMATCH[1]}")"; LAST_FIELD="where"; continue
                fi
                re='^- \*\*why:\*\* (.*)$'
                if [[ "$line" =~ $re ]]; then DECISION_WHY="${BASH_REMATCH[1]}"; LAST_FIELD="why"; continue; fi
                re='^- \*\*alternative:\*\* (.*)$'
                if [[ "$line" =~ $re ]]; then DECISION_ALT="${BASH_REMATCH[1]}"; LAST_FIELD="alternative"; continue; fi
                re='^- \*\*design:\*\* (.*)$'
                if [[ "$line" =~ $re ]]; then DECISION_DESIGN="${BASH_REMATCH[1]}"; LAST_FIELD="design"; continue; fi
                re='^- \*\*constitution:\*\* (.*)$'
                if [[ "$line" =~ $re ]]; then DECISION_CONST="${BASH_REMATCH[1]}"; LAST_FIELD="constitution"; continue; fi
                if [[ "$line" == '- **'* ]]; then
                    # A well-formed field this schema doesn't define — e.g. a hand-added
                    # `- **note:**` on a backfilled decision. STORE.md has no slot for it, but
                    # every other field on this decision is still real, so drop just this bullet
                    # rather than fail the whole record the way a genuinely malformed line does.
                    re='^- \*\*[A-Za-z][A-Za-z _-]*:\*\* '
                    if [[ "$line" =~ $re ]]; then LAST_FIELD=""; else DECISION_BAD=true; LAST_FIELD=""; fi
                elif [ -n "$LAST_FIELD" ] && [ -n "${line//[[:space:]]/}" ]; then
                    append_continuation "$(trim "$line")"
                fi
                continue
            fi
        fi
        case "$line" in
            '### Components'*) flush_knowledge; SECTION=components; continue ;;
            '### Hard-won conditions'*) flush_knowledge; SECTION=conditions; continue ;;
            '## '*) flush_knowledge; SECTION=""; continue ;;
        esac
        if [ "$SECTION" = components ] || [ "$SECTION" = conditions ]; then
            if [[ "$line" =~ $bullet_re ]]; then
                # A new bullet opening mid-accumulation means the previous one never reached its
                # status marker; flush it now so it is reported rather than silently discarded.
                flush_knowledge
                IN_KNOWLEDGE=true; KN_SECTION="$SECTION"
                KN_NAME="${BASH_REMATCH[1]}"; KN_BODY="${BASH_REMATCH[2]}"
                maybe_flush_knowledge
            elif $IN_KNOWLEDGE && [[ "$line" == '- **'* ]]; then
                # A bullet-looking line broke the accumulation before its status marker. flush_knowledge
                # already reports the abandoned bullet with its own numbered marker — do not warn twice.
                flush_knowledge
            elif $IN_KNOWLEDGE && [ -n "${line//[[:space:]]/}" ]; then
                KN_BODY="$KN_BODY $(trim "$line")"
                maybe_flush_knowledge
            elif [[ "$line" == '- **'* ]]; then
                warn_skip "$SOURCE_BASE#knowledge"
            fi
        fi
    done < "$file"
    flush_decision
    flush_knowledge
}

while IFS= read -r -d '' session_file; do
    import_session "$session_file"
done < <(find "$LEGACY_ROOT" -mindepth 3 -maxdepth 3 -type f -path '*/sessions/*.md' -print0)

$AUTO || echo "Imported $IMPORTED legacy record(s); skipped $SKIPPED."
