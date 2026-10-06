// Stable wrapper boundary for attaching the coverage model to the DUT.
module mosaic_module_coverage_bind #(
    parameter int unsigned DATA_WIDTH = 32
) (
    input logic                  clk_i,
    input logic                  rst_ni,
    input logic                  enable_i,
    input logic [DATA_WIDTH-1:0] data_i,
    input logic [DATA_WIDTH-1:0] data_o
);

  mosaic_module_coverage #(.DATA_WIDTH(DATA_WIDTH)) i_mosaic_module_coverage (.*);

endmodule

`ifndef MOSAIC_FORMAL
// Simulation attaches coverage automatically. Formal instantiates the wrapper
// in its harness to avoid relying on Yosys bind support.
bind mosaic_module mosaic_module_coverage_bind #(
    .DATA_WIDTH(DATA_WIDTH)
) i_mosaic_module_coverage_bind (.*);
`endif
