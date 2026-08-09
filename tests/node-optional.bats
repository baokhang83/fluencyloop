#!/usr/bin/env bats
# Node is a site-only runtime. Core scripts may detect its availability for the doctor, but never
# execute it; the site command lives in the top-level dispatcher until F2 supplies the server.

load test_helper

@test "core scripts never invoke Node" {
    run python3 - "$DIST" <<'PY'
import pathlib
import re
import sys

dist = pathlib.Path(sys.argv[1])
for root in (dist / "scripts" / "bash", dist / "scripts" / "powershell"):
    for path in root.iterdir():
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8").lower()
        assert not re.search(r"(?<!command -v )\bnode\s+--", text), path
        assert "exec node" not in text, path
        assert not re.search(r"&\s+node\b", text), path
PY
    [ "$status" -eq 0 ]
}
