# Module documentation

This directory contains design-owned documentation for one MOSAIC RTL module.
The root [repository README](../README.md) is the concise operational entry point
for setup and execution. This file is the canonical index for detailed module
design, configuration, verification, waiver, and release records.

Shared methodology behavior remains documented under
[`mosaic-flow/docs/`](../mosaic-flow/docs/README.md).

## Ownership boundary

Documentation here describes this module:

- Its hardware interface and behavior
- Its architecture and implementation choices
- Its verification intent and coverage
- Its constraints, power intent, and accepted waivers
- Its release evidence and supported configurations

Documentation under `mosaic-flow/docs/` describes the reusable methodology:

- How orchestration and quality gates work
- What each flow consumes and produces
- Shared configuration precedence and status semantics
- How shared adapters and tool versions are maintained

Do not copy shared methodology documentation into this directory. Link to it and
keep module-specific decisions here.

## Recommended reading order

1. [Creating a module](creating-a-module.md) explains how to turn this template
   into a new independently versioned RTL repository.
2. [Repository structure](repository-structure.md) explains where each artifact
   belongs and why the hierarchy is split this way.
3. [Multi-module repositories](multi-module-repositories.md) defines the
   optional hierarchy, manifest, CI matrix, and regression contract for a
   repository that owns several related RTL modules.
4. [Project configuration](project-configuration.md) covers module identity,
   file lists, flow selection, dependencies, constraints, and site inputs.
5. [Interface specification](interface.md) defines the hardware contract that
   consumers may rely on.
6. [Verification plan](verification-plan.md) maps requirements to SystemVerilog
   simulation, PyUVM, shared assertions, formal properties, and coverage.
7. [Qualification and release evidence](qualification.md) explains parameter
   profiles, coverage, campaigns, static intent, OpenROAD, and manifests.
8. [Reviewed waivers](waivers.md) records every accepted tool exception.
9. [Release checklist](release-checklist.md) defines the evidence required
   before publishing a module revision.

## Quick reference

| Goal | Location or command |
| --- | --- |
| Rename the example design | [Creating a module](creating-a-module.md#rename-the-example-module) |
| Configure several module roots | [Multi-module repositories](multi-module-repositories.md) |
| Set top names and paths | `config/design.mk` |
| Enable or disable checks | `config/flows.mk` |
| Add RTL sources | `filelists/rtl.f` |
| Add simulation sources | `filelists/tb.f` |
| Define shared properties | `filelists/properties.f` |
| Define assertions | `filelists/assertions.f` |
| Define HDL coverage | `filelists/coverage.f` |
| Add PyUVM tests | `verif/pyuvm/` |
| Define formal proof and covers | `flows/symbiyosys/` |
| Define synthesis timing | `flows/synthesis/timing.sdc` |
| Define CDC intent | `flows/cdc/constraints.tcl` |
| Define DFT intent | `flows/sg_dft/constraints.tcl` |
| Define power intent | `flows/vc_lp/power.upf` |
| Define coverage policy | `config/coverage-policy.json` |
| Define negative and four-state campaigns | `config/qualification-campaigns.json` |
| Define portable SDC and UPF expectations | `config/static-intent.json` |
| Declare parameter profiles | `config/parameter-profiles.json` |
| Define physical evidence policy | `flows/openroad/evidence-policy.json` |
| Validate project policy | `make flow-config-check` |
| Run portable acceptance | `make clean open-source` |
| Run all parameter profiles | `make all-profiles PROFILE_JOBS=4` |
| Run containerized OpenROAD | `make FLOW_openroad=enabled OPENROAD_EXECUTION_MODE=container open-physical` |
| Build a release manifest | `make release-manifest release-manifest-validate` |
| Validate PyUVM evidence | `./.github/scripts/check-pyuvm-evidence.sh` |
| Inspect results | `reports/<flow-id>/` |

## Documentation completion rule

The template text is not release evidence. Replace examples and instructions
with reviewed module-specific content before the first release. Update the
affected document whenever a port, parameter, protocol, supported configuration,
constraint, verification item, waiver, or release policy changes.
