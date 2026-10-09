#!/usr/bin/env python3
"""Check exact profile identity, complete proof, and all cover witnesses.

Consume SymbiYosys's structured property database, not console PASS substrings.
This checks reachability evidence integrity, not full assertion non-vacuity.
"""

import argparse
import configparser
import hashlib
import json
from pathlib import Path
import shlex
import sqlite3


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_task(directory, mode, parameters):
    require((directory / "PASS").is_file(), f"Missing {mode} PASS in {directory}")
    require((directory / "status").read_text().split()[0] == "PASS", f"Non-PASS {mode} status")
    database = directory / "status.sqlite"
    require(database.is_file(), f"Missing {database}")
    config = configparser.ConfigParser(interpolation=None, allow_no_value=True, delimiters=("=",))
    config.optionxform = str
    config.read(directory / "config.sby")
    require(f"mode {mode}" in config["options"], f"Wrong {mode} configuration")
    if mode == "prove":
        require(list(config["engines"]) == ["abc pdr"], "Proof is not the qualified complete PDR engine")
    else:
        require("depth 128" in config["options"], "Wrong cover bound")
    applied = {}
    for line in config["script"]:
        command = shlex.split(line)
        if command[0] == "chparam":
            require(len(command) == 5 and command[1] == "-set" and command[-1] == "async_fifo_formal",
                    "Unexpected parameter command")
            require(command[2] not in applied, "Duplicate parameter command")
            applied[command[2]] = int(command[3])
    require(applied == parameters, f"Wrong parameters in {mode} elaboration")
    sources = {}
    for filename in config["files"]:
        original = Path(filename)
        staged = directory / "src" / original.name
        require(original.read_bytes() == staged.read_bytes(), f"Stale formal source: {original}")
        sources[filename] = hashlib.sha256(staged.read_bytes()).hexdigest()
    with sqlite3.connect(f"{database.resolve().as_uri()}?mode=ro", uri=True) as connection:
        connection.row_factory = sqlite3.Row
        tasks = connection.execute("SELECT id, mode FROM task").fetchall()
        require(len(tasks) == 1 and tasks[0]["mode"] == mode, f"Wrong {mode} task identity")
        final = connection.execute("SELECT status FROM task_status ORDER BY id DESC LIMIT 1").fetchone()
        require(final is not None and final["status"] == "PASS", f"Non-PASS {mode} database")
        properties = connection.execute("SELECT id, src, hdlname, kind FROM task_property").fetchall()
        require(any(prop["kind"] == "ASSERT" for prop in properties), "No assertion inventory")
        covers = [prop for prop in properties if prop["kind"] == "COVER"]
        require(covers, "No cover inventory")
        if mode != "cover":
            return {"assertions": sum(prop["kind"] == "ASSERT" for prop in properties),
                    "source_sha256": sources}
        witnesses = []
        for prop in covers:
            status = connection.execute(
                "SELECT status, data, task_trace FROM task_property_status "
                "WHERE task_property = ? ORDER BY id DESC LIMIT 1", (prop["id"],)
            ).fetchone()
            require(status is not None and status["status"] == "PASS", f"Unreached cover: {prop['hdlname']}")
            detail = json.loads(status["data"])
            trace = connection.execute(
                "SELECT path FROM task_trace WHERE id = ?", (status["task_trace"],)
            ).fetchone()
            require(trace is not None and (directory / trace["path"]).is_file(), "Missing cover trace")
            witnesses.append({"source": prop["src"], "name": prop["hdlname"],
                              "step": detail["step"], "trace": trace["path"]})
        return {"covers": len(covers), "maximum_witness_step": max(item["step"] for item in witnesses),
                "witnesses": witnesses}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("config/formal-profiles.json"))
    parser.add_argument("--profile", required=True)
    parser.add_argument("--reports", type=Path, required=True, help="Profile report directory")
    parser.add_argument("--work", type=Path, required=True, help="Profile work directory")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    selected = [entry for entry in manifest["include"] if entry["name"] == args.profile]
    require(len(selected) == 1, "Unknown or duplicate profile")
    expected = selected[0]
    actual = json.loads((args.reports / "parameter-profile.json").read_text())
    require(actual["profile"] == args.profile and actual["parameters"] == expected["parameters"],
            "Stale or mismatched parameter profile")
    flow = args.reports / "symbiyosys_formal"
    require((flow / "status.txt").read_text().strip() == "PASS", "Combined flow did not pass")
    proof = check_task(args.work / "symbiyosys_formal", "prove", expected["parameters"])
    covers = check_task(args.work / "symbiyosys_coverage", "cover", expected["parameters"])
    sources = [witness["source"] for witness in covers["witnesses"]]
    if expected["parameters"].get("RUNTIME_RESET"):
        require(sum(source.startswith("async_fifo_formal.sv:") for source in sources) >= 18,
                "Missing runtime-reset targets")
    if expected["parameters"].get("VARIABLE_CAPTURE"):
        require(sum(source.startswith("async_fifo_capture_formal.sv:") for source in sources) == 8,
                "Missing independent delayed-capture witnesses")
    summary = {"profile": args.profile, "parameters": expected["parameters"], "proof": proof,
               "reachability": covers, "status": "PASS", "full_assertion_vacuity": "NOT_RUN",
               "physical_cdc_signoff": "NOT_RUN"}
    (flow / "formal-evidence.json").write_text(json.dumps(summary, indent=4) + "\n")
    print(f"{args.profile}: complete proof PASS; {covers['covers']} covers reached, "
          f"latest step {covers['maximum_witness_step']}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, sqlite3.Error) as error:
        raise SystemExit(f"Formal evidence check failed: {error}") from error
