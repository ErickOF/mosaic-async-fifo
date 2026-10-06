#!/usr/bin/env bash
set -euo pipefail

# Validate the project examples and qualify the module parameter profiles with
# bounded concurrency while preserving the ordinary no-profile entry point.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
flow_root="${FLOW_ROOT:-${module_root}/mosaic-flow}"
module_manifest="${module_root}/docs/examples/multi-module/config/modules.json"
profile_manifest="${module_root}/config/examples/parameter-profiles.json"

python3 "${flow_root}/ci/module_manifest.py" validate \
    --manifest "${module_manifest}" \
    --module-root "${module_root}/docs/examples/multi-module"
module_matrix_a="$(python3 "${flow_root}/ci/module_manifest.py" matrix \
    --manifest "${module_manifest}" \
    --module-root "${module_root}/docs/examples/multi-module")"
module_matrix_b="$(python3 "${flow_root}/ci/module_manifest.py" matrix \
    --manifest "${module_manifest}" \
    --module-root "${module_root}/docs/examples/multi-module")"
test "${module_matrix_a}" = "${module_matrix_b}"

python3 "${flow_root}/ci/parameter_profiles.py" validate \
    --manifest "${profile_manifest}"
profile_matrix_a="$(python3 "${flow_root}/ci/parameter_profiles.py" matrix \
    --manifest "${profile_manifest}" --module mosaic_module)"
profile_matrix_b="$(python3 "${flow_root}/ci/parameter_profiles.py" matrix \
    --manifest "${profile_manifest}" --module mosaic_module)"
test "${profile_matrix_a}" = "${profile_matrix_b}"

mkdir -p "${module_root}/ci-artifacts"
printf '%s\n' "${module_matrix_a}" \
    >"${module_root}/ci-artifacts/module-matrix.json"
printf '%s\n' "${profile_matrix_a}" \
    >"${module_root}/ci-artifacts/parameter-profile-matrix.json"

make -C "${module_root}" \
    PARAMETER_PROFILE_MANIFEST="${profile_manifest}" \
    PROFILE_JOBS="${PROFILE_JOBS:-3}" \
    all-profiles

python3 - "${module_root}" <<'PY'
import json
import sys
from pathlib import Path

module_root = Path(sys.argv[1])
expected = {"width_min": 1, "nominal": 32, "width_wide": 64}
summary = json.loads(
    (module_root / "reports/parameter-profile-summary.json").read_text(
        encoding="utf-8"
    )
)
assert summary["aggregate_status"] == "PASS", summary
assert {entry["profile"] for entry in summary["profiles"]} == set(expected), summary

for profile, width in expected.items():
    evidence = json.loads(
        (module_root / "reports" / profile / "parameter-profile.json").read_text(
            encoding="utf-8"
        )
    )
    assert evidence["parameters"]["DATA_WIDTH"] == width, evidence
    netlist = (
        module_root
        / "work"
        / profile
        / "yosys_synthesis"
        / "mosaic_module_netlist.v"
    )
    assert netlist.stat().st_size > 0, netlist
PY

echo "Module manifest and concurrent parameter-profile checks passed"
