"""Independent FIFO reference model and deterministic dual-clock bus driver."""

from __future__ import annotations

import json
import os
import random
from collections import Counter, deque
from pathlib import Path
from typing import Callable

import cocotb
from cocotb.triggers import ReadWrite, Timer
from cocotb.utils import get_sim_time
from pyuvm import uvm_component, uvm_env


SEED = 0x53A912F1


class FifoScoreboard(uvm_component):
    """Observe public ports only and account for transfers within reset epochs."""

    def configure(self, parameters: dict[str, int]) -> None:
        """Start an empty model using the same released profile as the HDL top."""
        self.parameters = parameters
        self.depth = parameters["DEPTH"]
        self.queue: deque[int] = deque()
        self.hits: Counter[str] = Counter()
        self.accepted = 0
        self.delivered = 0
        self.cancelled = 0
        self.epoch_writes = 0
        self.epoch_reads = 0
        self.accounting = False

    def cancel_epoch(self) -> None:
        """Exclude the reset propagation window, whose traffic is not guaranteed."""
        self.accounting = False
        if self.queue:
            self.hits["reset_cancel"] += 1
        self.cancelled += len(self.queue)
        self.queue.clear()
        self.epoch_writes = self.epoch_reads = 0

    def observe(self, rising: set[str], ports: dict[str, int]) -> None:
        """Check one atomic pre-edge snapshot, including coincident clock edges."""
        if not self.accounting:
            return
        occupancy = len(self.queue)
        if "w" in rising and ports["o_w_init_done"]:
            level = ports["o_w_level"]
            assert occupancy <= level <= self.depth, "nonconservative write level"
            assert ports["o_w_almost_full"] == (
                level >= self.parameters["ALMOST_FULL_LEVEL"]
            ), "almost-full threshold mismatch"
            self.hits["full"] += ports["o_w_full"]
            self.hits["almost_full"] += ports["o_w_almost_full"]
        if "r" in rising and ports["o_r_init_done"]:
            level = ports["o_r_level"]
            assert 0 <= level <= occupancy, "nonconservative read level"
            assert ports["o_r_almost_empty"] == (
                level <= self.parameters["ALMOST_EMPTY_LEVEL"]
            ), "almost-empty threshold mismatch"
            self.hits["empty"] += ports["o_r_empty"]
            self.hits["almost_empty"] += ports["o_r_almost_empty"]
            self.hits["stalled_output"] += (
                ports["o_r_valid"] and not ports["i_r_ready"]
            )

        # Pop the old head before appending a simultaneous write. Both bounds
        # still use pre-edge occupancy, so an empty FIFO cannot bypass storage.
        if "r" in rising and ports["o_r_valid"] and ports["i_r_ready"]:
            assert occupancy > 0, "FIFO underflow"
            expected = self.queue.popleft()
            actual = ports["o_r_data"]
            assert actual == expected, f"FIFO data/order mismatch: {actual:#x} != {expected:#x}"
            self.delivered += 1
            self.epoch_reads += 1
            self.hits["accepted_read"] += 1
            self.hits["read_wrap"] += self.epoch_reads % self.depth == 0
        if "w" in rising and ports["i_w_valid"] and ports["o_w_ready"]:
            assert occupancy < self.depth, "FIFO overflow"
            self.queue.append(ports["i_w_data"])
            self.accepted += 1
            self.epoch_writes += 1
            self.hits["accepted_write"] += 1
            self.hits["write_wrap"] += self.epoch_writes % self.depth == 0

    def finish(self) -> None:
        """Require implemented scenario hits, then emit Python-only evidence."""
        required = (
            "accepted_write", "accepted_read", "full", "empty", "stalled_output",
            "almost_full", "almost_empty", "reset_cancel", "coordinated_reset",
            "skewed_release", "no_bubble_read", "stopped_startup", "stopped_write",
            "stopped_read", "write_reset_recovery", "read_reset_recovery",
            "ratio_fast_write", "ratio_fast_read", "ratio_equal", "ratio_coprime",
            "phase_walk", "coincident_edges",
            "stopped_startup_write", "stopped_startup_read",
            "skewed_assert_write_first", "skewed_assert_read_first",
            "equal_phase_drift", "equal_drift_write", "equal_drift_read",
            "equal_drift_slow_edges", "equal_drift_fast_edges",
            *(f"equal_drift_phase_{phase}" for phase in range(5)),
            *(
                f"reset_stop_{stopped}_{first}_first"
                for stopped in ("w", "r", "both") for first in ("w", "r")
            ),
        )
        assert all(self.hits[name] > 0 for name in required), dict(self.hits)
        assert self.hits["write_wrap"] >= 10 and self.hits["read_wrap"] >= 10
        assert not self.queue, "regression did not drain"
        assert self.accepted == self.delivered + self.cancelled, "reset accounting mismatch"
        evidence = {
            "schema": "mosaic-async-fifo-pyuvm-v1",
            "profile": os.environ.get("PROFILE", "default"),
            "parameters": self.parameters,
            "seed": SEED,
            "required_scenarios": list(required),
            "hits": dict(sorted(self.hits.items())),
            "totals": {
                "accepted": self.accepted,
                "delivered": self.delivered,
                "cancelled": self.cancelled,
                "remaining": len(self.queue),
            },
        }
        Path(os.environ["PYUVM_FUNCTIONAL_COVERAGE_FILE"]).write_text(
            json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
        )
        self.logger.info("PASS FIFO PyUVM: %s", evidence["totals"])


class FifoBfm:
    """Schedule unrelated clocks and sample handshakes before changing either."""

    def __init__(self, dut, scoreboard: FifoScoreboard) -> None:
        self.dut = dut
        self.scoreboard = scoreboard
        self.half_period = {"w": 3000, "r": 5000}
        self.running = {"w": True, "r": True}
        self.clock = {"w": 0, "r": 0}
        self.edge_counts = {"w": 0, "r": 0}
        self.phase_drift_active = False
        self.phase_drift_index = 0
        self.phase_drift_origin = 0
        self.phase_drift_pending_kind: str | None = None
        now = int(get_sim_time(unit="ps"))
        self.next_edge = {"w": now + 3000, "r": now + 6000}
        self.source_mode = "idle"
        self.sink_mode = "idle"
        self.source_accepted = False
        # Separate RNGs prevent reader timing from changing producer payloads.
        self.source_rng = random.Random(SEED)
        self.sink_rng = random.Random(SEED ^ 0x7681C032)
        self.payload_rng = random.Random(SEED ^ 0xA5A5A5A5)
        self.signals = {
            name: getattr(dut, name) for name in (
                "i_w_rstb", "i_r_rstb", "i_w_valid", "i_r_ready", "i_w_data",
                "o_w_ready", "o_w_full", "o_w_almost_full", "o_w_level",
                "o_w_init_done", "o_r_valid", "o_r_data", "o_r_empty",
                "o_r_almost_empty", "o_r_level", "o_r_init_done",
            )
        }
        for name in (
            "i_w_clk", "i_r_clk", "i_w_rstb", "i_r_rstb",
            "i_w_valid", "i_r_ready", "i_w_data",
        ):
            getattr(dut, name).value = 0

    def snapshot(self) -> dict[str, int]:
        """Capture stable interface state without reading pointers or storage."""
        return {name: int(signal.value) for name, signal in self.signals.items()}

    def drive_source(self) -> None:
        """Retain an outstanding offer until its sampled acceptance or reset."""
        if not self.scoreboard.accounting or not int(self.dut.i_w_rstb.value):
            self.dut.i_w_valid.value = 0
        elif not int(self.dut.i_w_valid.value) or self.source_accepted:
            valid = self.source_mode == "continuous" or (
                self.source_mode == "random" and self.source_rng.randrange(8) != 0
            )
            self.dut.i_w_valid.value = int(valid)
            self.dut.i_w_data.value = self.payload_rng.getrandbits(len(self.dut.i_w_data))

    async def step(self) -> set[str]:
        """Advance to the next edge and settle HDL before returning to stimulus."""
        active = [self.next_edge[domain] for domain in ("w", "r") if self.running[domain]]
        assert active, "both clocks stopped: no next event"
        next_time = min(active)
        await Timer(next_time - int(get_sim_time(unit="ps")), unit="ps")
        due = {
            domain for domain in ("w", "r")
            if self.running[domain] and self.next_edge[domain] == next_time
        }
        rising = {domain for domain in due if self.clock[domain] == 0}
        ports = self.snapshot()
        self.scoreboard.observe(rising, ports)
        if self.phase_drift_active:
            # Credit the interval that just elapsed, not the one scheduled next.
            if "r" in due and self.phase_drift_pending_kind is not None:
                self.scoreboard.hits[self.phase_drift_pending_kind] += 1
            if "r" in rising:
                phase = ((next_time - self.phase_drift_origin) % 10000) // 2000
                self.scoreboard.hits[f"equal_drift_phase_{phase}"] += 1
                self.scoreboard.hits["equal_drift_read"] += (
                    ports["o_r_valid"] and ports["i_r_ready"]
                )
            if "w" in rising:
                self.scoreboard.hits["equal_drift_write"] += (
                    ports["i_w_valid"] and ports["o_w_ready"]
                )
        if rising == {"w", "r"} and self.scoreboard.accounting:
            self.scoreboard.hits["coincident_edges"] += 1
        if "w" in rising:
            self.source_accepted = bool(ports["i_w_valid"] and ports["o_w_ready"])
        for domain in due:
            self.clock[domain] ^= 1
            self.edge_counts[domain] += 1
            getattr(self.dut, f"i_{domain}_clk").value = self.clock[domain]
            delay = self.half_period[domain]
            if domain == "r" and self.phase_drift_active:
                # Twenty 6 ns halves followed by twenty 4 ns halves have the
                # same mean period as the fixed 5 ns write-clock halves.
                slow = self.phase_drift_index % 40 < 20
                delay += 1000 if slow else -1000
                self.phase_drift_index += 1
                self.phase_drift_pending_kind = (
                    "equal_drift_slow_edges" if slow else "equal_drift_fast_edges"
                )
            self.next_edge[domain] = next_time + delay
        if "w" in due and "w" not in rising:
            self.drive_source()
        if "r" in due and "r" not in rising:
            ready = self.sink_mode == "continuous" or (
                self.sink_mode == "random" and self.sink_rng.randrange(8) > 2
            )
            self.dut.i_r_ready.value = int(self.scoreboard.accounting and ready)
        # Sampling before clock writes avoids simulator-specific RisingEdge/NBA
        # ordering. ReadWrite lets bound SVA/HDL settle without advancing past
        # another scheduled edge, and permits subsequent reset/mode changes.
        await ReadWrite()
        return rising

    async def steps(self, count: int) -> None:
        """Run a bounded number of scheduled events, not shared-clock cycles."""
        for _ in range(count):
            await self.step()

    async def elapse(self, duration_ps: int) -> None:
        """Advance real time without skipping running edges, even with both stopped."""
        assert duration_ps > 0
        deadline = int(get_sim_time(unit="ps")) + duration_ps
        while any(
            self.running[domain] and self.next_edge[domain] <= deadline
            for domain in ("w", "r")
        ):
            await self.step()
        remaining = deadline - int(get_sim_time(unit="ps"))
        if remaining:
            await Timer(remaining, unit="ps")
            await ReadWrite()

    async def wait_until(self, predicate: Callable[[], bool], limit: int = 10000) -> None:
        """Fail rather than hang if initialization, filling, or draining stalls."""
        for _ in range(limit):
            if predicate():
                return
            await self.step()
        raise AssertionError("FIFO PyUVM bounded wait timed out")

    async def falling(self, domain: str) -> None:
        """Return just after a new falling edge in the requested running domain."""
        assert self.running[domain]
        while True:
            previous = self.clock[domain]
            await self.step()
            if previous == 1 and self.clock[domain] == 0:
                return

    async def pause(self, domain: str) -> None:
        """Stop only at a low clock level to avoid manufacturing extra edges."""
        if self.clock[domain]:
            await self.falling(domain)
        self.running[domain] = False

    def resume(self, domain: str) -> None:
        """Restart an independent clock with a fresh positive half-period."""
        self.running[domain] = True
        self.next_edge[domain] = int(get_sim_time(unit="ps")) + self.half_period[domain]

    def periods(self, write_ns: int, read_ns: int, coincident: bool = False) -> None:
        """Change periods, optionally aligning the next edges for a race control."""
        now = int(get_sim_time(unit="ps"))
        assert write_ns > 0 and read_ns > 0
        self.half_period = {"w": write_ns * 1000, "r": read_ns * 1000}
        for domain in ("w", "r"):
            self.next_edge[domain] = now + self.half_period[domain]
        if coincident:
            assert self.clock["w"] == self.clock["r"] == 0
            self.next_edge["r"] = self.next_edge["w"]

    def start_equal_phase_drift(self) -> None:
        """Walk five relative phases in both directions with equal nominal rates."""
        assert all(self.running.values()) and self.clock["w"] == self.clock["r"] == 0
        self.periods(5, 5, coincident=True)
        self.phase_drift_index = 0
        self.phase_drift_origin = self.next_edge["w"]
        self.phase_drift_pending_kind = None
        self.phase_drift_active = True

    def stop_equal_phase_drift(self) -> None:
        """Return to fixed periods without generating an unscheduled clock edge."""
        self.phase_drift_active = False
        self.phase_drift_pending_kind = None
        self.periods(5, 5)

    def cancel(self) -> None:
        """End the model epoch before asserting either reset input."""
        self.scoreboard.cancel_epoch()
        self.source_mode = self.sink_mode = "idle"
        self.source_accepted = False
        self.dut.i_w_valid.value = 0
        self.dut.i_r_ready.value = 0

    async def release(self, domain: str) -> None:
        """Release reset away from the active edge of its own clock."""
        await self.falling(domain)
        getattr(self.dut, f"i_{domain}_rstb").value = 1

    def check_reset_outputs(self, domain: str) -> None:
        """Check asynchronous public reset state without consulting DUT internals."""
        assert not int(getattr(self.dut, f"i_{domain}_rstb").value)
        assert not int(getattr(self.dut, f"o_{domain}_init_done").value)
        assert int(getattr(self.dut, f"o_{domain}_level").value) == 0
        if domain == "w":
            assert int(self.dut.o_w_full.value) and not int(self.dut.o_w_ready.value)
        else:
            assert int(self.dut.o_r_empty.value) and not int(self.dut.o_r_valid.value)
            assert int(self.dut.o_r_data.value) == 0

    async def assert_reset(self, domain: str) -> None:
        """Assert a local reset and verify settled state even without clock edges."""
        getattr(self.dut, f"i_{domain}_rstb").value = 0
        await self.elapse(1)
        self.check_reset_outputs(domain)

    def check_startup_blocked(self) -> None:
        """Neither endpoint may transfer while one side cannot finish startup."""
        assert not int(self.dut.o_w_init_done.value) and not int(self.dut.o_r_init_done.value)
        assert not int(self.dut.o_w_ready.value) and not int(self.dut.o_r_valid.value)

    async def startup_stopped(self, stopped: str) -> None:
        """Release the running side first and keep the stopped side in reset."""
        running = "r" if stopped == "w" else "w"
        await self.pause(stopped)
        self.cancel()
        await self.assert_reset("w")
        await self.assert_reset("r")
        edges = self.edge_counts[stopped]
        await self.steps(40)
        await self.release(running)
        await self.steps(40)
        self.check_startup_blocked()
        assert self.edge_counts[stopped] == edges and self.clock[stopped] == 0
        self.resume(stopped)
        await self.release(stopped)
        await self.initialize()
        self.scoreboard.hits["stopped_startup"] += 1
        self.scoreboard.hits[f"stopped_startup_{'write' if stopped == 'w' else 'read'}"] += 1

    async def reset(self, skewed: bool = False, assertion_first: str | None = None) -> None:
        """Cancel pending records and recover only through a coordinated reset."""
        self.cancel()
        if assertion_first is None:
            self.dut.i_w_rstb.value = self.dut.i_r_rstb.value = 0
        else:
            peer = "r" if assertion_first == "w" else "w"
            await self.assert_reset(assertion_first)
            await self.elapse(
                2 * (self.scoreboard.parameters["SYNC_STAGES"] + 4)
                * max(self.half_period.values())
            )
            assert not int(getattr(self.dut, f"o_{peer}_init_done").value)
            transfer = "o_w_ready" if peer == "w" else "o_r_valid"
            assert not int(getattr(self.dut, transfer).value)
            await self.assert_reset(peer)
            self.scoreboard.hits[
                f"skewed_assert_{'write' if assertion_first == 'w' else 'read'}_first"
            ] += 1
        await self.steps(40)
        await self.release("w")
        if skewed:
            await self.steps(24)
            self.scoreboard.hits["skewed_release"] += 1
        await self.release("r")
        await self.initialize()
        self.scoreboard.hits["coordinated_reset"] += 1

    async def reset_while_stopped(self, stopped: str, first: str) -> None:
        """Exercise skewed reset and staggered clock restart of a canceled epoch."""
        domains = ("w", "r") if stopped == "both" else (stopped,)
        for domain in domains:
            await self.pause(domain)
        edges = self.edge_counts.copy()
        self.cancel()
        second = "r" if first == "w" else "w"
        await self.assert_reset(first)
        gap = (
            2 * (self.scoreboard.parameters["SYNC_STAGES"] + 4)
            * max(self.half_period.values())
        )
        await self.elapse(gap)
        if self.running[second]:
            assert not int(getattr(self.dut, f"o_{second}_init_done").value)
            transfer = "o_w_ready" if second == "w" else "o_r_valid"
            assert not int(getattr(self.dut, transfer).value)
        await self.assert_reset(second)
        await self.elapse(gap)
        for domain in domains:
            assert self.edge_counts[domain] == edges[domain] and self.clock[domain] == 0
        self.check_reset_outputs("w")
        self.check_reset_outputs("r")

        # With both clocks stopped, restart the first-reset side alone. With
        # one stopped, release the side already running before restarting it.
        early = first if stopped == "both" else ("r" if stopped == "w" else "w")
        late = "r" if early == "w" else "w"
        if not self.running[early]:
            self.resume(early)
        await self.release(early)
        await self.elapse(gap)
        self.check_startup_blocked()
        assert self.edge_counts[late] == edges[late] and self.clock[late] == 0
        self.resume(late)
        await self.release(late)
        await self.initialize()
        self.scoreboard.hits["coordinated_reset"] += 1

    async def initialize(self) -> None:
        """Start reference accounting only after both domains finish startup."""
        await self.wait_until(lambda: bool(
            int(self.dut.o_w_init_done.value) and int(self.dut.o_r_init_done.value)
        ))
        await self.steps(16)
        self.scoreboard.accounting = True

    async def drain(self) -> None:
        """Honor a held producer offer, then wait for the final empty indication."""
        self.source_mode = "idle"
        self.sink_mode = "continuous"
        await self.wait_until(lambda: not int(self.dut.i_w_valid.value))
        await self.wait_until(
            lambda: not self.scoreboard.queue and int(self.dut.o_r_empty.value) and
            not int(self.dut.o_r_valid.value)
        )
        await self.steps(32)


class FifoEnvironment(uvm_env):
    """Own the profile-specific scoreboard and interface-only BFM."""

    def build_phase(self) -> None:
        """Derive default thresholds after applying the selected depth."""
        raw = json.loads(os.environ.get("PROFILE_PARAMETERS_JSON", "{}"))
        depth = int(raw.get("DEPTH", 8))
        self.parameters = {
            "DATA_WIDTH": int(raw.get("DATA_WIDTH", 32)),
            "DEPTH": depth,
            "SYNC_STAGES": int(raw.get("SYNC_STAGES", 2)),
            "ALMOST_FULL_LEVEL": int(raw.get("ALMOST_FULL_LEVEL", depth - 1)),
            "ALMOST_EMPTY_LEVEL": int(raw.get("ALMOST_EMPTY_LEVEL", 1)),
        }
        assert len(cocotb.top.i_w_data) == self.parameters["DATA_WIDTH"]
        self.scoreboard = FifoScoreboard("scoreboard", self)
        self.scoreboard.configure(self.parameters)
        self.bfm = FifoBfm(cocotb.top, self.scoreboard)
