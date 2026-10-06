# Release checklist

Use this checklist for every supported module configuration. A passing portable
gate alone is not sufficient ASIC release evidence.

## Identity and scope

- [ ] The module name, repository name, top-level names, and Docker labels agree.
- [ ] Supported parameter values and configurations are listed.
- [ ] The parameter-profile manifest validates and its matrix is deterministic.
- [ ] Unsupported modes and external assumptions are explicit.
- [ ] The `mosaic-flow` gitlink points to a qualified published revision.
- [ ] The resolved flow policy has been captured with `make flow-config-check`.

## Interface and architecture

- [ ] [Interface specification](interface.md) matches the RTL.
- [ ] Every clock and reset has documented polarity and timing behavior.
- [ ] Latency, throughput, handshakes, backpressure, and errors are documented.
- [ ] Disabled, reset, test, and low-power behavior are documented.
- [ ] Integration assumptions and protocol dependencies are reviewed.

## RTL quality

- [ ] Verible style lint records `PASS` or an approved policy `SKIP`.
- [ ] Verible formatting records the expected status.
- [ ] Slang elaboration records the expected status.
- [ ] Verilator lint records the expected status.
- [ ] Yosys generic synthesis records the expected status.
- [ ] No unresolved warning is hidden outside the reviewed waiver files.

## Functional verification

- [ ] The [verification plan](verification-plan.md) maps every requirement to a
  test, assertion, formal property, or reviewed combination.
- [ ] All supported parameter configurations have evidence.
- [ ] Positive, negative, reset, error, and boundary tests pass.
- [ ] Enabled SystemVerilog and PyUVM regressions pass.
- [ ] Normal simulation, PyUVM, and formal consume the reviewed shared property,
  assertion, and coverage sources without duplicated checking logic.
- [ ] Assertions run in simulation and PyUVM and reach meaningful antecedents.
- [ ] Formal assumptions are reviewed for overconstraint.
- [ ] Formal proofs pass at justified depth or by complete proof.
- [ ] Formal cover mode demonstrates required scenario reachability.
- [ ] RTL-to-Yosys-netlist equivalence passes.
- [ ] Native HDL and Python functional coverage are reviewed independently.
- [ ] Functional and code coverage goals are met or deviations are approved.
- [ ] The versioned coverage policy passes for line, branch, toggle, user,
  required named coverpoints, and formal reachability.
- [ ] A deficient-coverage control proves that threshold enforcement fails
  closed.
- [ ] Negative campaigns include successful controls and detect assertion,
  elaboration, equivalence, and mutation failures as applicable.
- [ ] Four-state cases use a pinned four-state simulator and prove both X/Z
  stimulus reachability and monitor detection.
- [ ] Escaped-fault, unavailable-tool, and disabled-monitor controls are rejected
  with the expected classifications.
- [ ] VCS or Xcelium PyUVM evidence passes when commercial PyUVM belongs to the
  module's release scope.

## Constraints and static checks

- [ ] Synthesis and physical clocks agree unless a difference is documented.
- [ ] Input, output, uncertainty, exception, and asynchronous paths are reviewed.
- [ ] CDC and reset-domain intent covers every domain and crossing.
- [ ] CDC violations are resolved or narrowly waived.
- [ ] DFT test modes, controllability, observability, and exclusions are reviewed.
- [ ] UPF power domains, states, isolation, retention, and supplies match the
  architecture.
- [ ] The versioned static-intent policy names the applicable timing kind and
  required or forbidden power strategies.
- [ ] Portable SDC and UPF validation passes its positive policy and rejects
  missing, duplicate, conflicting, broad, incomplete, forbidden, and unsupported
  controls.
- [ ] Reviewers understand that portable static intent does not replace STA,
  CDC, IEEE 1801, or commercial low-power signoff.
- [ ] VC Lint, selected CDC, SpyGlass DFT, and VC LP adapters are qualified for
  the installed release and all expected statuses pass.

## Synthesis, timing, and power

- [ ] Design Compiler completes with the intended libraries and operating corner.
- [ ] Area, QoR, and synthesis timing reports are reviewed.
- [ ] PrimeTime reports no release-blocking setup or hold violation.
- [ ] Unconstrained paths and constraint coverage are reviewed.
- [ ] PrimePower uses representative SAIF activity.
- [ ] SAIF hierarchy and activity annotation coverage are reviewed.
- [ ] Power, performance, and area results meet the module targets.
- [ ] PDK, library, tool, constraint, and corner identities are recorded.

## Physical implementation

- [ ] OpenROAD or the selected implementation flow uses the intended platform.
- [ ] Floorplan, utilization, aspect ratio, and margins are justified.
- [ ] Placement, clocking, routing, timing, DRC, and LVS evidence is retained when
  physical implementation belongs to this module's release scope.
- [ ] Preliminary open-source physical results are not labeled as commercial
  signoff evidence.
- [ ] The physical-evidence policy requires nonempty DEF, GDS, ODB, SDC, and
  netlist artifacts plus reviewed metric thresholds.
- [ ] OpenROAD evidence records an immutable image digest or exact local ORFS
  revision, platform, variant, input hashes, artifact hashes, and metrics.
- [ ] Containerized physical output is owned by the invoking user and isolated
  by selected module and parameter profile.

## Waivers

- [ ] Every accepted waiver is recorded in [Reviewed waivers](waivers.md).
- [ ] Each waiver identifies the tool, rule, object, justification, owner,
  reviewer, date, and removal condition.
- [ ] Generated waiver drafts are not treated as approved policy.
- [ ] Expired waivers have been removed or re-reviewed.

## Reproducibility and evidence

- [ ] Native `make clean open-source` passes.
- [ ] Every representative profile passes with bounded concurrency and isolated
  reports, work products, formal artifacts, and netlists.
- [ ] PyUVM status, JUnit, native coverage, functional coverage, and version
  evidence pass `./.github/scripts/check-pyuvm-evidence.sh` when enabled.
- [ ] The pinned Docker image builds and its portable gate passes.
- [ ] GitHub Actions passes using the recorded gitlink revision.
- [ ] Commercial gates pass in the authorized local or self-hosted environment
  when they belong to release scope. Otherwise their policy is an approved
  `SKIP`.
- [ ] Reports identify module revision, methodology revision, tool versions,
  constraints, technology, date, and configuration.
- [ ] CI or release storage retains logs and required databases.
- [ ] No generated work database, credential, license, or proprietary library is
  committed to Git.
- [ ] Native, container, and applicable physical release manifests validate with
  explicit module and methodology revisions.
- [ ] Release manifests hash declared RTL, verification layers, constraints,
  policies, waivers, and configuration inputs and index every enabled compact
  evidence summary.
- [ ] No dirty-tree override is present in publishable release evidence.
- [ ] The source tree and `mosaic-flow` submodule remain clean after validation.

## Final commands

```sh
git submodule status
make flow-config-check
make clean open-source
./.github/scripts/check-qualification-controls.sh
./.github/scripts/check-profile-evidence.sh
make FLOW_openroad=enabled OPENROAD_EXECUTION_MODE=container open-physical
make release-manifest release-manifest-validate
make synopsys-check-env
make synopsys-all CDC_TOOL=vc
```

Pass full revision IDs and a distinct `RELEASE_EXECUTION_CONTEXT` when creating
publishable manifests. Run the Synopsys commands only in the licensed
environment after all release-specific adapters are qualified and when those
flows belong to release scope. Select `CDC_TOOL=sg` instead when that engine is
the approved project policy.

## Approval record

Record the release identifier, reviewed Git revisions, supported configuration,
evidence location, approvers, and approval date in the project's normal release
system. Do not infer approval only from the presence of `PASS` files in a local
working tree.
