export DESIGN_TOP := mosaic_module
export TB_TOP := $(DESIGN_TOP)_tb
export FORMAL_TOP := $(DESIGN_TOP)_formal
export DUT_INSTANCE := $(TB_TOP)/dut
export FLOW_CONFIG_ROOT := $(MODULE_ROOT)/flows
export RTL_FILELIST := $(MODULE_ROOT)/filelists/rtl.f
export TB_FILELIST := $(MODULE_ROOT)/filelists/tb.f

# Keep temporal declarations, checking, and coverage independently selectable
# while preserving their required compilation order.
export PROPERTY_FILELIST := $(MODULE_ROOT)/filelists/properties.f
export ASSERTION_FILELIST := $(MODULE_ROOT)/filelists/assertions.f
export COVERAGE_FILELIST := $(MODULE_ROOT)/filelists/coverage.f

# PyUVM drives the synthesizable DUT directly. The shared adapter appends the
# property, assertion, and coverage filelists above.
export PYUVM_FILELIST := $(MODULE_ROOT)/filelists/rtl.f
export PYUVM_TOP := $(DESIGN_TOP)
export PYUVM_TEST_MODULE := test_mosaic_module
export PYUVM_TEST_PATH := $(MODULE_ROOT)/verif/pyuvm
export PYUVM_COVERAGE := enabled
export VERILATOR_WAIVER_FILE := $(FLOW_CONFIG_ROOT)/verilator_lint/waivers.vlt
export VERIBLE_WAIVER_FILE := $(FLOW_CONFIG_ROOT)/verible/waivers.txt
export VERIBLE_RULES_FILE := $(FLOW_CONFIG_ROOT)/verible/rules
export FORMAL_CONFIG := $(FLOW_CONFIG_ROOT)/symbiyosys/formal.sby
export FORMAL_COVER_CONFIG := $(FLOW_CONFIG_ROOT)/symbiyosys/formal_cover.sby
export COVERAGE_QUALIFICATION_POLICY := $(MODULE_ROOT)/config/coverage-policy.json
export COVERAGE_QUALIFICATION_SOURCE := verilator_sim
export QUALIFICATION_CAMPAIGN_MANIFEST := $(MODULE_ROOT)/config/qualification-campaigns.json
export STATIC_INTENT_CONFIG := $(MODULE_ROOT)/config/static-intent.json
export EQUIVALENCE_CONFIG := $(FLOW_CONFIG_ROOT)/eqy/equivalence.eqy
export OPENROAD_CONFIG := $(FLOW_CONFIG_ROOT)/openroad/config.mk
export OPENROAD_CONSTRAINT_FILE := $(FLOW_CONFIG_ROOT)/openroad/timing.sdc
export OPENROAD_EVIDENCE_POLICY := $(FLOW_CONFIG_ROOT)/openroad/evidence-policy.json
export OPENROAD_DESIGN_NAME := $(DESIGN_TOP)
export OPENROAD_FLOW_VARIANT := template_release
export SYNTHESIS_CONSTRAINT_FILE := $(FLOW_CONFIG_ROOT)/synthesis/timing.sdc
export CDC_CONFIG := $(FLOW_CONFIG_ROOT)/cdc/constraints.tcl
export DFT_CONFIG := $(FLOW_CONFIG_ROOT)/sg_dft/constraints.tcl
export UPF_CONFIG := $(FLOW_CONFIG_ROOT)/vc_lp/power.upf
export CONSTRAINT_DIR := $(FLOW_CONFIG_ROOT)/synthesis
export REPORT_DIR := $(MODULE_ROOT)/reports
export WORK_DIR := $(MODULE_ROOT)/work
export OPENROAD_PLATFORM ?= nangate45

# Release evidence defaults to the portable, technology-independent context.
export RELEASE_MODULE_NAME := mosaic_module
export RELEASE_TECHNOLOGY := technology-independent

# Override in CI or a site-local, untracked environment file.
export TECH_SETUP_TCL ?=
export TARGET_LIBRARY ?=
export LINK_LIBRARY ?=
export OPERATING_CONDITION ?=
export ACTIVITY_FILE ?=$(WORK_DIR)/vcs_sim/$(DESIGN_TOP).saif
