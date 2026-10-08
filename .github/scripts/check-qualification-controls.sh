#!/usr/bin/env bash
set -euo pipefail

# Campaigns contain payload, RTL and PyUVM baselines and paired X/Z arrival
# controls. Full fault/vacuity and quantitative coverage closure remain open.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
make -C "${module_root}" PROFILE=minimum open-negative open-four-state

# Exercise the shared classifier against altered diagnostics without changing
# RTL or overwriting the passing campaign evidence.
python3 - "${module_root}" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location(
    "campaign", root / "mosaic-flow/ci/qualification_campaign.py"
)
campaign = importlib.util.module_from_spec(spec)
spec.loader.exec_module(campaign)
manifest = json.loads((root / "config/qualification-campaigns.json").read_text())
cases = [
    case for case in manifest["campaigns"]["negative"]["cases"]
    if case["kind"] == "invalid_parameter"
]
if len(cases) != 7:
    raise SystemExit("Expected seven independently guarded invalid-parameter cases")

for case in cases:
    phase = case["phases"][-1]
    log = (
        root / "reports/minimum/negative_qualification" / case["evidence"] / "run.log"
    ).read_text()
    controls = [
        ("actual fatal", 1, log, True, "expected_assertion_failure"),
        ("late fatal", 1, log.replace("Time: 0 ", "Time: 1 "), False,
            "unexpected_failure"),
        ("missing time", 1, log.splitlines()[0], False, "unexpected_failure"),
        ("wrong diagnostic", 1, log.replace("invalid parameters", "unrelated failure"),
            False, "unexpected_failure"),
        ("escaped rejection", 0, log, False, "escaped_fault"),
        ("missing simulator", 127, "vvp: command not found", False,
            "infrastructure_failure"),
    ]
    for name, code, output, expected, classification in controls:
        valid, actual, message = campaign.classify_phase(
            phase, code, output, campaign.DEFAULT_INFRASTRUCTURE_DIAGNOSTICS
        )
        if valid != expected or actual != classification:
            raise SystemExit(f"{case['id']} / {name}: {actual}: {message}")
    print(f"{case['id']}: time-zero diagnostic and five rejection controls PASS")
PY

echo "Asynchronous FIFO positive, negative, and monitor controls passed"
