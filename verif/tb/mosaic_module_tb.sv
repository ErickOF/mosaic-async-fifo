module mosaic_module_tb #(
    parameter int unsigned DATA_WIDTH = 32
);

  logic                  clk_i;
  logic                  rst_ni;
  logic                  enable_i;
  logic [DATA_WIDTH-1:0] data_i;
  logic [DATA_WIDTH-1:0] data_o;

  always #5ns clk_i = ~clk_i;

  mosaic_module #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

  initial begin
    clk_i    = 1'b0;
    rst_ni   = 1'b0;
    enable_i = 1'b0;
    data_i   = '0;

    repeat (2) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni   = 1'b1;
    data_i   = '1;
    enable_i = 1'b1;
    @(posedge clk_i);
    @(negedge clk_i);
    enable_i = 1'b0;

    assert (data_o == '1)
    else $fatal(1, "Unexpected output: %h", data_o);

    // Exercise both transition directions before checking the hold path.
    data_i = '0;
    @(posedge clk_i);
    @(negedge clk_i);
    assert (data_o == '1)
    else $fatal(1, "Disabled output changed unexpectedly: %h", data_o);

    enable_i = 1'b1;
    @(posedge clk_i);
    @(negedge clk_i);
    enable_i = 1'b0;
    assert (data_o == '0)
    else $fatal(1, "Unexpected cleared output: %h", data_o);

    // Reassert reset to exercise the asynchronous control in both directions.
    rst_ni = 1'b0;
    #1ns;
    rst_ni = 1'b1;
    repeat (2) @(posedge clk_i);
    @(negedge clk_i);

    $display("MOSAIC_MODULE_TEST_PASS");
    $finish;
  end
endmodule
