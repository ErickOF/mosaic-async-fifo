# Exploratory configuration only. The draft SDC blocks physical qualification.
export DESIGN_NAME = async_fifo
export PLATFORM = $(OPENROAD_PLATFORM)
export VERILOG_FILES = $(MODULE_ROOT)/submodules/mosaic-common/rtl/dff.sv \
    $(MODULE_ROOT)/submodules/mosaic-common/rtl/counter.sv \
    $(MODULE_ROOT)/rtl/async_fifo.sv
export SDC_FILE = $(MODULE_ROOT)/flows/openroad/timing.sdc
export LEC_CHECK = 0
export DIE_AREA = 0 0 100 100
export CORE_AREA = 5 5 95 95
