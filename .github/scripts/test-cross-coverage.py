#!/usr/bin/env python3
"""Counterfactual tests for native cross artifact integrity, not release thresholds.

Run after a passing minimum simulation. Each test edits an isolated copy of
real simulator evidence so the positive regression artifacts stay untouched.
"""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER_PATH = Path(__file__).with_name("check-cross-coverage.py")
SPEC = importlib.util.spec_from_file_location("fifo_cross_checker", CHECKER_PATH)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)
SOURCE = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path("reports/minimum/verilator_sim")


class CrossEvidenceControls(unittest.TestCase):
    """Missing identities fail closed; unhit identities are never erased."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.native = (SOURCE / "coverage.dat").read_text(encoding="latin-1")
        cls.profile = (SOURCE.parent / "parameter-profile.json").read_text()
        cls.cross_lines = [line for line in cls.native.splitlines()
                           if "\x01t\x02covergroup" in line and "\x01cross\x021" in line]
        if not cls.cross_lines:
            raise ValueError("Control fixture has no native cross bins")

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="fifo-cross-control-")
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.report = root / "verilator_sim"
        self.report.mkdir()
        (root / "parameter-profile.json").write_text(self.profile)
        (self.report / "status.txt").write_text("PASS\n")
        self.write_native(self.native)

    def write_native(self, native: str) -> None:
        (self.report / "coverage.dat").write_text(native, encoding="latin-1")

    def test_positive_preserves_twenty_crosses(self) -> None:
        evidence = CHECKER.collect(self.report)
        self.assertEqual(len(evidence["crosses"]), 20)
        self.assertEqual(evidence["coverage_qualification"], "NOT_RUN")
        self.assertEqual(evidence["assertion_vacuity"], "NOT_RUN")
        self.assertEqual(evidence["waivers_applied"], [])

    def test_one_missing_bin_is_rejected(self) -> None:
        self.write_native(self.native.replace(self.cross_lines[0] + "\n", "", 1))
        with self.assertRaisesRegex(ValueError, "Incomplete cross"):
            CHECKER.collect(self.report)

    def test_basic_coverpoints_alone_are_rejected(self) -> None:
        self.write_native("\n".join(line for line in self.native.splitlines()
                                    if "\x01t\x02covergroup" not in line) + "\n")
        with self.assertRaisesRegex(ValueError, "Incomplete cross"):
            CHECKER.collect(self.report)

    def test_duplicate_bin_is_rejected(self) -> None:
        self.write_native(self.native + self.cross_lines[0] + "\n")
        with self.assertRaisesRegex(ValueError, "Duplicate cross bin"):
            CHECKER.collect(self.report)

    def test_wrong_depth_shape_is_rejected(self) -> None:
        profile = json.loads(self.profile)
        profile["parameters"]["DEPTH"] *= 2
        (self.report.parent / "parameter-profile.json").write_text(json.dumps(profile))
        with self.assertRaisesRegex(ValueError, "Incomplete cross"):
            CHECKER.collect(self.report)

    def test_skip_is_not_positive_evidence(self) -> None:
        (self.report / "status.txt").write_text("SKIP\n")
        with self.assertRaisesRegex(ValueError, "passing positive simulation"):
            CHECKER.collect(self.report)

    def test_unqualified_extra_cross_sample_is_rejected(self) -> None:
        line = next(line for line in self.cross_lines
                    if "\x01page\x02v_covergroup/write_wrap_cg" in line)
        prefix, hits = line.rsplit(" ", 1)
        self.write_native(self.native.replace(line, prefix + " " + str(int(hits) + 1), 1))
        with self.assertRaisesRegex(ValueError, "Sample conservation failed"):
            CHECKER.collect(self.report)

    def test_zero_hits_are_retained_without_qualification(self) -> None:
        lines = []
        for line in self.native.splitlines():
            if "\x01t\x02covergroup" in line or "\x01o\x02coverage_" in line:
                line = line.rsplit(" ", 1)[0] + " 0"
            lines.append(line)
        self.write_native("\n".join(lines) + "\n")
        evidence = CHECKER.collect(self.report)
        self.assertEqual(sum(cross["hit_bins"] for cross in evidence["crosses"]), 0)
        self.assertEqual(sum(cross["total_bins"] for cross in evidence["crosses"]),
                         len(self.cross_lines))
        self.assertEqual(evidence["artifact_status"], "VALID")
        self.assertEqual(evidence["coverage_qualification"], "NOT_RUN")


if __name__ == "__main__":
    unittest.main()
