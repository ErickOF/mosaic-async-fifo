# Project flow selection. Shared defaults live in mosaic-flow/config/flows.mk.
FLOW_verible_lint := enabled
FLOW_verible_format := enabled
FLOW_slang_elaboration := enabled
FLOW_verilator_lint := enabled
# Standalone synthesis/equivalence are owner-approved unit-level SKIPs.
# SymbiYosys still uses Yosys internally to prepare its formal models.
FLOW_yosys_synthesis := disabled
FLOW_symbiyosys_formal := enabled
FLOW_eqy_equivalence := disabled
FLOW_verilator_sim := enabled
# Verilator PyUVM uses the same property/assertion/coverage layers as simulation.
FLOW_pyuvm_open_source := enabled
# Quantitative coverage and the dual-clock static-intent adapter remain
# unqualified. Disabled status is NOT release approval. See the release checklist.
FLOW_coverage_qualification := disabled
FLOW_negative_qualification := enabled
FLOW_four_state_qualification := enabled
FLOW_static_intent := disabled
FLOW_openroad := disabled

FLOW_vcs_sim := disabled
FLOW_pyuvm_commercial := disabled
# Mandatory ASIC lint, CDC/RDC, mapped synthesis, STA, power and MTBF are
# NOT_RUN/BLOCKED until site tools, libraries and adapters are qualified.
# These portable enablement flags are not release waivers.
FLOW_vc_lint := disabled
FLOW_vc_cdc := disabled
FLOW_sg_cdc := disabled
FLOW_sg_dft := disabled
FLOW_vc_lp := disabled
FLOW_synopsys_synthesis := disabled
FLOW_synopsys_primetime := disabled
FLOW_synopsys_primepower := disabled

# Project dependency overrides. Dependencies must use canonical flow IDs.
# Retain the synthesis prerequisite if standalone EQY is enabled later.
FLOW_DEPENDENCIES_eqy_equivalence := yosys_synthesis
FLOW_DEPENDENCIES_coverage_qualification := verilator_sim
FLOW_DEPENDENCIES_synopsys_primetime := synopsys_synthesis
FLOW_DEPENDENCIES_synopsys_primepower := vcs_sim synopsys_synthesis
