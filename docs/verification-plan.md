# Verification plan

[Return to the module documentation index](README.md).

This plan maps the public [interface specification](interface.md) to unit-level
evidence. The current content describes the template smoke design and provides a
structure to replace for a production module.

## Verification objectives

The template verifies:

- Asynchronous reset clears the output
- An enabled rising edge captures input data
- A disabled rising edge preserves output data
- The directed behavior passes through both SystemVerilog and PyUVM stimulus
- Shared assertions run under normal simulation, PyUVM, and formal proof
- Representative property antecedents are reachable in formal cover mode
- RTL compiles and elaborates in independent frontends
- RTL is generically synthesizable
- Yosys synthesis preserves RTL behavior under the configured EQY strategy
- Minimum, nominal, and wide parameter profiles propagate consistently through
  elaboration, lint, synthesis, formal, equivalence, simulation, and PyUVM
- Quantitative HDL and formal coverage policy passes
- Negative controls prove assertion, elaboration, equivalence, and monitor
  failures are detected
- A pinned four-state simulator detects X and Z on the example control input
- Portable SDC and UPF intent matches the module-owned expectation

The example demonstrates the qualification mechanisms. It does not claim that
the three representative widths close the parameter space of a replacement
production module.

## Verification environments

| Environment | Top | Purpose |
| --- | --- | --- |
| Verilator simulation | `mosaic_module_tb` | Directed SystemVerilog stimulus, bound SVA, and native coverage |
| PyUVM with Verilator | `mosaic_module` | Python-driven smoke test, the same bound SVA, native coverage, and functional coverage |
| VCS simulation | `mosaic_module_tb` | Licensed simulation and SAIF generation path |
| SymbiYosys proof | `mosaic_module_formal` | Reset, update, and hold proofs using the shared assertion wrapper |
| SymbiYosys cover | `mosaic_module_formal` | Reachability of representative reset, update, and hold scenarios |
| EQY | `mosaic_module` | RTL-to-Yosys-netlist equivalence |
| Static frontends | `mosaic_module` | Style, lint, compile, hierarchy, and synthesizability checks |
| Coverage qualification | Collected Verilator and SymbiYosys evidence | Enforce line, branch, toggle, user, named coverpoint, and formal-cover policy |
| Negative campaign | Module-owned controls and mutations | Prove expected failures are attributable and do not escape |
| Icarus four-state campaign | `mosaic_module_four_state_tb` | Prove X and Z control detection with a disabled-monitor control |
| Static-intent validator | Module SDC and UPF | Check the supported portable timing and power-intent subset |
| Containerized ORFS | `mosaic_module` | Produce exploratory Nangate45 physical evidence |

## Requirements traceability

| ID | Requirement | SystemVerilog simulation | PyUVM | Assertion or formal evidence |
| --- | --- | --- | --- | --- |
| `REQ-RST-001` | Active reset clears `data_o` | Reset sequence in `mosaic_module_tb` | Reset phase in `MosaicModuleTest` | `reset_clears_output` |
| `REQ-DATA-001` | Enabled edge captures `data_i` | Width-aware all-ones transfer | Enabled-update phase and functional coverage | `output_updates_when_enabled` |
| `REQ-HOLD-001` | Disabled edge preserves `data_o` | Disable after directed transfer | Disabled-hold phase and functional coverage | `output_holds_when_disabled` |
| `REQ-SYN-001` | RTL is synthesizable | Not applicable | Not applicable | Yosys synthesis and structural checks |
| `REQ-EQY-001` | Generic netlist matches RTL | Not applicable | Not applicable | EQY SAT strategy |

Replace this table with every production requirement. A requirement without an
evidence mapping is not covered merely because the testbench passes.

## Simulation plan

The current directed test:

1. Holds asynchronous reset active for two rising edges.
2. Releases reset on a falling edge.
3. Captures an all-ones input value.
4. Changes the input to zero while disabled and checks that the output holds.
5. Re-enables capture and checks the zero transition.
6. Reasserts asynchronous reset and checks that the output clears.
7. Waits long enough for one-cycle implication assertions to complete.

Production simulation must add as applicable:

- All commands, responses, opcodes, and error paths
- Minimum, maximum, and representative parameter values
- Reset assertion and release at varied clock phases
- Back-to-back traffic, idle gaps, and backpressure
- Boundary values, overflow, underflow, and signedness cases
- Concurrent events and arbitration
- Low-power and test-mode sequences
- Randomized regressions with recorded seeds
- Scoreboards or reference models independent from DUT logic

## Assertion plan

Reusable sequences live in `verif/properties/mosaic_module_sequences.svh`, and
named properties live in `verif/properties/mosaic_module_properties.svh`. The
assertion checker includes those properties and is attached to the DUT through
`verif/assertions/mosaic_module_bind.sv` in normal simulation and PyUVM.
Verilator enables assertions with `--assert`. The formal harness explicitly
instantiates the same checker rather than relying on `bind`.

For every assertion, document:

- Requirement ID
- Clock and reset domain
- Antecedent reachability
- Failure severity
- Formal and simulation applicability
- Any legal disable condition

An assertion that never reaches its antecedent is not useful evidence. Add cover
properties or coverage points for important activation conditions.

## PyUVM plan

`verif/pyuvm/test_mosaic_module.py` repeats reset, enabled-update, and
disabled-hold behavior through cocotb. PyUVM owns Python stimulus and checking.
It does not call SVA. The HDL simulator compiles the shared assertion and
coverage wrappers, then evaluates them concurrently while PyUVM drives the DUT.

The flow must retain a clean JUnit result, native coverage, and the separate
`functional-coverage.json` summary under `reports/pyuvm_open_source/`. The
repository CI evidence check verifies that all files exist and that native
coverage names both the assertion and coverage source areas.

## Formal plan

The formal harness treats reset, enable, and input data as symbolic. Proof mode
checks reset behavior plus enabled update and disabled hold behavior with an
induction depth of eight. Cover mode demonstrates that representative
antecedents and transfers are reachable.

Before release, review:

- Whether every assumption represents a real integration guarantee
- Whether reset initialization permits all legal startup behavior
- Whether proof depth is justified
- Whether liveness properties need fairness assumptions
- Whether covers demonstrate key legal scenarios are reachable
- Whether parameter configurations require separate proofs

Retain counterexamples for failed properties as debugging evidence. Do not waive
a failing property by strengthening assumptions without an interface review.

## Equivalence plan

EQY compares `rtl/mosaic_module.sv` with the netlist generated under
`work/yosys_synthesis/`. Yosys synthesis is a declared dependency and must record
`PASS` first.

The current SAT strategy uses depth eight. A production module must justify its
strategy and account for memories, black boxes, undriven state, initialization,
and any synthesis transformations that require matching rules.

## Coverage plan

The template produces native Verilator coverage for normal simulation and
PyUVM, a separate JSON functional coverage summary from PyUVM, and formal cover
reachability results. `config/coverage-policy.json` currently requires 90
percent line, branch, and toggle coverage, 100 percent user coverage, hits on
four named coverpoints, and passing formal cover reachability. A production
plan must review and replace these example targets as appropriate:

| Coverage type | Required content |
| --- | --- |
| Requirements | Every requirement has at least one evidence item |
| Functional | Features, modes, transitions, errors, and cross coverage |
| Assertions | Antecedent attempts, passes, failures, and vacuity review |
| Code | Statement, branch, expression, toggle, and FSM goals as applicable |
| Formal | Proven, failed, bounded, unreachable, and covered property counts |

State quantitative targets and the approval process for exclusions.

Review native and Python coverage independently. Python bins do not prove that
bound SVA or HDL cover properties executed, while native HDL coverage does not
replace transaction and scenario coverage sampled by the verification model.

## Parameter and configuration matrix

The versioned demonstration manifest is
`config/examples/parameter-profiles.json`. It stays outside the default path so
the repository remains usable with the simple no-profile command.

| Configuration | Simulation | Formal | Synthesis | Equivalence | Status |
| --- | --- | --- | --- | --- | --- |
| `DATA_WIDTH=1` | Required | Required | Required | Required | Boundary profile |
| `DATA_WIDTH=32` | Required | Required | Required | Required | Nominal profile |
| `DATA_WIDTH=64` | Required | Required | Required | Required | Wide profile |

The manifest also selects elaboration, lint, PyUVM, and static-intent evidence
for every profile. The shared runner translates `DATA_WIDTH` for each backend,
renders profile-local formal and EQY configuration, and isolates every report,
work product, and synthesized netlist below the profile name. The bounded
aggregate preserves completed evidence and fails if any child fails or is
missing.

This representative matrix is infrastructure evidence, not automatic proof of
every legal positive integer. A production module must select its legal
boundaries and both sides of every structural feature toggle.

## Negative testing

`config/qualification-campaigns.json` proves that checking fails when behavior
is wrong. It contains successful simulation and equivalence controls plus
dedicated negative fixtures for:

- A mutation that violates enabled capture behavior
- An illegal zero width rejected during elaboration
- A deliberately inequivalent candidate netlist
- X and Z control values detected by a four-state monitor

The CI acceptance script additionally proves that deficient coverage, an
escaped mutation, an unavailable tool, a disabled X/Z monitor, and malformed
static intent all fail closed. Deliberately incorrect RTL remains isolated under
`verif/mutations/` and is not included in normal file lists.

## Exit criteria

- [ ] Every interface requirement has reviewed evidence.
- [ ] All supported configurations complete their required matrix.
- [ ] Enabled portable flows record `PASS`.
- [ ] Disabled portable flows have an approved reason and record `SKIP`.
- [ ] Simulation regressions pass with recorded tests and seed policy.
- [ ] PyUVM reports clean JUnit, native coverage, and functional coverage evidence.
- [ ] Assertions have no failures and meaningful activation is demonstrated.
- [ ] Formal properties are proven and required cover properties are reachable.
- [ ] Equivalence passes for every required synthesis configuration.
- [ ] Coverage goals are met and exclusions are approved.
- [ ] Negative and four-state campaigns pass with their positive controls.
- [ ] Portable static intent passes and its limitations are understood.
- [ ] Every selected parameter profile has isolated complete evidence.
- [ ] Release manifests validate for each required execution context.
- [ ] All waivers are recorded in [Reviewed waivers](waivers.md).
- [ ] The release checklist is complete.
