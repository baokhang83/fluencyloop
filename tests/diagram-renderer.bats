#!/usr/bin/env bats
# diagram-renderer.js — agents supply graph facts; the renderer owns geometry and fixed iframe height.

load test_helper

@test "renders a six-node hub without custom SVG or vertical overflow" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the diagram renderer"
    setup_initialized_repo
    run bash "$DIST/fluencyloop" diagram \
        --output docs/fluencyloop/diagrams/product-overview.html --layout hub --title "Selection architecture" --hub service \
        --node list --label "Dog list" --detail "Chooses a dog" \
        --node filters --label "Filter controls" --detail "Refines the directory" \
        --node service --label "Selection service" --detail "Owns current selection" \
        --node detail --label "Dog detail" --detail "Reads selected dog" \
        --node metrics --label "Usage metrics" --detail "Observes selection" \
        --node data --label "Dog data" --detail "Provides fixed profiles" \
        --edge list service --edge filters service --edge data service --edge service detail --edge service metrics
    [ "$status" -eq 0 ]
    diagram="$TESTREPO/docs/fluencyloop/diagrams/product-overview.html"
    [ -s "$diagram" ]
    grep -q 'height:528px' "$diagram"
    grep -q 'overflow:hidden' "$diagram"
    [ "$(grep -o '<path d="M' "$diagram" | wc -l | tr -d ' ')" -eq 6 ]
    ! grep -q '<iframe\|<script\|https://' "$diagram"
}

@test "renders a four-node merge with relationship labels and a full-height canvas" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the diagram renderer"
    setup_initialized_repo
    run bash "$DIST/fluencyloop" diagram \
        --output docs/fluencyloop/diagrams/product-overview.html --layout merge --title "Architecture drift check" --hub drift \
        --node reader --label "Store reader" --detail "Parses recorded history" \
        --node resolver --label "Record resolver" --detail "Builds current state" \
        --node scanner --label "Reality scanner" --detail "Reads repository facts" \
        --node drift --label "Drift engine" --detail "Compares both views" \
        --edge reader resolver --edge-label "records" \
        --edge resolver drift --edge-label "current state" \
        --edge scanner drift --edge-label "repository facts"
    [ "$status" -eq 0 ]
    diagram="$TESTREPO/docs/fluencyloop/diagrams/product-overview.html"
    grep -q 'height:528px' "$diagram"
    grep -q 'records' "$diagram"
    grep -q 'current state' "$diagram"
    grep -q 'repository facts' "$diagram"
    [ "$(grep -o '<path d="M' "$diagram" | wc -l | tr -d ' ')" -eq 4 ]
}

@test "gives a five-node merge readable lanes without full-width cards" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the diagram renderer"
    setup_initialized_repo
    run bash "$DIST/fluencyloop" diagram \
        --output docs/fluencyloop/diagrams/product-overview.html --layout merge --title "Architecture drift check" --hub tools \
        --node reader --label "Store reader" --detail "Parses stored records" \
        --node resolver --label "Record resolver" --detail "Builds current state" \
        --node scanner --label "Reality scanner" --detail "Reads repository facts" \
        --node drift --label "Drift engine" --detail "Compares both views" \
        --node tools --label "MCP tools" --detail "Expose the findings" \
        --edge reader resolver --edge-label "records" \
        --edge resolver drift --edge-label "current state" \
        --edge scanner drift --edge-label "repository facts" \
        --edge drift tools --edge-label "drift findings"
    [ "$status" -eq 0 ]
    diagram="$TESTREPO/docs/fluencyloop/diagrams/product-overview.html"
    grep -q 'width="168"' "$diagram"
    grep -q 'class="name compact"' "$diagram"
    grep -q 'drift findings' "$diagram"
}

@test "rejects an unlabeled merge instead of producing an unexplained convergence" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the diagram renderer"
    setup_initialized_repo
    run bash "$DIST/fluencyloop" diagram \
        --output docs/fluencyloop/diagrams/product-overview.html --layout merge --title "Missing labels" --hub sink \
        --node source --label "Source" --detail "Provides input" \
        --node sink --label "Sink" --detail "Combines input" \
        --edge source sink
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires --edge-label"* ]]
}

@test "rejects a layered fan-out instead of producing overlapping routes" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the diagram renderer"
    setup_initialized_repo
    run bash "$DIST/fluencyloop" diagram \
        --output docs/fluencyloop/diagrams/product-overview.html --layout layered --title "Invalid fan" \
        --node source --label "Source" --detail "Starts the flow" \
        --node left --label "Left output" --detail "Consumes the result" \
        --node right --label "Right output" --detail "Consumes the result" \
        --edge source left --edge source right
    [ "$status" -ne 0 ]
    [[ "$output" == *"choose hub for a fan-out"* ]]
}
