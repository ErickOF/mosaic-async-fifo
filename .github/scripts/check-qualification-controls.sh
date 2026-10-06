#!/usr/bin/env bash
set -euo pipefail

# Prove that each portable qualification gate fails closed on a representative
# broken policy, escaped fault, unavailable tool, or disabled monitor.
module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
flow_root="${FLOW_ROOT:-${module_root}/mosaic-flow}"
control_root="${module_root}/work/qualification-controls"
mkdir -p "${control_root}"

# Resolve the same pinned tool path exported to normal flow adapters. This also
# makes the controls usable inside the packaged methodology container.
# shellcheck disable=SC2016
resolved_tool_path="$(make --no-print-directory --silent \
    --eval='mosaic-print-tool-path: ; @printf "%s\n" "$$PATH"' \
    mosaic-print-tool-path)"
export PATH="${resolved_tool_path}"

expect_failure() {
    local name="$1"
    shift
    if "$@" >"${control_root}/${name}.log" 2>&1; then
        echo "Expected ${name} control to fail" >&2
        exit 1
    fi
}

python3 - "${module_root}" "${control_root}" <<'PY'
import json
import sys
from pathlib import Path

module_root = Path(sys.argv[1])
control_root = Path(sys.argv[2])

coverage = json.loads(
    (module_root / "config/coverage-policy.json").read_text(encoding="utf-8")
)
coverage["coverpoints"][0]["minimum_hits"] = 1_000_000
(control_root / "deficient-coverage.json").write_text(
    json.dumps(coverage, indent=2) + "\n", encoding="utf-8"
)

negative = {
    "schema": "mosaic-qualification-campaigns-v1",
    "campaigns": {
        "negative": {
            "infrastructure_diagnostics": ["MOSAIC_MISSING_TOOL"],
            "cases": [
                {
                    "id": "working_control",
                    "evidence": "working_control",
                    "role": "positive_control",
                    "kind": "positive_control",
                    "phases": [
                        {
                            "name": "run",
                            "command": [
                                "{python}",
                                "-c",
                                "print(\"WORKING_CONTROL_PASS\")",
                            ],
                            "expected": "success",
                            "diagnostic": "WORKING_CONTROL_PASS",
                        }
                    ],
                },
                {
                    "id": "missing_tool_control",
                    "evidence": "missing_tool_control",
                    "role": "positive_control",
                    "kind": "infrastructure_control",
                    "phases": [
                        {
                            "name": "run",
                            "command": ["MOSAIC_MISSING_TOOL"],
                            "expected": "success",
                        }
                    ],
                },
                {
                    "id": "escaped_mutation",
                    "evidence": "escaped_mutation",
                    "role": "negative",
                    "kind": "simulation_mutation",
                    "positive_control": "working_control",
                    "phases": [
                        {
                            "name": "run",
                            "command": [
                                "{python}",
                                "-c",
                                "print(\"MUTATION_SHOULD_HAVE_FAILED\")",
                            ],
                            "expected": "failure",
                            "diagnostic": "MUTATION_SHOULD_HAVE_FAILED",
                            "failure_class": "mutation",
                        }
                    ],
                },
            ]
        }
    },
}
(control_root / "broken-negative-campaign.json").write_text(
    json.dumps(negative, indent=2) + "\n", encoding="utf-8"
)

four_state = json.loads(
    (module_root / "config/qualification-campaigns.json").read_text(encoding="utf-8")
)
four_state["campaigns"] = {"four_state": four_state["campaigns"]["four_state"]}
detection = four_state["campaigns"]["four_state"]["cases"][1]
detection["phases"][0]["command"].insert(
    4, "-DMOSAIC_MODULE_DISABLE_UNKNOWN_MONITOR"
)
(control_root / "disabled-monitor-campaign.json").write_text(
    json.dumps(four_state, indent=2) + "\n", encoding="utf-8"
)

static_intent = json.loads(
    (module_root / "config/static-intent.json").read_text(encoding="utf-8")
)
base_sdc = (module_root / "flows/synthesis/timing.sdc").read_text(
    encoding="utf-8"
)

static_sdc_cases = {
    "missing": base_sdc.replace(
        "set_output_delay 0.500 -clock clk_i [all_outputs]\n", ""
    ),
    "duplicate": base_sdc.replace(
        "set_clock_uncertainty 0.100 [get_clocks clk_i]\n",
        "set_clock_uncertainty 0.100 [get_clocks clk_i]\n" * 2,
    ),
    "conflicting": base_sdc.replace(
        "create_clock -name clk_i -period 10.000 [get_ports clk_i]\n",
        "create_clock -name clk_i -period 10.000 [get_ports clk_i]\n"
        "create_clock -name clk_i -period 8.0 [get_ports clk_i]\n",
    ),
    "broad": base_sdc + "set_false_path -from [all_inputs]\n",
    "unsupported": base_sdc + "set_operating_conditions typical\n",
}

for name, contents in static_sdc_cases.items():
    path = control_root / f"{name}.sdc"
    path.write_text(contents, encoding="utf-8")
    policy = json.loads(json.dumps(static_intent))
    policy["sdc"]["profiles"] = [policy["sdc"]["profiles"][0]]
    policy["sdc"].pop("consistency", None)
    policy["sdc"]["profiles"][0]["path"] = (
        f"work/qualification-controls/{name}.sdc"
    )
    policy.pop("upf", None)
    (control_root / f"{name}-static-intent.json").write_text(
        json.dumps(policy, indent=2) + "\n", encoding="utf-8"
    )

incomplete_policy = {
    "schema": "mosaic-static-intent-v1",
    "sdc": {
        "profiles": [
            {
                "name": "incomplete",
                "path": "work/qualification-controls/incomplete.sdc",
                "kind": "combinational",
            }
        ]
    },
}
(control_root / "incomplete.sdc").write_text(
    "set_max_delay 5.0 -from [get_ports data_i] -to [all_outputs]\n",
    encoding="utf-8",
)
(control_root / "incomplete-static-intent.json").write_text(
    json.dumps(incomplete_policy, indent=2) + "\n", encoding="utf-8"
)

forbidden_policy = json.loads(json.dumps(static_intent))
forbidden_policy.pop("sdc", None)
forbidden_policy["upf"]["path"] = (
    "work/qualification-controls/forbidden.upf"
)
forbidden_policy["upf"]["forbidden_strategies"] = ["isolation"]
base_upf = (module_root / "flows/vc_lp/power.upf").read_text(encoding="utf-8")
(control_root / "forbidden.upf").write_text(
    base_upf
    + "set_isolation ISO_UNEXPECTED -domain PD_MOSAIC_MODULE "
    "-applies_to outputs -clamp_value 0\n",
    encoding="utf-8",
)
(control_root / "forbidden-static-intent.json").write_text(
    json.dumps(forbidden_policy, indent=2) + "\n", encoding="utf-8"
)
PY

expect_failure deficient-coverage \
    python3 "${flow_root}/ci/coverage_qualification.py" qualify \
        --policy "${control_root}/deficient-coverage.json" \
        --module-root "${module_root}" \
        --native "${module_root}/reports/verilator_sim/coverage.dat" \
        --lcov "${module_root}/reports/verilator_sim/coverage.info" \
        --source verilator_sim \
        --formal-result PASS \
        --formal-reached 4 \
        --output "${control_root}/deficient-coverage-summary.json"
grep -Fq '"status": "FAIL"' \
    "${control_root}/deficient-coverage-summary.json"

expect_failure broken-negative-campaign \
    python3 "${flow_root}/ci/qualification_campaign.py" \
        --campaign negative \
        --manifest "${control_root}/broken-negative-campaign.json" \
        --module-root "${module_root}" \
        --flow-root "${flow_root}" \
        --report-dir "${control_root}/negative-reports" \
        --work-dir "${control_root}/negative-work"
grep -Fq '"classification": "escaped_fault"' \
    "${control_root}/negative-reports/summary.json"
grep -Fq '"classification": "infrastructure_failure"' \
    "${control_root}/negative-reports/summary.json"

expect_failure disabled-monitor \
    python3 "${flow_root}/ci/qualification_campaign.py" \
        --campaign four_state \
        --manifest "${control_root}/disabled-monitor-campaign.json" \
        --module-root "${module_root}" \
        --flow-root "${flow_root}" \
        --report-dir "${control_root}/four-state-reports" \
        --work-dir "${control_root}/four-state-work"
grep -Fq '"classification": "escaped_fault"' \
    "${control_root}/four-state-reports/summary.json"

test "$(<"${module_root}/reports/static_intent/status.txt")" = PASS

static_intent_failure() {
    local name="$1"
    local report="$2"
    local code="$3"
    expect_failure "${name}-static-intent" \
        python3 "${flow_root}/ci/static_intent.py" \
            --config "${control_root}/${name}-static-intent.json" \
            --module-root "${module_root}" \
            --output-dir "${control_root}/${name}-static-intent-reports"
    grep -Fq '"status": "FAIL"' \
        "${control_root}/${name}-static-intent-reports/summary.json"
    grep -Fq "\"code\": \"${code}\"" \
        "${control_root}/${name}-static-intent-reports/${report}-findings.json"
}

static_intent_failure missing sdc missing_command
static_intent_failure duplicate sdc duplicate_command
static_intent_failure conflicting sdc conflicting_command
static_intent_failure broad sdc broad_exception
static_intent_failure incomplete sdc incomplete_max_delay
static_intent_failure forbidden upf forbidden_strategy
static_intent_failure unsupported sdc invalid_sdc_intent

echo "Portable qualification failure controls passed"
