#!/usr/bin/env bash
# import-legacy.sh — import rigid pre-0.3 session markdown into append-only store records.
# Originals under docs/fluencyloop/features are read-only. Each imported record carries a stable
# imported_from marker; re-runs recognise that exact raw marker without parsing JSON.
#
# Usage: import-legacy.sh [--auto|--semantic-status [--json]|--semantic-map|--assess-unconfirmed|--assess <feature> --summary <text> [--record <name> ...]|--mark-semantic-complete|--help]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Prevent require_fluency's first-use hook from re-entering this importer when it is invoked
# directly rather than by that hook.
export FLUENCYLOOP_IMPORTING=1

AUTO=false; MARK_SEMANTIC_COMPLETE=false
ASSESS_FEATURE=""; ASSESS_SUMMARY=""
declare -a ASSESS_RECORDS=()
SEMANTIC_STATUS=false; SEMANTIC_MAP=false; ASSESS_UNCONFIRMED=false; JSON=false
HELP=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --auto) AUTO=true ;;
        --mark-semantic-complete) MARK_SEMANTIC_COMPLETE=true ;;
        --assess) shift; ASSESS_FEATURE="${1:-}" ;;
        --summary) shift; ASSESS_SUMMARY="${1:-}" ;;
        --record) shift; ASSESS_RECORDS+=("${1:-}") ;;
        --semantic-status) SEMANTIC_STATUS=true ;;
        --semantic-map) SEMANTIC_MAP=true ;;
        --assess-unconfirmed) ASSESS_UNCONFIRMED=true ;;
        --json) JSON=true ;;
        --help|-h) HELP=true ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if $HELP; then
    cat <<'EOF'
Usage: fluencyloop import [--auto]
       fluencyloop import --semantic-status [--json]
       fluencyloop import --semantic-map
       fluencyloop import --assess-unconfirmed
       fluencyloop import --assess <feature> --summary <text> [--record <name> ...]
       fluencyloop import --mark-semantic-complete

Import legacy Markdown records, print a compact record map, stamp all imported features as
unconfirmed, record one reviewed assessment, or mark a fully assessed migration complete.
EOF
    exit 0
fi
require_fluency

json_array_from_lines() {
    local item first=true
    printf '['
    while IFS= read -r item; do
        $first || printf ','
        first=false
        printf '"%s"' "$(json_escape "$item")"
    done
    printf ']'
}

if $SEMANTIC_STATUS; then
    $AUTO && { echo "Error: --auto cannot be combined with --semantic-status." >&2; exit 1; }
    $MARK_SEMANTIC_COMPLETE && { echo "Error: --semantic-status and --mark-semantic-complete cannot be combined." >&2; exit 1; }
    if [ -n "$ASSESS_FEATURE$ASSESS_SUMMARY" ] || $SEMANTIC_MAP || $ASSESS_UNCONFIRMED; then
        echo "Error: --semantic-status cannot be combined with another migration action." >&2
        exit 1
    fi
    if $JSON; then
        printf '{"imported_features":'; json_array_from_lines < <(legacy_imported_feature_slugs)
        printf ',"unassessed_features":'; json_array_from_lines < <(legacy_semantic_unassessed_features)
        printf ',"architectural_records":%s,"tagged_architectural_records":%s}\n' \
            "$(legacy_architectural_record_count)" "$(legacy_tagged_architectural_record_count)"
    else
        echo "Imported legacy features: $(legacy_imported_feature_count)"
        echo "Assessed: $(legacy_semantic_assessment_count)"
        echo "Architectural records: $(legacy_architectural_record_count)"
        echo "Tagged architectural records: $(legacy_tagged_architectural_record_count)"
        echo "Unassessed features:"
        legacy_semantic_unassessed_features
    fi
    exit 0
fi

json_record_field() {
    local record="$1" field="$2" re
    re="\"$field\":\"([^\"]*)\""
    if [[ "$record" =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

if $SEMANTIC_MAP; then
    $AUTO && { echo "Error: --auto cannot be combined with --semantic-map." >&2; exit 1; }
    $MARK_SEMANTIC_COMPLETE && { echo "Error: --semantic-map and --mark-semantic-complete cannot be combined." >&2; exit 1; }
    if [ -n "$ASSESS_FEATURE$ASSESS_SUMMARY" ] || $ASSESS_UNCONFIRMED || $SEMANTIC_STATUS; then
        echo "Error: --semantic-map cannot be combined with another migration action." >&2
        exit 1
    fi
    echo "# Imported legacy record map"
    while IFS= read -r store; do
        feature="$(basename "$store" .jsonl)"
        echo
        printf '## %s\n' "$feature"
        feature_record="$(grep '"type":"feature"' "$store" | tail -n 1 || true)"
        intent="$(json_record_field "$feature_record" intent)"
        [ -n "$intent" ] && printf '%s\n' "Intent: $intent"
        while IFS= read -r record; do
            type="$(json_record_field "$record" type)"
            case "$type" in
                decision)
                    printf '%s\n' "Decision: $(json_record_field "$record" title) — $(json_record_field "$record" where)"
                    ;;
                component) printf '%s\n' "Component: $(json_record_field "$record" name)" ;;
                condition) printf '%s\n' "Condition: $(json_record_field "$record" subject)" ;;
            esac
        done < "$store"
    done < <(find "$(store_dir)/features" -maxdepth 1 -type f -name '*.jsonl' -print 2>/dev/null | LC_ALL=C sort)
    concept_store="$(concepts_store_path)"
    if [ -f "$concept_store" ]; then
        echo
        echo "# Existing architectural records"
        while IFS= read -r record; do
            [ "$(json_record_field "$record" type)" = "concept" ] || continue
            name="$(json_record_field "$record" name)"
            tags="$(json_record_field "$record" tags)"
            if [ -n "$tags" ]; then
                printf '%s\n' "Record: $name — tags: $tags"
            else
                printf '%s\n' "Record: $name — tags: (missing)"
            fi
        done < "$concept_store"
    fi
    exit 0
fi

if $ASSESS_UNCONFIRMED; then
    $AUTO && { echo "Error: --auto cannot be combined with --assess-unconfirmed." >&2; exit 1; }
    $MARK_SEMANTIC_COMPLETE && { echo "Error: --assess-unconfirmed and --mark-semantic-complete cannot be combined." >&2; exit 1; }
    if [ -n "$ASSESS_FEATURE$ASSESS_SUMMARY" ] || $SEMANTIC_STATUS; then
        echo "Error: --assess-unconfirmed cannot be combined with another migration action." >&2
        exit 1
    fi
    assessed=0
    while IFS= read -r feature; do
        store="$(feature_store_path "$feature")"
        if grep -Eq '"type":"semantic_assessment".*"semantic_migration_revision":"'"$LEGACY_SEMANTIC_MIGRATION_REVISION"'"' "$store"; then
            continue
        fi
        store_append_record "$store" semantic_assessment "$feature" 000-legacy-import \
            summary "Imported pre-0.3 history is unconfirmed pending independent review." \
            trust unverified semantic_migration_revision "$LEGACY_SEMANTIC_MIGRATION_REVISION"
        assessed=$((assessed + 1))
    done < <(legacy_imported_feature_slugs)
    echo "Recorded $assessed unconfirmed legacy assessment(s)."
    exit 0
fi

if [ -n "$ASSESS_FEATURE$ASSESS_SUMMARY" ]; then
    $AUTO && { echo "Error: --auto cannot be combined with --assess." >&2; exit 1; }
    $MARK_SEMANTIC_COMPLETE && { echo "Error: --assess and --mark-semantic-complete cannot be combined." >&2; exit 1; }
    [ -n "$ASSESS_FEATURE" ] || { echo "Error: --assess requires an imported feature slug." >&2; exit 1; }
    [ -n "$ASSESS_SUMMARY" ] || { echo "Error: --summary is required with --assess." >&2; exit 1; }
    store="$(feature_store_path "$ASSESS_FEATURE")"
    grep -Eq '"type":"feature".*"imported_from":"' "$store" 2>/dev/null || {
        echo "Error: $ASSESS_FEATURE is not an imported legacy feature." >&2; exit 1;
    }
    if grep -Eq '"type":"semantic_assessment".*"semantic_migration_revision":"'"$LEGACY_SEMANTIC_MIGRATION_REVISION"'"' "$store"; then
        echo "Semantic migration assessment already recorded for $ASSESS_FEATURE."
        exit 0
    fi
    fields=(summary "$ASSESS_SUMMARY" semantic_migration_revision "$LEGACY_SEMANTIC_MIGRATION_REVISION")
    if [ "${#ASSESS_RECORDS[@]}" -gt 0 ]; then
        fields+=(architectural_records "$(IFS=$'\n'; printf '%s' "${ASSESS_RECORDS[*]}")")
    fi
    store_append_record "$store" semantic_assessment "$ASSESS_FEATURE" 000-legacy-import "${fields[@]}"
    echo "Recorded semantic migration assessment for $ASSESS_FEATURE."
    exit 0
fi

if $MARK_SEMANTIC_COMPLETE; then
    $AUTO && { echo "Error: --auto and --mark-semantic-complete cannot be combined." >&2; exit 1; }
    count="$(legacy_imported_feature_count)"
    [ "$count" -gt 0 ] || { echo "Error: no imported legacy features are available to mark." >&2; exit 1; }
    assessed="$(legacy_semantic_assessment_count)"
    missing="$(legacy_semantic_unassessed_features)"
    if [ -n "$missing" ]; then
        echo "Error: semantic migration is incomplete: assessed $assessed of $count imported feature(s). Missing: $(printf '%s' "$missing" | paste -sd ',')." >&2
        exit 1
    fi
    architectural_records="$(legacy_architectural_record_count)"
    [ "$architectural_records" -gt 0 ] || {
        echo "Error: semantic migration is incomplete: no evidence-backed architectural records were recorded." >&2
        exit 1
    }
    tagged_architectural_records="$(legacy_tagged_architectural_record_count)"
    [ "$tagged_architectural_records" -gt 0 ] || {
        echo "Error: semantic migration is incomplete: no architectural records have tags for site filtering." >&2
        exit 1
    }
    mkdir -p "$(store_dir)"
    printf '%s\n' "$LEGACY_SEMANTIC_MIGRATION_REVISION" > "$(legacy_semantic_migration_path)"
    echo "Marked semantic migration complete for $count imported feature(s), $assessed assessment(s), and $architectural_records architectural record(s)."
    exit 0
fi

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

# Feature declarations are append-only too, but an earlier importer wrote a literal placeholder
# under the same stable source marker. Match the current intent as well as that marker so revision
# upgrades can append one superseding declaration instead of being permanently skipped.
feature_intent_is_imported() {
    local store="$1" source="$2" intent="$3" source_marker intent_marker line
    [ -f "$store" ] || return 1
    source_marker="\"imported_from\":\"$(json_escape "$source")\""
    intent_marker="\"intent\":\"$(json_escape "$intent")\""
    while IFS= read -r line; do
        [[ "$line" == *"$source_marker"* && "$line" == *"$intent_marker"* ]] && return 0
    done < "$store"
    return 1
}

append_imported_feature() {
    local store="$1" feature="$2" source="$3" intent="$4"
    if feature_intent_is_imported "$store" "$source" "$intent"; then
        SKIPPED=$((SKIPPED + 1))
        return
    fi
    store_append_record "$store" feature "$feature" none \
        slug "$feature" \
        intent "$intent" \
        branch "legacy-import/$feature" \
        base_ref legacy \
        imported_from "$source"
    IMPORTED=$((IMPORTED + 1))
}

# Prefer the existing design heading: it is the original one-line feature intent, not a new
# interpretation. Older histories without a design still get a useful, honestly-derived fallback
# from their first session title rather than a fixed placeholder.
legacy_feature_intent() {
    local feature_dir="$1" design session_file title
    design="$feature_dir/design.md"
    if [ -f "$design" ]; then
        title="$(sed -n 's/^# Design:[[:space:]]*//p' "$design" | head -1)"
        [ -n "$title" ] && { printf '%s' "$title"; return; }
    fi
    for session_file in "$feature_dir"/sessions/*.md; do
        [ -f "$session_file" ] || continue
        title="$(sed -n 's/^#[[:space:]]*Session:[[:space:]]*//p' "$session_file" | head -1)"
        [ -n "$title" ] && { printf 'Record legacy history: %s.' "$title"; return; }
    done
    printf 'Recover legacy history for %s.' "$(basename "$feature_dir")"
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
    # Split at the first closing bold span. A greedy regular expression would mistake later
    # emphasis in the explanatory prose for the close, and requiring a space after the close
    # rejects valid prose such as "**Windows**, so ...".
    local line raw parsed_name parsed_body
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
            parsed_name=""
            parsed_body=""
            if [[ "$line" == '- **'* ]]; then
                raw="${line#- \*\*}"
                if [[ "$raw" == *'**'* ]]; then
                    # %% removes from the first closing ** through the end; # removes through
                    # that same first close. Preserve punctuation immediately following it.
                    parsed_name="${raw%%\*\**}"
                    parsed_body="${raw#*\*\*}"
                    parsed_body="${parsed_body# }"
                fi
            fi
            if [ -n "$parsed_name" ]; then
                # A new bullet opening mid-accumulation means the previous one never reached its
                # status marker; flush it now so it is reported rather than silently discarded.
                flush_knowledge
                IN_KNOWLEDGE=true; KN_SECTION="$SECTION"
                KN_NAME="$parsed_name"; KN_BODY="$parsed_body"
                KN_BODY="${KN_BODY#"— "}"
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

import_feature() {
    local feature_dir="$1" sessions_dir session_file feature_intent
    FEATURE="$(basename "$feature_dir")"
    STORE="$(feature_store_path "$FEATURE")"
    SOURCE_BASE="$(repo_rel "$feature_dir")"
    sessions_dir="$feature_dir/sessions"
    [ -d "$sessions_dir" ] || return 0
    if ! find "$sessions_dir" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print -quit | grep -q .; then
        return 0
    fi
    while IFS= read -r -d '' session_file; do
        import_session "$session_file"
    done < <(find "$sessions_dir" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print0)

    # Legacy Markdown proves that this feature existed, but it cannot truthfully reconstruct the
    # original branch or a native 0.3 session declaration. Add one explicitly synthetic import
    # session instead. The original decision/component/condition records keep their legacy session
    # slugs, so their contemporaneous context remains intact.
    FEATURE="$(basename "$feature_dir")"
    STORE="$(feature_store_path "$FEATURE")"
    SOURCE_BASE="$(repo_rel "$feature_dir")"
    feature_intent="$(legacy_feature_intent "$feature_dir")"
    append_imported_feature "$STORE" "$FEATURE" "$SOURCE_BASE#feature" "$feature_intent"
    append_imported "$STORE" session "$FEATURE" 000-legacy-import "$SOURCE_BASE#backfill-session" \
        slug 000-legacy-import \
        intent "Backfill pre-0.3 session history."
}

while IFS= read -r -d '' feature_dir; do
    import_feature "$feature_dir"
done < <(find "$LEGACY_ROOT" -mindepth 1 -maxdepth 1 -type d -print0)

# A parser correction can safely ask an already-migrated repository for one more scan. Mark this
# completed pass so ordinary commands do not repeatedly walk its legacy Markdown afterwards.
printf '%s\n' "$LEGACY_IMPORT_REVISION" > "$(legacy_import_revision_path)"

$AUTO || echo "Imported $IMPORTED legacy record(s); skipped $SKIPPED."
