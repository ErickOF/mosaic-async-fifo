#!/usr/bin/env bash
set -euo pipefail

# Validate one selected profile without duplicating the shared PyUVM runner.
# This checks artifact integrity and implemented scenarios, not PPA or overall
# quantitative code/assertion/functional coverage closure.
report_dir="${1:-reports/nominal/pyuvm_open_source}"

python3 - "${report_dir}" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

report = Path(sys.argv[1])
required_files = (
    "status.txt", "compile.log", "simulation.log", "results.xml",
    "functional-coverage.json", "coverage.dat", "coverage.info", "versions.log",
)
for name in required_files:
    path = report / name
    if not path.is_file() or not path.stat().st_size:
        raise SystemExit(f"Missing PyUVM evidence: {name}")
if (report / "status.txt").read_text().strip() != "PASS":
    raise SystemExit("Enabled FIFO PyUVM status must be PASS, not SKIP/FAIL")

root = ET.parse(report / "results.xml").getroot()
suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
tests = sum(int(suite.get("tests", "0")) for suite in suites)
failures = sum(int(suite.get("failures", "0")) for suite in suites)
errors = sum(int(suite.get("errors", "0")) for suite in suites)
skipped = sum(int(suite.get("skipped", "0")) for suite in suites)
cases = list(root.iter("testcase"))
if tests < 1 or failures or errors or skipped or not cases:
    raise SystemExit("PyUVM JUnit must contain executed tests and no failure/error/skip")
if any(
    case.find(tag) is not None for case in cases
    for tag in ("failure", "error", "skipped")
):
    raise SystemExit("PyUVM JUnit testcase contains a failure/error/skip")
if not any(case.get("name") == "AsyncFifoTest" for case in cases):
    raise SystemExit("FIFO-specific PyUVM test is missing from JUnit")

native = (report / "coverage.info").read_text()
for source in ("async_fifo_sva.sv", "async_fifo_coverage.sv", "async_fifo.sv"):
    if not any(
        line.startswith("SF:") and line.endswith("/" + source)
        for line in native.splitlines()
    ):
        raise SystemExit(f"Native PyUVM coverage is missing shared source: {source}")

functional = json.loads((report / "functional-coverage.json").read_text())
if functional.get("schema") != "mosaic-async-fifo-pyuvm-v1":
    raise SystemExit("Wrong FIFO PyUVM evidence schema")
profile = json.loads((report.parent / "parameter-profile.json").read_text())
parameters = functional["parameters"]
if functional["profile"] != profile["profile"]:
    raise SystemExit("PyUVM profile identity mismatch")
if "pyuvm_open_source" not in profile["flows"]:
    raise SystemExit("Selected profile does not require PyUVM")
depth = profile["parameters"].get("DEPTH", 8)
expected = {
    "DATA_WIDTH": 32, "DEPTH": depth, "SYNC_STAGES": 2,
    "ALMOST_FULL_LEVEL": depth - 1, "ALMOST_EMPTY_LEVEL": 1,
} | profile["parameters"]
if parameters != expected:
    raise SystemExit("PyUVM parameter identity mismatch")
required = {
    "accepted_write", "accepted_read", "full", "empty", "stalled_output",
    "almost_full", "almost_empty", "reset_cancel", "coordinated_reset",
    "skewed_release", "no_bubble_read", "stopped_startup", "stopped_write",
    "stopped_read", "write_reset_recovery", "read_reset_recovery",
    "ratio_fast_write", "ratio_fast_read", "ratio_equal", "ratio_coprime",
    "phase_walk", "coincident_edges",
    "stopped_startup_write", "stopped_startup_read",
    "skewed_assert_write_first", "skewed_assert_read_first",
    "equal_phase_drift", "equal_drift_write", "equal_drift_read",
    "equal_drift_slow_edges", "equal_drift_fast_edges",
    *(f"equal_drift_phase_{phase}" for phase in range(5)),
    *(
        f"reset_stop_{stopped}_{first}_first"
        for stopped in ("w", "r", "both") for first in ("w", "r")
    ),
}
if set(functional["required_scenarios"]) != required:
    raise SystemExit("PyUVM required scenario set is incomplete")
hits = functional["hits"]
for name in required | {"write_wrap", "read_wrap"}:
    count = hits.get(name)
    minimum = 10 if name.endswith("_wrap") else 1
    if type(count) is not int or count < minimum:
        raise SystemExit(f"Missing FIFO PyUVM scenario hit: {name}")
if any(hits[name] != 20 * depth for name in (
    "equal_drift_slow_edges", "equal_drift_fast_edges",
)):
    raise SystemExit("PyUVM phase drift must complete balanced slow/fast intervals")
totals = functional["totals"]
if any(type(value) is not int or value < 0 for value in totals.values()):
    raise SystemExit("Invalid PyUVM accounting totals")
if (totals["remaining"] != 0 or
    totals["accepted"] != totals["delivered"] + totals["cancelled"] or
    totals["accepted"] != hits["accepted_write"] or
    totals["delivered"] != hits["accepted_read"]):
    raise SystemExit("FIFO PyUVM accounting is inconsistent")
print(f"FIFO PyUVM evidence PASS: {functional['profile']} {totals}")
PY

# Preserve individual HDL cross bins, separately from Python scenario hits.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "${module_root}/.github/scripts/check-cross-coverage.py" "${report_dir}"
