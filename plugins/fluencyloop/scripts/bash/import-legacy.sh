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
    IN_DECISION=false
    DECISION_TITLE=""; DECISION_WHERE=""; DECISION_WHY=""; DECISION_ALT=""
    DECISION_DESIGN=""; DECISION_CONST=""; DECISION_TRUST=""; DECISION_BAD=false
}

import_session() {
    local file="$1" feature_dir
    feature_dir="$(dirname "$(dirname "$file")")"
    FEATURE="$(basename "$feature_dir")"
    SESSION="$(basename "$file" .md)"
    STORE="$(feature_store_path "$FEATURE")"
    SOURCE_BASE="$(repo_rel "$file")"
    DECISION_NUMBER=0; COMPONENT_NUMBER=0; CONDITION_NUMBER=0
    IN_DECISION=false; IN_COMMENT=false; SECTION=""
    DECISION_TITLE=""; DECISION_WHERE=""; DECISION_WHY=""; DECISION_ALT=""
    DECISION_DESIGN=""; DECISION_CONST=""; DECISION_TRUST=""; DECISION_BAD=false
    local line component_re
    component_re='^- \*\*(.+)\*\* — (.+) · status: (documented|follow-up)$'
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
                    '- **trust:** ✓ verified') DECISION_TRUST="verified" ;;
                    '- **trust:** ⚠ not independently verified') DECISION_TRUST="unverified" ;;
                    '- **trust:** '*) DECISION_BAD=true ;;
                    *)
                        local re
                        # shellcheck disable=SC2016 # The regex deliberately matches literal Markdown backticks.
                        re='^- \*\*where:\*\* `([^`]*)`$'
                        if [[ "$line" =~ $re ]]; then DECISION_WHERE="${BASH_REMATCH[1]}"; continue; fi
                        re='^- \*\*why:\*\* (.*)$'
                        if [[ "$line" =~ $re ]]; then DECISION_WHY="${BASH_REMATCH[1]}"; continue; fi
                        re='^- \*\*alternative:\*\* (.*)$'
                        if [[ "$line" =~ $re ]]; then DECISION_ALT="${BASH_REMATCH[1]}"; continue; fi
                        re='^- \*\*design:\*\* (.*)$'
                        if [[ "$line" =~ $re ]]; then DECISION_DESIGN="${BASH_REMATCH[1]}"; continue; fi
                        re='^- \*\*constitution:\*\* (.*)$'
                        if [[ "$line" =~ $re ]]; then DECISION_CONST="${BASH_REMATCH[1]}"; continue; fi
                        [[ "$line" == '- **'* ]] && DECISION_BAD=true ;;
                esac
                continue
            fi
        fi
        case "$line" in
            '### Components'*) SECTION=components; continue ;;
            '### Hard-won conditions'*) SECTION=conditions; continue ;;
            '## '*) SECTION=""; continue ;;
        esac
        if [[ "$line" =~ $component_re ]]; then
            if [ "$SECTION" = components ]; then
                COMPONENT_NUMBER=$((COMPONENT_NUMBER + 1))
                # The legacy template kept role and conditions in one prose field. Preserve that
                # exact text in both schema fields rather than guessing a split that was never encoded.
                append_imported "$STORE" component "$FEATURE" "$SESSION" "$SOURCE_BASE#component-$COMPONENT_NUMBER" \
                    name "${BASH_REMATCH[1]}" role "${BASH_REMATCH[2]}" conditions "${BASH_REMATCH[2]}" status "${BASH_REMATCH[3]}"
            elif [ "$SECTION" = conditions ]; then
                CONDITION_NUMBER=$((CONDITION_NUMBER + 1))
                append_imported "$STORE" condition "$FEATURE" "$SESSION" "$SOURCE_BASE#condition-$CONDITION_NUMBER" \
                    subject "${BASH_REMATCH[1]}" why "${BASH_REMATCH[2]}"
            fi
        elif [[ "$line" == '- **'* ]] && { [ "$SECTION" = components ] || [ "$SECTION" = conditions ]; }; then
            warn_skip "$SOURCE_BASE#knowledge"
        fi
    done < "$file"
    flush_decision
}

while IFS= read -r -d '' session_file; do
    import_session "$session_file"
done < <(find "$LEGACY_ROOT" -mindepth 3 -maxdepth 3 -type f -path '*/sessions/*.md' -print0)

$AUTO || echo "Imported $IMPORTED legacy record(s); skipped $SKIPPED."
