# Interface specification

[Return to the module documentation index](README.md).

This file defines the public hardware contract. Replace the template reference
interface below when creating a real module. Any behavior on which another block
depends must be stated here and verified by the
[verification plan](verification-plan.md).

## Overview

The template `mosaic_module` is a parameterized enabled register. On each rising
clock edge, it captures `data_i` when `enable_i` is asserted. It holds its
previous output otherwise. An active-low asynchronous reset clears the output.

This example exists only to prove the repository infrastructure. It is not a
MOSAIC architectural block.

## Parameters

| Parameter | Type | Default | Legal values | Description |
| --- | --- | --- | --- | --- |
| `DATA_WIDTH` | `int unsigned` | `32` | Positive integers | Width of `data_i` and `data_o` |

The normal template elaboration uses 32 bits. The qualification example also
uses 1 and 64 bits. A negative campaign confirms that `DATA_WIDTH=0` is rejected
by elaboration. A production module should add explicit static parameter checks
when its supported frontend set provides a portable mechanism.

## Clocks and resets

| Signal | Role | Active edge or level | Behavior |
| --- | --- | --- | --- |
| `clk_i` | Functional clock | Rising edge | Samples enable and input data |
| `rst_ni` | Asynchronous reset | Low level | Clears `data_o` to zero |

Reset assertion is asynchronous. Functional state becomes zero without waiting
for a clock edge. Reset release is consumed by the next rising `clk_i` edge. The
integration must satisfy the selected technology's reset recovery and removal
requirements.

## Ports

| Port | Direction | Width | Description |
| --- | --- | --- | --- |
| `clk_i` | Input | 1 | Functional clock |
| `rst_ni` | Input | 1 | Active-low asynchronous reset |
| `enable_i` | Input | 1 | Enables capture of `data_i` |
| `data_i` | Input | `DATA_WIDTH` | Input data sampled when enabled |
| `data_o` | Output | `DATA_WIDTH` | Registered output data |

## Functional behavior

At a rising `clk_i` edge:

| Condition | Next `data_o` |
| --- | --- |
| `rst_ni == 0` | Zero |
| `rst_ni == 1` and `enable_i == 1` | Current `data_i` |
| `rst_ni == 1` and `enable_i == 0` | Previous `data_o` |

Reset has priority over enable.

## Timing contract

- Capture latency is one rising clock edge.
- Throughput is one `DATA_WIDTH` value per cycle while enabled.
- There is no ready or backpressure signal.
- Inputs must meet the implementation's setup and hold requirements.
- `data_o` remains stable across disabled cycles unless reset is asserted.

The example synthesis constraint defines a 10 ns clock period, 0.1 ns
uncertainty, and 0.5 ns interface delays. These are template values and must be
replaced or justified for a production module.

## Errors and illegal use

The template has no error output and performs no runtime protocol checking.
Unknown data values follow SystemVerilog simulation and synthesis semantics.
An X or Z value on `enable_i` is illegal verification stimulus and the dedicated
four-state monitor rejects it. This monitor is verification collateral rather
than a hardware error output. Production modules must define illegal
transactions, error reporting, and recovery behavior explicitly.

## Low-power behavior

The example UPF declares one always-on power domain. It defines no switchable
domain, isolation, retention, level shifting, or power-state table. A module
with power management must document:

- Legal power states and transitions
- State retained or lost in each state
- Isolation values and timing
- Required clock and reset sequencing
- Behavior of outputs while a domain is off

## Integration assumptions

- `clk_i` is free running while functional updates are required.
- The integration provides legal reset deassertion for the target technology.
- `enable_i` and `data_i` belong to the `clk_i` domain in this example.
- The consumer does not rely on behavior outside the parameter and reset
  contract above.

## Production replacement checklist

- [ ] Replace the example overview and behavior.
- [ ] Document every parameter and legal combination.
- [ ] Document every port, clock, reset, and protocol relationship.
- [ ] State latency, throughput, ordering, and backpressure.
- [ ] Define errors, illegal inputs, and recovery.
- [ ] Define disabled, test-mode, reset, and low-power behavior.
- [ ] Link each requirement to verification evidence.
- [ ] Review this document with both module and integration owners.
