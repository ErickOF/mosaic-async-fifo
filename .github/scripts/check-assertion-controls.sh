#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0

# Compile once through mosaic-flow, using the complete normal regression as
# the positive baseline. Each opt-in observation fault must hit its named SVA.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
report_root="${REPORT_DIR:-${module_root}/reports}/assertion_controls"
work_root="${WORK_DIR:-${module_root}/work}/assertion_controls"
binary="${work_root}/minimum/verilator_sim/obj_dir/Vasync_fifo_assertion_control_tb"
evidence="${report_root}/minimum/verilator_sim"
mkdir -p "${evidence}"
printf 'FAIL\n' > "${evidence}/controls-status.txt"
make -C "${module_root}" PROFILE=minimum open-sim \
    TB_TOP=async_fifo_assertion_control_tb \
    TB_FILELIST="${module_root}/filelists/assertion_control_tb.f" \
    REPORT_DIR="${report_root}" WORK_DIR="${work_root}"

for fault in storage_hold output_idle_hold write_init_prerequisites write_async_reset; do
    log="${evidence}/${fault}.log"
    if "${binary}" "+ASSERTION_FAULT=${fault}" > "${log}" 2>&1; then
        echo "Expected ${fault} to fail, but it passed" >&2
        exit 1
    fi
    if ! grep -q "ASSERTION_FAULT_REACHED ${fault}" "${log}" || \
       ! grep -Eq "Assertion failed in .*\\.${fault}:" "${log}" || \
       grep -q 'ASSERTION_FAULT_ESCAPED' "${log}"; then
        echo "Missing attributable ${fault} assertion failure, see ${log}" >&2
        exit 1
    fi
    echo "Detected ${fault} in the shared HDL checker"
done
printf 'PASS\n' > "${evidence}/controls-status.txt"
