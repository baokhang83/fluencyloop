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
    grep -q 'height:520px' "$diagram"
    grep -q 'overflow:hidden' "$diagram"
    [ "$(grep -o '<path d="M' "$diagram" | wc -l | tr -d ' ')" -eq 6 ]
    ! grep -q '<iframe\|<script\|https://' "$diagram"
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
