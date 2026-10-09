"""PyUVM FIFO regression using the shared simulator-bound SVA/coverage layers."""

from cocotb.triggers import with_timeout
from cocotb.utils import get_sim_time
from pyuvm import test, uvm_test

from async_fifo_env import FifoEnvironment


@test()
class AsyncFifoTest(uvm_test):
    """Exercise independent clock domains, reset epochs, and opaque records."""

    def build_phase(self) -> None:
        """Use PyUVM hierarchy for the model and interface driver."""
        self.env = FifoEnvironment("env", self)

    async def run_phase(self) -> None:
        """Keep the UVM phase alive until all scenarios and evidence complete."""
        self.raise_objection()
        await with_timeout(self.exercise(), 20, "ms")
        self.env.scoreboard.finish()
        self.drop_objection()

    async def exercise(self) -> None:
        """Run deterministic scenarios for every selected parameter profile."""
        bfm = self.env.bfm
        model = self.env.scoreboard
        dut = bfm.dut
        depth = model.depth
        # The first startup has no write-clock edges until explicitly resumed.
        bfm.running["w"] = False
        dut.i_w_rstb.value = dut.i_r_rstb.value = 1
        await bfm.elapse(1)
        await bfm.startup_stopped("w")

        # Fill and hold a visible head long enough to exercise HDL hold SVA.
        bfm.source_mode = "continuous"
        await bfm.wait_until(
            lambda: len(model.queue) == depth and int(dut.o_w_full.value) and
            int(dut.o_r_valid.value)
        )
        await bfm.steps(80)
        await bfm.reset(skewed=True)

        # Exercise the symmetric startup after a coordinated canceled epoch.
        await bfm.startup_stopped("r")

        # Reset assertion skew is distinct from the existing skewed release.
        for first in ("w", "r"):
            bfm.source_mode = "continuous"
            bfm.sink_mode = "idle"
            await bfm.wait_until(
                lambda: len(model.queue) == depth and int(dut.o_r_valid.value)
            )
            await bfm.reset(skewed=True, assertion_first=first)

        # Prefill all records and make the entire burst visible before reading.
        bfm.source_mode = "continuous"
        bfm.sink_mode = "idle"
        await bfm.wait_until(
            lambda: len(model.queue) == depth and int(dut.o_r_level.value) == depth
        )
        bfm.source_mode = "idle"
        bfm.sink_mode = "continuous"
        await bfm.falling("r")
        reads = 0
        while reads < depth:
            previous = model.delivered
            rising = await bfm.step()
            if "r" in rising:
                assert model.delivered == previous + 1, "registered output inserted a bubble"
                reads += 1
        model.hits["no_bubble_read"] += 1
        await bfm.drain()

        bfm.source_mode = "continuous"
        bfm.sink_mode = "idle"
        await bfm.wait_until(
            lambda: len(model.queue) >= max(1, depth // 2) and int(dut.o_r_valid.value)
        )
        await bfm.reset()

        # Ratios include exact coincident rising edges, not just equal periods.
        for name, write_ns, read_ns in (
            ("fast_write", 2, 7), ("fast_read", 11, 3),
            ("equal", 5, 5), ("coprime", 7, 11),
        ):
            if name == "equal":
                await bfm.pause("w")
                await bfm.pause("r")
                bfm.resume("w")
                bfm.resume("r")
            bfm.periods(write_ns, read_ns, coincident=name == "equal")
            bfm.source_mode = bfm.sink_mode = "random"
            await bfm.steps(400 * depth)
            await bfm.drain()
            model.hits[f"ratio_{name}"] += 1

        # Fixed 10 ns write cycles and a balanced 12/8 ns read-cycle pattern
        # walk five measured relative phases without changing the mean rate.
        await bfm.pause("w")
        await bfm.pause("r")
        bfm.resume("w")
        bfm.resume("r")
        drift_edges = bfm.edge_counts.copy()
        bfm.start_equal_phase_drift()
        bfm.source_mode = bfm.sink_mode = "random"
        await bfm.wait_until(lambda: bfm.phase_drift_index >= 40 * depth + 1)
        assert int(get_sim_time(unit="ps")) - bfm.phase_drift_origin == 200000 * depth
        assert all(
            bfm.edge_counts[domain] - drift_edges[domain] == 40 * depth + 1
            for domain in ("w", "r")
        ), "drifting clocks did not maintain equal average rates"
        assert model.hits["equal_drift_slow_edges"] == 20 * depth
        assert model.hits["equal_drift_fast_edges"] == 20 * depth
        bfm.stop_equal_phase_drift()
        await bfm.drain()
        model.hits["equal_phase_drift"] += 1

        # Reproducible phase walk changes periods independently while streaming.
        bfm.source_mode = bfm.sink_mode = "random"
        for interval in range(50):
            bfm.periods(2 + interval % 11, 2 + (interval * 7) % 13)
            await bfm.steps(80)
            model.hits["phase_walk"] += 1
        await bfm.drain()

        bfm.source_mode = "continuous"
        bfm.sink_mode = "idle"
        await bfm.pause("r")
        await bfm.wait_until(lambda: int(dut.o_w_full.value) and len(model.queue) == depth)
        await bfm.steps(80)
        bfm.resume("r")
        await bfm.drain()
        model.hits["stopped_read"] += 1

        bfm.source_mode = bfm.sink_mode = "continuous"
        await bfm.steps(80)
        await bfm.pause("w")
        await bfm.wait_until(lambda: not model.queue and int(dut.o_r_empty.value))
        await bfm.steps(80)
        bfm.resume("w")
        await bfm.drain()
        model.hits["stopped_write"] += 1

        # Start every stopped-clock reset with live, backpressured records.
        # Count a case only after newly generated records survive recovery.
        bfm.periods(3, 5)
        for stopped in ("w", "r", "both"):
            for first in ("w", "r"):
                bfm.source_mode = "continuous"
                bfm.sink_mode = "idle"
                await bfm.wait_until(
                    lambda: len(model.queue) == depth and int(dut.o_r_valid.value)
                )
                pending = len(model.queue)
                cancelled = model.cancelled
                await bfm.reset_while_stopped(stopped, first)
                assert model.cancelled == cancelled + pending
                delivered = model.delivered
                bfm.source_mode = bfm.sink_mode = "continuous"
                await bfm.steps(80 * depth)
                await bfm.drain()
                assert model.delivered > delivered, "no post-reset records were checked"
                model.hits[f"reset_stop_{stopped}_{first}_first"] += 1

        # Peer shutdown is sticky: unilateral release must never restart traffic.
        for reset_domain, peer_domain, peer_transfer in (
            ("w", "r", "o_r_valid"), ("r", "w", "o_w_ready"),
        ):
            bfm.source_mode = "continuous"
            bfm.sink_mode = "idle"
            await bfm.wait_until(lambda: int(dut.o_r_valid.value))
            bfm.cancel()
            getattr(dut, f"i_{reset_domain}_rstb").value = 0
            await bfm.steps(40 + 8 * self.env.parameters["SYNC_STAGES"])
            assert not int(getattr(dut, f"o_{peer_domain}_init_done").value)
            assert not int(getattr(dut, peer_transfer).value)
            await bfm.release(reset_domain)
            await bfm.steps(40)
            assert not int(dut.o_w_init_done.value) and not int(dut.o_r_init_done.value)
            await bfm.reset(skewed=True)
            bfm.source_mode = bfm.sink_mode = "continuous"
            await bfm.steps(80 * depth)
            await bfm.drain()
            model.hits[f"{'write' if reset_domain == 'w' else 'read'}_reset_recovery"] += 1
