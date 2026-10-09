#!/usr/bin/env python3
"""Preserve each native HDL cross bin without claiming coverage qualification.

The pinned shared collector handles user counters, not Verilator's covergroup
records. This module-owned integrity check retains those records separately.
Zero-hit bins remain open. No scenarios, databases or instances are merged.
"""

from __future__ import annotations

import hashlib
import itertools
import json
import sys
from pathlib import Path

MODULE_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(MODULE_ROOT / "mosaic-flow" / "ci"))
from coverage_qualification import NATIVE_RECORD  # noqa: E402


def power_of_two_capacity(count: int) -> int:
    """Return the value range of the narrow automatic-bin index vector."""
    return 1 << (count - 1).bit_length()


def expected_bins(parameters: dict[str, int]) -> dict[tuple[str, str], set[tuple[str, ...]]]:
    """Specify every elaborated cross, including unhit and invalid-range bins."""
    depth = parameters["DEPTH"]
    stages = parameters["SYNC_STAGES"]
    pointer_width = depth.bit_length()
    if depth > 32768 or stages > 65536:
        raise ValueError("Profile exceeds the native automatic-bin capacity")
    auto = lambda count: [f"auto_{value}" for value in range(count)]
    model: dict[tuple[str, str], set[tuple[str, ...]]] = {}

    def add(group: str, cross: str, *dimensions: list[str]) -> None:
        model[group, cross] = set(itertools.product(*dimensions))

    for port in ("write", "read"):
        add(f"{port}_address_cg", "address_pair", auto(depth), auto(depth))
        add(f"{port}_activity_cg", "activity_status", auto(2), auto(2), auto(2))
        add(f"{port}_stall_cg", "stall_level", auto(2), auto(2 * depth))
        add(f"{port}_wrap_cg", "wrap_remote_phase", auto(2), auto(2))
        add(f"{port}_threshold_cg", "threshold_transition", ["entry", "exit"], auto(2 * depth))
    for group in ("read_gray_cg", "write_gray_cg"):
        add(group, "stage_bit_direction", auto(power_of_two_capacity(stages)),
            auto(power_of_two_capacity(pointer_width)), auto(2))
    for group in ("read_up_cg", "write_up_cg"):
        add(group, "stage_direction", auto(power_of_two_capacity(stages)), auto(2))
    ratios = ["write_faster", "equal_periods", "read_faster", "write_inactive", "read_inactive"]
    for group in ("write_clock_cg", "read_clock_cg"):
        add(group, "clock_occupancy", ratios, ["empty", "partial", "full"])
        add(group, "depth_ratio", ["current_depth"], ratios)
    add("reset_cg", "reset_state_skew_stop", ["uninitialized", "empty", "partial", "full"],
        ["simultaneous", "write_first", "read_first"],
        ["both_running", "write_inactive", "read_inactive", "both_inactive"])
    add("init_cg", "init_first_transfer", ["write_first", "read_first", "simultaneous"],
        ["write_first", "read_first", "simultaneous"])
    return model


def collect(report: Path) -> dict:
    """Fail on missing/stale bin identities but retain every zero-hit bin."""
    if (report / "status.txt").read_text().strip() != "PASS":
        raise ValueError("Cross evidence requires a passing positive simulation")
    profile = json.loads((report.parent / "parameter-profile.json").read_text())
    raw = profile["parameters"]
    depth = raw.get("DEPTH", 8)
    parameters = {"DATA_WIDTH": 32, "DEPTH": depth, "SYNC_STAGES": 2,
                  "ALMOST_FULL_LEVEL": depth - 1, "ALMOST_EMPTY_LEVEL": 1} | raw
    expected = expected_bins(parameters)
    groups: dict[tuple[str, str], dict[tuple[str, ...], dict]] = {key: {} for key in expected}
    # Independent HDL event counters catch counting crosses on unqualified
    # cycles even when all their native identities are present.
    event_counters: dict[str, int] = {}
    component_counts: dict[tuple[str, str], int] = {}
    first_component = {"address_pair": "write_address", "activity_status": "activity",
                       "stall_level": "stall", "wrap_remote_phase": "wrap_phase",
                       "threshold_transition": "threshold_direction",
                       "stage_bit_direction": "sync_stage", "stage_direction": "sync_stage",
                       "clock_occupancy": "ratio", "depth_ratio": "sync_depth",
                       "reset_state_skew_stop": "occupancy_state",
                       "init_first_transfer": "initialization_order"}
    state_groups = {f"{port}_{event}_cg" for port in ("write", "read")
                    for event in ("address", "activity", "stall", "wrap", "threshold")}
    native = report / "coverage.dat"
    for line_number, line in enumerate(native.read_text(encoding="latin-1").splitlines(), 1):
        if not line.startswith("C "):
            continue
        match = NATIVE_RECORD.fullmatch(line)
        if not match:
            raise ValueError(f"Malformed native record at line {line_number}")
        tagged, hits = match.groups()
        fields = dict(part.split("\x02", 1) for part in tagged.split("\x01") if "\x02" in part)
        if fields.get("t") == "user" and fields.get("o", "").startswith("coverage_"):
            counter = fields["o"]
            if counter in event_counters:
                raise ValueError(f"Duplicate sample counter: {counter}")
            event_counters[counter] = int(hits)
        if fields.get("t") != "covergroup":
            continue
        group = fields.get("page", "").removeprefix("v_covergroup/")
        hierarchy = fields.get("h", "")
        if not hierarchy.startswith(group + "."):
            raise ValueError("Unexpected native covergroup hierarchy")
        cross = hierarchy[len(group) + 1:].split(".", 1)[0]
        key = group, cross
        if fields.get("cross") != "1":
            component_counts[key] = component_counts.get(key, 0) + int(hits)
            continue
        if key not in expected:
            raise ValueError(f"Undeclared cross: {key}")
        identity = tuple(fields.get("Cb", "").split(","))
        if identity in groups[key]:
            raise ValueError(f"Duplicate cross bin: {key} {identity}")
        groups[key][identity] = {"values": list(identity), "hits": int(hits),
                                 "native_bin": fields["bin"], "source": fields["f"]}
    result = []
    for key, identities in expected.items():
        actual = groups[key]
        if set(actual) != identities:
            missing = sorted(identities - set(actual))
            extra = sorted(set(actual) - identities)
            raise ValueError(f"Incomplete cross {key}: missing={missing[:5]} extra={extra[:5]}")
        bins = [actual[identity] for identity in sorted(identities)]
        samples = sum(item["hits"] for item in bins)
        component = component_counts.get((key[0], first_component[key[1]]))
        if component != samples:
            raise ValueError(f"Sample conservation failed: {key} cross={samples} "
                             f"component={component}")
        if key[0] in state_groups:
            counter = "coverage_" + key[0].removesuffix("_cg") + "_sample"
            if counter not in event_counters or event_counters[counter] != samples:
                raise ValueError(f"Sample conservation failed: {key} cross={samples} "
                                 f"qualifying_events={event_counters.get(counter)}")
        result.append({"group": key[0], "cross": key[1], "total_bins": len(bins),
                       "hit_bins": sum(item["hits"] > 0 for item in bins),
                       "sample_events": samples, "bins": bins})
    return {"schema": "mosaic-async-fifo-cross-coverage-v1", "artifact_status": "VALID",
            "profile": profile["profile"], "parameters": parameters,
            "native_sha256": hashlib.sha256(native.read_bytes()).hexdigest(),
            "coverage_qualification": "NOT_RUN", "assertion_vacuity": "NOT_RUN",
            "waivers_applied": [], "state_sample_counters": event_counters, "crosses": result}


def main() -> int:
    """Write inspectable evidence for CI without awarding a release PASS."""
    report = Path(sys.argv[1])
    output = report / "cross-coverage.json"
    try:
        evidence = collect(report)
    except (OSError, ValueError, KeyError) as error:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps({"artifact_status": "INVALID", "error": str(error)},
                                     indent=2) + "\n")
        print(f"Invalid FIFO cross evidence: {error}", file=sys.stderr)
        return 1
    output.write_text(json.dumps(evidence, indent=2) + "\n")
    total = sum(item["total_bins"] for item in evidence["crosses"])
    hit = sum(item["hit_bins"] for item in evidence["crosses"])
    print(f"FIFO HDL cross evidence VALID: {evidence['profile']} {hit}/{total} bins hit; closure OPEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
