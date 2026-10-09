# Release checklist

Use this checklist for every supported module configuration. A passing portable
gate alone is not sufficient ASIC release evidence.

Status: initial implementation, no release approval. MC20261005V1 is the selected
common baseline. Mandatory contracts, CDC/RDC, mapped preservation, MTBF,
PrimeTime, PrimePower, coverage closure, and site qualification remain open.

## Identity and scope

- [x] The module name, repository name, top-level names, and Docker labels agree.
  Comment: `async_fifo`, `async_fifo_tb`, `async_fifo_formal`, and the module Docker identity agree.
- [x] Supported parameter values and configurations are listed.
  Comment: docs/release-scope.md lists five exact proposed production tuples, including resolved thresholds. Scope approval is pending. This is not a legal-value Cartesian product, and no ASIC parameter envelope is released.
- [x] The parameter-profile manifest validates and its matrix is deterministic.
  Comment: The manifest validates. Repeated `make profile-matrix` output is identical.
- [x] Unsupported modes and external assumptions are explicit.
  Comment: Power loss, scan bypass, external reset coordination, and contract gaps are explicit.
- [ ] The `mosaic-flow` gitlink points to a qualified published revision.
- [x] The resolved flow policy has been captured with `make flow-config-check`.
  Comment: Per-profile `reports/<profile>/flow-policy.log` and `parameter-profile.json` record applicable portable gates.
  Comment: After the standalone synthesis/equivalence policy change, resolved configuration validates for all five portable and nine formal-only targets. Fresh native portable evidence in reports/unit-flow-policy records both disabled flows as SKIP in every profile. No formal target was removed.

## Interface and architecture

- [x] [Interface specification](interface.md) matches the RTL.
  Comment: Parameters, all 18 ports, flags, occupancy, prefetch, and reset behavior are documented.
- [x] Every clock and reset has documented polarity and timing behavior.
  Comment: Independent rising-edge clocks, asynchronous assertion, external synchronized release.
- [x] Latency, throughput, handshakes, backpressure, and errors are documented.
  Comment: Includes variable cross-domain visibility and no-bubble locally visible read bursts.
- [x] Disabled, reset, test, and low-power behavior are documented.
  Comment: Always-on profile only. One-sided reset cancels the epoch and requires coordinated recovery.
- [ ] Integration assumptions and protocol dependencies are reviewed.
  Comment: BLOCKED: MC20261005V1 is pinned for RTL primitives, not protocols. Proposed FIFO-owned AFIFO-CHANNEL-V1 is drafted from the issue's behavior. Publisher/scope approval, replacement of the issue's mosaic-contracts references and immutable publication remain pending. Integration reset/endpoint and formal overconstraint review remain separate open obligations.

## RTL quality

- [x] Verible style lint records `PASS` or an approved policy `SKIP`.
  Comment: PASS for all five native profiles. Candidate naming policy still needs maintainer approval.
- [x] Verible formatting records the expected status.
  Comment: PASS using four-space indentation and wrap indentation.
- [x] Slang elaboration records the expected status.
  Comment: PASS for all five native profiles.
- [x] Verilator lint records the expected status.
  Comment: PASS for all five native profiles.
- [x] Yosys generic synthesis records the expected status.
  Comment: Owner-approved policy SKIP at the FIFO unit level. The flow is disabled and excluded from all five portable profiles. Previous native/container PASS evidence is historical. Formal still uses Yosys for model preparation. ASIC storage/synchronizer mapping remains unqualified.
- [ ] No unresolved warning is hidden outside the reviewed waiver files.
  Comment: Candidate STYLE-001, TB-001 and covergroup-scaffolding COV-001 are documented. Maintainer waiver review is pending. COV-001 is declaration-local, not a coverage-bin exclusion. Yosys array-to-register messages remain visible.

## Functional verification

- [ ] The [verification plan](verification-plan.md) maps every requirement to a
  test, assertion, formal property, or reviewed combination.
  Comment: FIFO-01 through FIFO-13 and all nineteen required assertion items are mapped in the verification plan and assertion inventory. Behavioral storage, output, prediction, initialization and shutdown checks are implemented. Structural crossing, full fault/vacuity and release requirement closure remain pending.
- [ ] All supported parameter configurations have evidence.
  Comment: Five exact proposed production tuples pass portable regressions. Proposed scope approval and all applicable release gates remain pending. Formal-only and four-state/fault fixture tuples do not expand the production envelope or prove its wider profiles.
- [ ] Positive, negative, reset, error, and boundary tests pass.
  Comment: Implemented scenarios and 24 negative-campaign cases pass. Both stopped-startup directions, skewed assertion orders, five measured equal-nominal-rate drift ranges, and all six write/read/both-clock-stop versus reset-order cases pass in SV and PyUVM. Twelve fixed-minimum RTL faults cover pointer/domain-up stage zero and final stages, full/empty flags and storage write/hold. Arbitrary reset pulse/occupancy/phase crosses, other fault polarities/transients/stages/addresses and wider fault parameters remain open.
- [x] Enabled SystemVerilog and PyUVM regressions pass.
  Comment: Fresh SystemVerilog and Verilator PyUVM sweeps pass all five native and container profiles with the expanded shared checker and reset/phase scenario matrix. Each stopped-clock reset case must cancel old records, block premature startup and deliver checked fresh records after coordinated recovery. PyUVM is enabled by default in the portable gate and GitHub Actions.
- [x] Normal simulation, PyUVM, and formal consume the reviewed shared property,
  assertion, and coverage sources without duplicated checking logic.
  Comment: All three consume the same prediction/reset/Gray/control predicates, behavioral checker and separate HDL coverage. Simulation/PyUVM bind through a passive array-packing adapter. Formal-only observation wiring connects actual storage, not a duplicate reference. Icarus runs only the shared known-control/final-synchronizer immediate monitors, not concurrent SVA. Two-state formal does not establish unknown-value detection.
- [ ] Assertions run in simulation and PyUVM and reach meaningful antecedents.
  Comment: Expanded SVA passes in both environments. Four observation-fault controls hit storage_hold, output_idle_hold, write_init_prerequisites and write_async_reset, the last with the write clock stopped. Actual flag/memory faults additionally hit full/empty prediction and storage_write/storage_hold. The automated negative-campaign PyUVM fault hits input_hold after a passing full PyUVM control. Runtime formal adds domain-up falling, peer-down and recovery witnesses; those are selected reachability checks, not systematic per-assertion antecedent/vacuity closure, which remains open.
- [ ] Formal assumptions are reviewed for overconstraint.
  Comment: Source hold, symbolic runtime reset, coordinated epoch rearming, reset release on local falling edges and reset visibility through SYNC_STAGES + VARIABLE_CAPTURE + 1 peer edges are documented in docs/formal-model.md. Four crossings independently permit one extra coherent first-stage capture edge. No fairness or DUT-output assumption is added. Integration-owner review and physical CDC/RDC/reset assumptions remain open.
- [x] Formal proofs pass at justified depth or by complete proof.
  Comment: Scoped closure: complete ABC PDR safety proofs pass natively and in the container for all nine exact config/formal-profiles.json targets, including depth four, two-bit threshold endpoints, three stages, runtime cancellation/shutdown and bounded variable capture. The original minimum startup-only proof also passes natively. Existing shared storage, output, prediction and initialization checks remain active. This does not prove 32/64/128-bit portable profiles, every legal parameter tuple, arbitrary propagation delay, liveness or physical CDC. Assumption review and the supported-configuration gate remain open.
- [x] Formal cover mode demonstrates required scenario reachability.
  Comment: Scoped closure: every selected formal target passes cover mode in both environments within the 128-step bound, with latest witnesses at steps 41-53. Runtime covers include empty/partial/full cancellation, stalled head, held clocks, both peer-shutdown directions and repeated fresh-epoch recovery. Every delayed profile also reaches eight independent stale/forced-capture witnesses. Complete proofs check the wrap-phase invariants; no native bin is waived. Structured per-target statuses, source hashes and required traces are checked. Real-time crosses, wider profile coverage and systematic assertion non-vacuity remain separate open gates.
- [x] RTL-to-Yosys-netlist equivalence passes.
  Comment: Closed by owner-approved policy SKIP, not by a current equivalence PASS. Standalone EQY is disabled and excluded from all five portable profiles. Collateral and the synthesis prerequisite are retained. Previous native/container and development before/after results remain historical in `docs/portable-validation.md`. Technology-mapped integration qualification is not waived.
- [x] Native HDL and Python functional coverage are reviewed independently.
  Comment: Twenty native HDL cross families implement all twelve required coverage items. The collector retains each bin, including zeros, independently of Python scenario JSON and the original five HDL points. Missing/duplicate identities fail integrity; VALID does not imply quantitative closure. See docs/coverage-model.md for native padding, sampling semantics and formal scope. No databases or profiles are merged.
- [ ] Functional and code coverage goals are met or deviations are approved.
  Comment: NOT_RUN: quantitative closure, uncovered-bin stimulus and legal-bin/profile-specific exclusion review are pending. Native zero-hit bins are retained, not waived. Assertion antecedent/vacuity review remains open independently of cross implementation.
- [ ] The versioned coverage policy passes for line, branch, toggle, user,
  required named coverpoints, and formal reachability.
  Comment: Draft module coverpoint policy exists, but MF20260910V1 does not parse the new native covergroup metric. Its five-counter policy cannot close the crosses. Shared-parser support and policy review are required before enabling quantitative qualification, which remains a mandatory release gate.
- [ ] A deficient-coverage control proves that threshold enforcement fails
  closed.
  Comment: NOT_RUN: module-specific deficient-threshold control remains open. Eight isolated cross-artifact tests check missing bins, five-counter-only evidence, duplicates, wrong depth shape, SKIP, inflated cross sampling and zero-hit retention. State-cross totals must match ten independent HDL event counters. Those are integrity controls, not quantitative threshold enforcement.
- [ ] Negative campaigns include successful controls and detect assertion,
  parameter rejection, elaboration, equivalence, and mutation failures as applicable.
  Comment: All 24 declarative negative cases pass in minimum and nominal, natively and in the container. Actual RTL faults run at fixed minimum parameters, distinct from the four observation-only controls. PyUVM input_hold detection is automated, with untouched raw adapter FAIL archived as raw-status.txt and a separately attributable campaign PASS. Missing tools, wrong diagnostics, escaped faults and watchdogs cannot satisfy the negative expectation. Inequivalent-netlist qualification is deferred with standalone EQY. Wider mutation and physical fault qualification remain pending.
  Comment: The seven Icarus invalid-parameter cases require successful compilation and a named fatal at time zero with a nonzero run exit. They are classified as expected_assertion_failure, not compiler elaboration failures. The issue's before-execution wording amendment is proposed in docs/release-scope.md.
- [x] Four-state cases use a pinned four-state simulator and prove both X/Z
  stimulus reachability and monitor detection.
  Comment: Shared Icarus campaigns pass sixteen X/Z injections and sixteen paired disabled-monitor arrival controls, including both final Gray buses and domain-up bits. The fixed 8-bit/depth-four payload control delivers 24 queued records across six bursts/wraps, with all eight all/mixed/sparse X/Z patterns checked three times while public flags/levels remain known. This is not full four-state SVA or metastability evidence.
- [x] Escaped-fault, unavailable-tool, and disabled-monitor controls are rejected
  with the expected classifications.
  Comment: Isolated native and container counterfactual manifest copies each retain a passing control and reject a no-fault negative as escaped_fault, a wrong named diagnostic as unexpected_failure, an unavailable binary as infrastructure_failure and an enabled-case compilation with its monitor disabled as escaped_fault. Positive campaign evidence is not overwritten. The development fixture locations and scope are recorded in docs/portable-validation.md. Broader fault/vacuity closure remains open.
- [ ] VCS or Xcelium PyUVM evidence passes when commercial PyUVM belongs to the
  module's release scope.
  Comment: NOT_RUN: commercial PyUVM and commercial simulation still require site qualification. Portable Verilator PyUVM evidence is separate.

## Constraints and static checks

- [ ] Synthesis and physical clocks agree unless a difference is documented.
  Comment: Draft physical SDC sources the draft synthesis SDC. Both deliberately block qualification until mapped Gray endpoints and budgets are available.
- [ ] Input, output, uncertainty, exception, and asynchronous paths are reviewed.
  Comment: BLOCKED: generic interface budgets are drafts. Gray delay/skew, payload storage, and reset recovery/removal require site review.
- [ ] CDC and reset-domain intent covers every domain and crossing.
  Comment: Crossing inventory is present. Qualified CDC/RDC constraints, structural reports, variable-propagation reasoning and tool recognition are pending.
- [ ] CDC violations are resolved or narrowly waived.
  Comment: NOT_RUN/BLOCKED: no qualified CDC or RDC execution evidence. No CDC waiver is approved.
- [ ] DFT test modes, controllability, observability, and exclusions are reviewed.
  Comment: BLOCKED: product scan/reset/test-clock profile has not been selected.
- [ ] UPF power domains, states, isolation, retention, and supplies match the
  architecture.
  Comment: Always-on, same-voltage draft UPF is present. Power strategy review and any product voltage/switchable-domain scope remain open.
- [ ] The versioned static-intent policy names the applicable timing kind and
  required or forbidden power strategies.
  Comment: Draft policy identifies both clocks and always-on intent. Complete Gray-bus and RDC qualification is outside the current portable parser.
- [ ] Portable SDC and UPF validation passes its positive policy and rejects
  missing, duplicate, conflicting, broad, incomplete, forbidden, and unsupported
  controls.
  Comment: NOT_RUN: dual-clock draft SDC fails closed instead of inheriting the template's one-clock PASS.
- [x] Reviewers understand that portable static intent does not replace STA,
  CDC, IEEE 1801, or commercial low-power signoff.
  Comment: Portable checks are explicitly distinguished from ASIC CDC/RDC, STA, low-power and physical evidence.
- [ ] VC Lint, selected CDC, SpyGlass DFT, and VC LP adapters are qualified for
  the installed release and all expected statuses pass.
  Comment: Mandatory VC Lint and selected CDC/RDC are NOT_RUN/BLOCKED. DFT/VC LP applicability needs product review. Site adapters are unqualified.

## Synthesis, timing, and power

- [ ] Design Compiler completes with the intended libraries and operating corner.
  Comment: NOT_RUN/BLOCKED: technology, libraries, corners and synchronizer/storage mapping are not selected.
- [ ] Area, QoR, and synthesis timing reports are reviewed.
  Comment: Historical generic Yosys reports are available; standalone synthesis is now a unit-level policy SKIP. ASIC area, timing, stage preservation and storage suitability remain open.
- [ ] PrimeTime reports no release-blocking setup or hold violation.
  Comment: NOT_RUN/BLOCKED: mapped timing and Gray skew/delay reports are mandatory, not waived.
- [ ] Unconstrained paths and constraint coverage are reviewed.
  Comment: NOT_RUN: no mapped path or recovery/removal review.
- [ ] PrimePower uses representative SAIF activity.
  Comment: NOT_RUN/BLOCKED: representative licensed activity and power characterization remain mandatory.
- [ ] SAIF hierarchy and activity annotation coverage are reviewed.
  Comment: NOT_RUN: no licensed activity annotation evidence.
- [ ] Power, performance, and area results meet the module targets.
  Comment: BLOCKED: ASIC targets and characterized results are unavailable. MTBF per crossing is also mandatory and missing.
- [ ] PDK, library, tool, constraint, and corner identities are recorded.
  Comment: Portable tools and method revision are pinned. ASIC PDK, library, PVT, MTBF constants, and operating rates are unavailable.

## Physical implementation

- [ ] OpenROAD or the selected implementation flow uses the intended platform.
  Comment: NOT_RUN/BLOCKED: exploratory configuration exists but draft Gray/reset constraints deliberately prevent physical qualification.
- [ ] Floorplan, utilization, aspect ratio, and margins are justified.
  Comment: Exploratory dimensions are not approved product floorplan evidence.
- [ ] Placement, clocking, routing, timing, DRC, and LVS evidence is retained when
  physical implementation belongs to this module's release scope.
  Comment: NOT_RUN: product physical scope, synchronizer placement and routing budgets are not qualified.
- [x] Preliminary open-source physical results are not labeled as commercial
  signoff evidence.
  Comment: No physical qualification result is claimed.
- [ ] The physical-evidence policy requires nonempty DEF, GDS, ODB, SDC, and
  netlist artifacts plus reviewed metric thresholds.
  Comment: Physical adapter is disabled. Template metric thresholds require product review.
- [ ] OpenROAD evidence records an immutable image digest or exact local ORFS
  revision, platform, variant, input hashes, artifact hashes, and metrics.
  Comment: NOT_RUN: no FIFO physical run has been performed.
- [ ] Containerized physical output is owned by the invoking user and isolated
  by selected module and parameter profile.
  Comment: NOT_RUN: physical execution is not enabled.

## Waivers

- [ ] Every accepted waiver is recorded in [Reviewed waivers](waivers.md).
  Comment: No accepted functional/signoff waiver. Two development diagnostic policies await maintainer review.
- [ ] Each waiver identifies the tool, rule, object, justification, owner,
  reviewer, date, and removal condition.
  Comment: Candidate records include metadata and removal conditions but do not fabricate reviewer approval.
- [ ] Generated waiver drafts are not treated as approved policy.
  Comment: Candidates are explicitly pending. Final waiver approval remains open.
- [ ] Expired waivers have been removed or re-reviewed.
  Comment: No final approved waiver register exists yet.

## Reproducibility and evidence

- [x] Native `make clean open-source` passes.
  Comment: A root `make clean` followed by `make all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-source` passes after common primitive reuse, including a freshly regenerated nominal profile.
  Comment: A fresh five-profile native sweep also passes with the current standalone synthesis/equivalence SKIP policy and isolated reports/unit-flow-policy and work/unit-flow-policy roots. All enabled flows and simulation evidence checks pass. See docs/portable-validation.md for commands and scope.
- [x] Every representative profile passes with bounded concurrency and isolated
  reports, work products, formal artifacts, and netlists.
  Comment: All five fresh native and container portable sweeps pass with PROFILE_JOBS=2 after the simulation-gap additions. Native and container transaction/scenario counts agree. Container evidence uses separate reports/container and work/container roots. Focused assertion controls use additional isolated assertion_controls roots and their complete baseline also includes the new scenarios.
- [x] PyUVM status, JUnit, native coverage, functional coverage, and version
  evidence pass `./.github/scripts/check-pyuvm-evidence.sh` when enabled.
  Comment: The FIFO-aware script passes all five native and container profiles. It requires the actual FIFO test, shared HDL source coverage, every reset/clock-stop/phase hit, completed balanced drift intervals, matching parameters, and balanced totals. Isolated deficient-evidence controls reject missing startup, assertion-order, phase-range, or both-stopped reset hits and an extra unbalanced slow interval. Earlier SKIP/missing-coverage controls remain documented.
- [x] The pinned Docker image builds and its portable gate passes.
  Comment: Image sha256:2c542500db1bc36b54fdfa8a754ace0cc22695c626940e1a9e1bd9a160e75338 builds and passes all five profiles.
- [ ] GitHub Actions passes using the recorded gitlink revision.
  Comment: Revision 6fbba188b22ebce249196234f33f61a767de3d85 passes hosted push run 37730251982. PR run 37730334702 passes all five native profiles, all nine native formal jobs and the portable container sweep, but its delayed_reset_depth4 container proof times out at the original 600-second limit. The revised 1200-second proof budget, serialized container formal sweep and standalone synthesis/equivalence SKIP policy still require hosted confirmation, so this item remains open. See docs/portable-validation.md for the separate run outcomes. No timeout is waived or converted to PASS.
- [ ] Commercial gates pass in the authorized local or self-hosted environment
  when they belong to release scope. Otherwise their policy is an approved
  `SKIP`.
  Comment: NOT_RUN/BLOCKED: mandatory commercial and reliability gates are not approved SKIP.
- [ ] Reports identify module revision, methodology revision, tool versions,
  constraints, technology, date, and configuration.
  Comment: Per-profile tool logs and parameter identity are retained. Immutable reviewed source revision and ASIC context are pending.
- [ ] CI or release storage retains logs and required databases.
  Comment: Workflow uploads reports for native profiles and container execution. Hosted retention has not been exercised.
- [x] No generated work database, credential, license, or proprietary library is
  committed to Git.
  Comment: Generated data remains ignored. No proprietary technology or credentials have been added.
- [ ] Native, container, and applicable physical release manifests validate with
  explicit module and methodology revisions.
  Comment: BLOCKED: no qualified release exists. Supplemental mandatory gates prevent a portable SKIP from authorizing release.
- [ ] Release manifests hash declared RTL, verification layers, constraints,
  policies, waivers, and configuration inputs and index every enabled compact
  evidence summary.
  Comment: Shared collector is configured. Complete qualified evidence and a committed source revision are pending.
- [ ] No dirty-tree override is present in publishable release evidence.
  Comment: No publishable release manifest is produced. A local fail-closed diagnostic may use a dirty-tree override only to test rejection.
- [ ] The source tree and `mosaic-flow` submodule remain clean after validation.
  Comment: Both `mosaic-flow` and `submodules/mosaic-common` are unchanged and clean. Module implementation is intentionally uncommitted.

## Final commands

```sh
git submodule status
make PROFILE=nominal flow-config-check
make PROFILE=nominal clean open-source
./.github/scripts/check-qualification-controls.sh
bash .github/scripts/check-assertion-controls.sh
./.github/scripts/check-profile-evidence.sh
make all-profiles PROFILE_JOBS=2 PROFILE_TARGET=open-source
# After qualified constraints, product scope and licensed evidence are available:
make PROFILE=nominal release-manifest release-manifest-validate
make PROFILE=nominal synopsys-check-env
make PROFILE=nominal synopsys-all CDC_TOOL=vc
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
