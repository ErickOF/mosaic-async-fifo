# MOSAIC RTL module repository template

Template for one independently versioned MOSAIC RTL module. Each module owns
its implementation, unit verification, design constraints, flow policy, and
release evidence. The reusable execution methodology is pinned through the
`mosaic-flow` Git submodule.

## Start here

This file is the operational entry point for cloning and running the repository.
The [module documentation index](docs/README.md) organizes the detailed design,
configuration, verification, waiver, and release records. Shared flow behavior
and tool adapters are documented in
[`mosaic-flow/docs/`](mosaic-flow/docs/README.md).

Initialize the pinned methodology and run the portable acceptance gate:

```sh
git submodule update --init --recursive
make flow-config-check
make clean open-source
```

The first open-source target installs the pinned OSS CAD Suite, Verible, Slang,
PyUVM, and cocotb releases under
`${XDG_CACHE_HOME:-$HOME/.cache}/mosaic`. Set `MOSAIC_TOOLS_ROOT` to use another
cache location.

## Repository contract

Each module repository owns:

- Synthesizable RTL and public packages
- Unit-level tests, assertions, formal properties, and coverage
- Module-specific timing, CDC, DFT, and low-power intent
- Flow enablement policy and design-owned flow inputs
- Reviewed waivers with justification and ownership
- Reproducible release evidence for supported configurations

The module must remain independently verifiable before system integration.

## Layout

```text
rtl/                  Synthesizable SystemVerilog
verif/                TB, PyUVM, properties, assertions, formal, and coverage
filelists/            Ordered design and verification source lists
config/               Module identity and flow policy
flows/                Module-owned inputs grouped by shared flow name
docs/                 Design, configuration, verification, and release records
mosaic-flow/           Pinned shared methodology Git submodule
reports/               Generated flow summaries and release evidence
work/                  Generated tool databases
```

See the [repository structure](docs/repository-structure.md) for ownership and
source-of-truth rules.

Repositories that intentionally own several related RTL modules should use the
[multi-module repository guide](docs/multi-module-repositories.md). Each module
retains an independent project root, flow policy, regression, and report tree.

## Configuration

The root `Makefile` is a thin consumer of `mosaic-flow/mk/project.mk`. The
project API preserves the ordinary single-module commands and also activates
validated module and parameter-profile manifests when a repository declares
them.
Module identity and paths belong in `config/design.mk`. Flow states and
dependencies belong in `config/flows.mk`. Tool-specific project inputs mirror
the shared hierarchy under `flows/<flow-name>/`.

Do not edit the submodule to customize one module. The complete override model
is documented in [Project configuration](docs/project-configuration.md).

## Creating a module

Start from [Creating a module](docs/creating-a-module.md). At minimum:

1. Rename the example RTL and verification hierarchy.
2. Replace the example datapath, testbench, and PyUVM smoke verification.
3. Update the RTL, property, assertion, coverage, simulation, and formal lists.
4. Define timing, CDC, DFT, low-power, formal, and physical intent.
5. Replace the example coverage, campaign, static-intent, and physical-evidence
   policies.
6. Declare representative parameter profiles and required evidence.
7. Review flow states and dependencies.
8. Replace template documentation with module-specific records.
9. Run native, containerized, physical, and applicable commercial
   qualification.

## Continuous integration

`.github/workflows/rtl-simulation.yml` runs the portable gate using both native
and pinned-container execution. It also qualifies the representative parameter
profiles and runs a dedicated containerized Nangate45 OpenROAD job. It does not
invoke licensed commercial tools.

`ECASLab/mosaic-flow` is public, so CI does not require an additional repository
secret. It checks out the exact submodule revision recorded here rather than a
floating branch.

Manual container build and execution commands are documented under
[initial acceptance](docs/creating-a-module.md#run-initial-acceptance).

## Commercial qualification

Synopsys flows run only in an authorized local environment. Verify the
environment explicitly before starting the aggregate flow:

```sh
make synopsys-check-env
make synopsys-all
```

Commercial licenses, credentials, PDK paths, technology libraries, and site
setup files must not be committed. The template VC Lint, CDC, SpyGlass DFT, and
VC LP adapters require qualification against the locally installed tool release
before they can provide signoff evidence.

## Release policy

A release is acceptable only when every enabled flow has the expected passing
evidence and every disabled flow is justified by project policy. Use the
[release checklist](docs/release-checklist.md) as the final review record and
keep all accepted exceptions in [Reviewed waivers](docs/waivers.md).

The open-source gate covers style, formatting, elaboration, lint, generic
synthesis, formal proof and cover reachability, RTL-to-netlist equivalence,
SystemVerilog simulation, PyUVM, quantitative native HDL coverage, negative and
four-state campaigns, and portable SDC and UPF intent checks. PyUVM functional
coverage remains a separate report and must be reviewed alongside native
coverage. The public Nangate45 job is exploratory implementation evidence.
Technology-mapped signoff, timing, power, CDC, DFT, low-power, and physical
verification use the configured authorized implementation environment.

The module-owned qualification contracts and release-manifest commands are
summarized in [Qualification and release evidence](docs/qualification.md).
