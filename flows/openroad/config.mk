export DESIGN_NAME = mosaic_module
export PLATFORM = $(OPENROAD_PLATFORM)
export VERILOG_FILES = $(REPO_ROOT)/rtl/mosaic_module.sv
export SDC_FILE = $(REPO_ROOT)/flows/openroad/timing.sdc
# RTL-to-netlist equivalence is qualified by the module's EQY flow. Disable the
# optional ORFS Kepler LEC helper so the pinned physical container remains
# portable across GitHub-hosted and local x86_64 runners.
export LEC_CHECK = 0
# Keep the tiny template design large enough for the platform's default PDN
# straps. Production modules must replace these representative dimensions.
export DIE_AREA = 0 0 60 60
export CORE_AREA = 5 5 55 55
