module mosaic_module_four_state_tb;
  logic enable_i;
  logic saw_x;
  logic saw_z;

  initial begin
    saw_x = 1'b0;
    saw_z = 1'b0;

    enable_i = 1'bx;
    #1;
    saw_x = $isunknown(enable_i);

    enable_i = 1'bz;
    #1;
    saw_z = $isunknown(enable_i);

`ifdef MOSAIC_MODULE_DISABLE_UNKNOWN_MONITOR
    if (saw_x && saw_z) begin
      $display("UNKNOWN_ENABLE_STIMULUS_REACHED");
      $finish;
    end
    $fatal(1, "FOUR_STATE_STIMULUS_BROKEN");
`else
    if (saw_x && saw_z) begin
      $fatal(1, "UNKNOWN_ENABLE_XZ_DETECTED");
    end
    $finish;
`endif
  end
endmodule
