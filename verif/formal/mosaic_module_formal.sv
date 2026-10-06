// Minimal unconstrained harness shared by proof and property-reachability tasks.
module mosaic_module_formal #(
    parameter int unsigned DATA_WIDTH = 32
);

  (* gclk   *)logic                  clk_i;
  (* anyseq *)logic                  rst_ni;
  (* anyseq *)logic                  enable_i;
  (* anyseq *)logic [DATA_WIDTH-1:0] data_i;
  logic [DATA_WIDTH-1:0] data_o;

  mosaic_module #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

  // Select one shared wrapper for each proof or reachability task. Keeping
  // directives out of this harness prevents formal-only copies from diverging.
`ifdef FORMAL_ASSERTIONS
  mosaic_module_bind #(.DATA_WIDTH(DATA_WIDTH)) i_mosaic_module_bind (.*);
`endif

`ifdef FORMAL_COVERAGE
  mosaic_module_coverage_bind #(.DATA_WIDTH(DATA_WIDTH)) i_mosaic_module_coverage_bind (.*);
`endif

endmodule
