# Draft characterization clocks, not an ASIC timing qualification.
create_clock -name w_clk -period 10.000 [get_ports i_w_clk]
create_clock -name r_clk -period 14.000 [get_ports i_r_clk]
set_clock_uncertainty 0.100 [get_clocks {w_clk r_clk}]
set_input_delay 0.500 -clock w_clk [get_ports {i_w_valid i_w_data i_w_rstb}]
set_input_delay 0.500 -clock r_clk [get_ports {i_r_ready i_r_rstb}]
set_output_delay 0.500 -clock w_clk [get_ports {o_w_ready o_w_full o_w_almost_full o_w_level o_w_init_done}]
set_output_delay 0.500 -clock r_clk [get_ports {o_r_valid o_r_data o_r_empty o_r_almost_empty o_r_level o_r_init_done}]

# Do not insert blanket clock groups or reset false paths here. They can mask
# Gray-bus constraints or reset recovery/removal. The mapped configuration must
# supply exact source-Q / first-stage-D collections for both Gray buses and up
# bits, source-transition-based datapath delay and bus-skew limits, synchronizer
# preservation/placement, and a separately reviewed storage crossing policy.
# Mapping names, frequencies, skew budgets and library corners are not available.
error "BLOCKED: async_fifo Gray crossing endpoints, budgets and reset timing are not qualified"
