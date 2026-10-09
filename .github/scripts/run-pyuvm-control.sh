#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0

# Bridge module-owned campaign cases to the unchanged mosaic-flow adapter.
# The campaign, not this script, classifies the expected assertion failure.
mode="${1:?Usage: run-pyuvm-control.sh <positive|fault> <report-root> <work-root>}"
report_root="${2:?Missing report root}"
work_root="${3:?Missing work root}"
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${mode}" in
    positive) test_module=test_async_fifo ;;
    fault) test_module=test_async_fifo_assertion_control ;;
    *) echo "Invalid PyUVM control mode: ${mode}" >&2; exit 2 ;;
esac

mkdir -p "${report_root}"
adapter_report_root="${report_root}"
if [[ "${mode}" == fault ]]; then
    # Keep raw expected-failure status out of the profile gate-status scan.
    # Compact artifacts below retain that status explicitly, never rewrite it.
    adapter_report_root="${work_root}/raw-reports"
fi
result=0
# Recompute flow policy for the fixed fixture rather than inheriting the outer profile.
make --no-print-directory -C "${module_root}" PROFILE=minimum DISABLED_FLOWS= open-pyuvm \
    PYUVM_TEST_MODULE="${test_module}" \
    REPORT_DIR="${adapter_report_root}" WORK_DIR="${work_root}" \
    > "${report_root}/adapter.log" 2>&1 || result=$?
evidence="${adapter_report_root}/minimum/pyuvm_open_source"
if [[ "${mode}" == fault ]]; then
    archive="${report_root}/raw-pyuvm"
    mkdir -p "${archive}"
    if [[ -s "${evidence}/status.txt" ]]; then
        cp "${evidence}/status.txt" "${archive}/raw-status.txt"
    fi
    for artifact in compile.log simulation.log run.log results.xml versions.log; do
        if [[ -f "${evidence}/${artifact}" ]]; then
            cp "${evidence}/${artifact}" "${archive}/${artifact}"
        fi
    done
fi
if [[ "${result}" -ne 0 ]]; then
    cat "${report_root}/adapter.log"
    if [[ -s "${evidence}/simulation.log" ]]; then
        cat "${evidence}/simulation.log"
    fi
    if [[ ! -s "${evidence}/status.txt" ]] || [[ "$(<"${evidence}/status.txt")" != FAIL ]]; then
        echo "INFRASTRUCTURE_FAILURE: PyUVM did not retain raw FAIL evidence" >&2
    fi
    exit "${result}"
fi

if [[ "${mode}" == positive ]]; then
    "${module_root}/.github/scripts/check-pyuvm-evidence.sh" "${evidence}"
    echo "PYUVM_CAMPAIGN_BASELINE_PASS"
else
    # Return success unchanged: the shared campaign must reject an escaped
    # fault, never turn it into an expected nonzero design-check result here.
    echo "PYUVM_CAMPAIGN_FAULT_ESCAPED"
fi
