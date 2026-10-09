#!/usr/bin/env python3
"""Exercise formal evidence rejection using disposable copies of a passed profile."""

import argparse
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile


def corrupt(case, reports, work):
    flow = reports / "symbiyosys_formal"
    proof = work / "symbiyosys_formal"
    covers = work / "symbiyosys_coverage"
    if case == "combined_skip":
        (flow / "status.txt").write_text("SKIP\n")
    elif case == "wrong_parameters":
        path = reports / "parameter-profile.json"
        data = json.loads(path.read_text())
        data["parameters"]["DEPTH"] *= 2
        path.write_text(json.dumps(data))
    elif case == "missing_proof":
        (proof / "PASS").unlink()
    elif case == "unreached_cover":
        with sqlite3.connect(covers / "status.sqlite") as connection:
            connection.execute(
                "UPDATE task_property_status SET status = 'UNKNOWN' WHERE id = "
                "(SELECT MAX(s.id) FROM task_property_status s JOIN task_property p "
                "ON p.id = s.task_property WHERE p.id = "
                "(SELECT MIN(id) FROM task_property WHERE kind = 'COVER'))"
            )
    elif case == "missing_trace":
        with sqlite3.connect(covers / "status.sqlite") as connection:
            path = connection.execute(
                "SELECT t.path FROM task_trace t JOIN task_property_status s ON t.id = s.task_trace "
                "JOIN task_property p ON p.id = s.task_property "
                "WHERE p.kind = 'COVER' AND s.status = 'PASS' AND s.id = "
                "(SELECT MAX(latest.id) FROM task_property_status latest "
                "WHERE latest.task_property = p.id) LIMIT 1"
            ).fetchone()[0]
        (covers / path).unlink()
    elif case == "stale_source":
        path = proof / "src" / "async_fifo_sva.sv"
        path.write_text(path.read_text() + "\n// Disposable stale-source control.\n")
    elif case == "bounded_engine":
        path = proof / "config.sby"
        path.write_text(path.read_text().replace("mode prove", "mode bmc").replace(
            "abc pdr", "smtbmc bitwuzla"
        ))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reports", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    args = parser.parse_args()
    cases = {
        "positive": None,
        "combined_skip": "Combined flow did not pass",
        "wrong_parameters": "mismatched parameter profile",
        "missing_proof": "Missing prove PASS",
        "unreached_cover": "Unreached cover",
        "missing_trace": "Missing cover trace",
        "stale_source": "Stale formal source",
        "bounded_engine": "Wrong prove configuration",
    }
    evidence = []
    for case, expected in cases.items():
        with tempfile.TemporaryDirectory(prefix="async-fifo-formal-control-") as temporary:
            root = Path(temporary)
            reports = root / "reports"
            work = root / "work"
            shutil.copytree(args.reports, reports)
            shutil.copytree(args.work, work)
            corrupt(case, reports, work)
            result = subprocess.run(
                [sys.executable, ".github/scripts/check-formal-evidence.py", "--profile", args.profile,
                 "--reports", str(reports), "--work", str(work)],
                capture_output=True, text=True, check=False
            )
            output = result.stdout + result.stderr
            if expected is None:
                passed = result.returncode == 0
            else:
                passed = result.returncode != 0 and expected in output
            if not passed:
                raise SystemExit(f"Formal control {case} failed: {output}")
            evidence.append({"case": case, "status": "PASS", "diagnostic": output.strip()})
            print(f"{case}: PASS")
    (args.reports / "symbiyosys_formal" / "evidence-controls.json").write_text(
        json.dumps({"profile": args.profile, "status": "PASS", "cases": evidence}, indent=4) + "\n"
    )


if __name__ == "__main__":
    main()
