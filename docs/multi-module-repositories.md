# Multi-module repositories

## Scope

The base template remains one independently releasable RTL module. A repository
that owns several closely related modules can use the same root hierarchy and
one pinned `mosaic-flow` checkout while qualifying each selected top
independently.

Use this mode when modules share ownership, release cadence, and a meaningful
common purpose, such as a library of small primitive blocks. Keep independently
evolving specialized units in separate repositories when they need their own
release schedule, technology requirements, access policy, or verification
environment.

Every selected module retains its own design profile, flow policy, parameter
profiles, reports, work products, constraints, waivers, and release evidence.
Do not combine unrelated tops into one configuration merely to shorten CI.

## Project API

The repository keeps one thin root Makefile:

```make
SHELL := /usr/bin/env bash

export MODULE_ROOT := $(CURDIR)
export FLOW_ROOT ?= $(abspath $(MODULE_ROOT)/mosaic-flow)

include $(FLOW_ROOT)/mk/project.mk
```

`project.mk` preserves the simple single-module path when no manifest exists.
When `config/modules.json` exists, normal flow targets require a selected
`MODULE` and load its matching design and flow configuration.

## Repository hierarchy

Keep shared source categories at the root. Use top-qualified file names only
where modules need different inputs:

```text
rtl-library/
|-- config/
|   |-- modules.json
|   |-- modules/
|   |   |-- counter.mk
|   |   |-- counter-flows.mk
|   |   |-- fifo.mk
|   |   `-- fifo-flows.mk
|   `-- parameter-profiles/
|       |-- counter.json
|       `-- fifo.json
|-- docs/
|   |-- counter/
|   `-- fifo/
|-- filelists/
|   |-- counter.rtl.f
|   |-- counter.tb.f
|   |-- fifo.rtl.f
|   `-- fifo.tb.f
|-- flows/
|   |-- synthesis/
|   |   |-- counter.timing.sdc
|   |   `-- fifo.timing.sdc
|   `-- symbiyosys/
|       |-- counter.formal.sby
|       `-- fifo.formal.sby
|-- rtl/
|-- verif/
|-- mosaic-flow/
|-- Makefile
`-- README.md
```

The standard resolver functions search a top-qualified input first and then the
shared fallback:

```text
filelists/<DESIGN_TOP>.<filename>
filelists/<filename>

flows/<flow>/<DESIGN_TOP>.<filename>
flows/<flow>/<filename>
```

This supports a shared `rtl.f`, `timing.sdc`, or waiver file when the content is
genuinely common. A module-specific file wins when present. Do not duplicate a
shared file only to satisfy the naming pattern.

## Module manifest

`config/modules.json` is the versioned registry. The `mosaic-modules-v1` schema
requires a nonempty `include` array and unique lowercase names:

```json
{
  "schema": "mosaic-modules-v1",
  "include": [
    {"name": "counter", "artifact_suffix": "native"},
    {"name": "fifo", "artifact_suffix": "native"}
  ]
}
```

For every entry, the validator requires:

```text
config/modules/<name>.mk
config/modules/<name>-flows.mk
```

Additional fields are retained in the generated CI matrix. Names must begin
with a letter and contain only lowercase letters, digits, and underscores.
Unknown selections, malformed JSON, duplicates, and missing profile files fail
before a tool starts.

The design profile exports the same variables as `config/design.mk`. Use shared
resolver functions for inputs that support top-qualified fallback:

```make
export DESIGN_TOP := counter
export TB_TOP := $(DESIGN_TOP)_tb
export FORMAL_TOP := $(DESIGN_TOP)_formal
export DUT_INSTANCE := $(TB_TOP)/dut

export RTL_FILELIST := $(call mosaic_resolve_filelist,rtl.f)
export TB_FILELIST := $(call mosaic_resolve_filelist,tb.f)
export FORMAL_CONFIG := \
  $(call mosaic_resolve_flow_config,symbiyosys,formal.sby)
```

The matching `<name>-flows.mk` declares that module's complete `FLOW_<id>`
policy and dependency overrides. Standard `REPORT_DIR` and `WORK_DIR` values
are already module-qualified and normally need no override.

## Selection and matrices

Validate and inspect the registry before running tools:

```sh
make module-manifest-check
make module-list
make module-matrix
make module-profile-matrix
```

Run one selected module with the normal API:

```sh
make MODULE=counter flow-config-check
make MODULE=counter clean open-source
```

Run every module with bounded concurrency:

```sh
make all-modules
make all-modules TARGET=open-formal MODULE_JOBS=4
```

`MODULE_JOBS=0` uses all available processors. The aggregate waits for every
child, preserves completed evidence, and returns nonzero if any module fails or
lacks required status.

Each selected module defaults to:

```text
reports/<module>/<flow-id>/
work/<module>/<flow-id>/
```

If `config/parameter-profiles/<module>.json` exists, the profile name is inserted
before the flow ID. `module-profile-matrix` combines every registered module
with its own profiles, while a module without a profile manifest contributes a
single `default` entry:

```text
reports/<module>/<profile>/<flow-id>/
work/<module>/<profile>/<flow-id>/
```

`make MODULE=<name> clean` removes only that module's generated state. A root
`make clean` without selection removes the complete project report and work
trees.

## GitHub Actions matrix

Generate the matrix through the validated methodology API rather than parsing
the JSON directly:

```yaml
jobs:
  qualification-matrix:
    runs-on: ubuntu-24.04
    outputs:
      matrix: ${{ steps.matrix.outputs.value }}
      flow_revision: ${{ steps.flow.outputs.revision }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - name: Read pinned mosaic-flow revision
        id: flow
        run: |
          revision="$(git ls-files --stage mosaic-flow |
            awk '$1 == "160000" {print $2}')"
          test "${#revision}" -eq 40
          echo "revision=${revision}" >> "${GITHUB_OUTPUT}"
      - uses: actions/checkout@v7
        with:
          repository: ECASLab/mosaic-flow
          ref: ${{ steps.flow.outputs.revision }}
          path: mosaic-flow
          persist-credentials: false
      - name: Generate module and profile matrix
        id: matrix
        run: echo "value=$(make module-profile-matrix)" >> "${GITHUB_OUTPUT}"

  rtl-checks:
    name: ${{ matrix.job_name }} / native
    needs: qualification-matrix
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.qualification-matrix.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: actions/checkout@v7
        with:
          repository: ECASLab/mosaic-flow
          ref: ${{ needs.qualification-matrix.outputs.flow_revision }}
          path: mosaic-flow
          persist-credentials: false
      - name: Run selected qualification
        run: |
          make MODULE="${{ matrix.module }}" \
            PROFILE="${{ matrix.profile }}" \
            clean open-source
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: ${{ matrix.job_name }}-reports
          path: reports/${{ matrix.module }}/
          if-no-files-found: error
```

Use the same validated matrix for native and pinned-container jobs. Verify the
exact methodology gitlink in every child. Qualify cache scopes, image tags,
artifact names, report paths, and diagnostics by module and profile. Run
containers as the invoking UID and GID and verify output ownership.

`fail-fast: false` lets every module report its result. The matrix job still
fails when any child fails, so integration jobs with `needs: rtl-checks` cannot
start prematurely.

## Verification and integration

Every module job independently runs its enabled style, elaboration, lint,
synthesis, formal, equivalence, simulation, PyUVM, coverage, campaign, and
static-intent flows. Its source lists must include any packages or instantiated
dependencies needed for a clean build. A unit job must not consume another
module job's generated output.

An integration target owns its own top, file lists, assertions, constraints,
waivers, and reports. Run it only after all required unit qualifications pass.
Unit waivers do not automatically authorize an integration-level violation.

Commercial flows remain module-selected and run only in the authorized
environment. Physical implementation may be selected per module or profile.
Public Nangate45 results remain exploratory evidence.

## Release requirements

A multi-module release requires:

- A valid deterministic registry and combined module-profile matrix
- Every selected unit flow and parameter profile to complete
- Separate reports, work products, release manifests, and waiver records
- Every required integration target to pass after unit checks
- The same module revision and methodology gitlink in every job
- Documented compatibility between modules released together
- No output collision during bounded concurrent execution

Do not infer repository success from one passing module. The aggregate matrix
and required integration jobs define repository-level acceptance.
