// Shared coverage model used by simulation, PyUVM, and formal reachability.
module mosaic_module_coverage #(
    parameter int unsigned DATA_WIDTH = 32
) (
    input logic                  clk_i,
    input logic                  rst_ni,
    input logic                  enable_i,
    input logic [DATA_WIDTH-1:0] data_i,
    input logic [DATA_WIDTH-1:0] data_o
);

`ifdef MOSAIC_YOSYS_FORMAL
  // Procedural equivalents preserve cover intent in Yosys. The final cover
  // checks the same one-cycle representative transfer as the shared property.
  logic past_valid = 1'b0;

  always_ff @(posedge clk_i) begin
    past_valid <= 1'b1;

    if (rst_ni) begin
      cover (enable_i);
      cover (!enable_i);
      cover (enable_i && data_i == {DATA_WIDTH{1'b1}});
      cover (past_valid && $past(
          rst_ni
      ) && $past(
          enable_i
      ) && $past(
          data_i
      ) == {DATA_WIDTH{1'b1}} && data_o == {DATA_WIDTH{1'b1}});
    end
  end
`else
  // Keep coverage directives separate while reusing the common properties.
  `include "mosaic_module_properties.svh"

enabled_operation :
  cover property (@(posedge clk_i) disable iff (!rst_ni) enabled_operation_s);

  disabled_operation :
  cover property (@(posedge clk_i) disable iff (!rst_ni) disabled_operation_s);

  representative_data :
  cover property (@(posedge clk_i) disable iff (!rst_ni) representative_data_s);

  representative_output :
  cover property (@(posedge clk_i) disable iff (!rst_ni) representative_output_p);
`endif

endmodule
