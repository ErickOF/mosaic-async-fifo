#!/usr/bin/env bash
set -euo pipefail

# Exercise the module's actual manifest, not the template's example widths.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${module_root}"
make profile-manifest-check
first="$(make --silent profile-matrix)"
second="$(make --silent profile-matrix)"
test "${first}" = "${second}"
make all-profiles PROFILE_JOBS="${PROFILE_JOBS:-2}" PROFILE_TARGET=open-source
while IFS= read -r profile; do
    python3 .github/scripts/check-cross-coverage.py "reports/${profile}/verilator_sim"
    ./.github/scripts/check-pyuvm-evidence.sh "reports/${profile}/pyuvm_open_source"
done < <(make --silent profile-list)
python3 .github/scripts/test-cross-coverage.py reports/minimum/verilator_sim
echo "Asynchronous FIFO profile checks passed"
