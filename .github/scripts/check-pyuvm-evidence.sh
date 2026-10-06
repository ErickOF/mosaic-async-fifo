#!/usr/bin/env bash
set -euo pipefail

# Validate the portable PyUVM release-evidence contract after a successful run.
report_dir="${1:-reports/pyuvm_open_source}"

if [[ ! -s "${report_dir}/status.txt" ]]; then
    echo "Missing PyUVM evidence: status.txt" >&2
    exit 1
fi

status="$(<"${report_dir}/status.txt")"
if [[ "${status}" == "SKIP" ]]; then
    echo "PyUVM evidence check skipped by module flow policy"
    exit 0
fi
if [[ "${status}" != "PASS" ]]; then
    echo "PyUVM status is not PASS" >&2
    exit 1
fi

required_files=(
    compile.log
    simulation.log
    results.xml
    functional-coverage.json
    coverage.dat
    coverage.info
    versions.log
)

for required_file in "${required_files[@]}"; do
    if [[ ! -s "${report_dir}/${required_file}" ]]; then
        echo "Missing PyUVM evidence: ${required_file}" >&2
        exit 1
    fi
done

# Source-area checks prove that native coverage includes the shared HDL layers,
# rather than recording only Python-driven activity in the DUT.
if ! grep -Fq "/verif/assertions/" "${report_dir}/coverage.info"; then
    echo "PyUVM native coverage does not include shared assertions" >&2
    exit 1
fi
if ! grep -Fq "/verif/coverage/" "${report_dir}/coverage.info"; then
    echo "PyUVM native coverage does not include HDL coverage models" >&2
    exit 1
fi

python3 - "${report_dir}" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

report_dir = Path(sys.argv[1])
root = ET.parse(report_dir / "results.xml").getroot()
suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
tests = sum(int(suite.get("tests", "0")) for suite in suites)
failures = sum(int(suite.get("failures", "0")) for suite in suites)
errors = sum(int(suite.get("errors", "0")) for suite in suites)
if tests < 1 or failures or errors:
    raise SystemExit(
        f"PyUVM JUnit is not clean: tests={tests}, failures={failures}, errors={errors}"
    )

functional_coverage = json.loads(
    (report_dir / "functional-coverage.json").read_text(encoding="utf-8")
)
if not functional_coverage:
    raise SystemExit("PyUVM functional coverage is empty")
PY

echo "PyUVM evidence is complete"
