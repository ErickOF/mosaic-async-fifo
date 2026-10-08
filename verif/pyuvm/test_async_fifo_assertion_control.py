"""Negative-campaign test: shared HDL input_hold must detect producer corruption.

This module is excluded from the positive regression. The negative campaign
selects it with isolated output roots and requires the named SVA diagnostic.
"""

from pyuvm import test, uvm_test

from async_fifo_env import FifoEnvironment


@test()
class AsyncFifoAssertionControl(uvm_test):
    """Intentionally break a held write offer after its SVA antecedent fires."""

    def build_phase(self) -> None:
        """Reuse the positive test's interface environment and shared HDL layers."""
        self.env = FifoEnvironment("env", self)

    async def run_phase(self) -> None:
        """A full FIFO must reject a payload change on a stalled valid offer."""
        self.raise_objection()
        bfm = self.env.bfm
        dut = bfm.dut
        await bfm.reset()
        bfm.source_mode = "continuous"
        await bfm.wait_until(
            lambda: int(dut.o_w_full.value) and int(dut.i_w_valid.value)
        )
        await bfm.steps(40)
        await bfm.falling("w")
        self.logger.info("PYUVM_INPUT_HOLD_FAULT_REACHED")
        dut.i_w_data.value = int(dut.i_w_data.value) ^ 1
        await bfm.steps(20)
        raise RuntimeError("PYUVM_ASSERTION_ESCAPED: input_hold did not detect the fault")
