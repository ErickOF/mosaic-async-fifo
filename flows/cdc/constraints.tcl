# Declare every clock, reset, generated clock and intentional synchronization path.
# Keep tool-specific waivers in docs/waivers.md with an owner and expiration date.

# Example intent. Adapt commands to the selected VC CDC or SpyGlass CDC release.
# clock -name clk_i -period 10 [get_ports clk_i]
# reset -name rst_ni -value 0 [get_ports rst_ni]
