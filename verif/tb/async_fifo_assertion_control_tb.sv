`timescale 1ns / 1ps
// Reuse the normal regression as the positive control. Faults alter only the
// checker's observed values, not FIFO behavior or the independent scoreboard.
module async_fifo_assertion_control_tb #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH = 8,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1
);
    string fault;
    logic [DATA_WIDTH*DEPTH-1:0] corrupted_storage;

    async_fifo_tb #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) u_baseline ();

    initial begin
        if ($value$plusargs("ASSERTION_FAULT=%s", fault)) begin
            case (fault)
                "storage_hold": begin
                    wait (u_baseline.o_w_full && u_baseline.expected_queue.size() == DEPTH);
                    repeat (2) @(posedge u_baseline.i_w_clk);
                    @(negedge u_baseline.i_w_clk);
                    #1ps;
                    corrupted_storage = u_baseline.dut.u_checker.storage_snapshot ^
                        ((DATA_WIDTH * DEPTH)'(1) << ((DEPTH - 1) * DATA_WIDTH));
                    force u_baseline.dut.u_checker.u_behavior.storage_snapshot = corrupted_storage;
                end
                "output_idle_hold": begin
                    wait (u_baseline.o_r_init_done);
                    // Establish one initialized, empty sample before corrupting
                    // invalid output data. No queue comparison can detect this.
                    @(posedge u_baseline.i_r_clk);
                    @(negedge u_baseline.i_r_clk);
                    force u_baseline.dut.u_checker.u_behavior.o_r_data = '1;
                end
                "write_init_prerequisites": begin
                    wait (u_baseline.o_w_full && u_baseline.expected_queue.size() == DEPTH);
                    @(negedge u_baseline.i_w_clk);
                    force u_baseline.dut.u_checker.u_behavior.r_up_final = 1'b0;
                end
                "write_async_reset": begin
                    wait (u_baseline.o_w_full && u_baseline.expected_queue.size() == DEPTH);
                    @(negedge u_baseline.i_w_clk);
                    // Reset must be checked without waiting for a write edge.
                    u_baseline.w_run = 0;
                    force u_baseline.dut.u_checker.u_behavior.w_bin = '1;
                    u_baseline.i_w_rstb = 0;
                end
                default: $fatal(1, "unknown ASSERTION_FAULT=%s", fault);
            endcase
            $display("ASSERTION_FAULT_REACHED %s", fault);
            #100ns;
            $fatal(1, "ASSERTION_FAULT_ESCAPED %s", fault);
        end
    end
endmodule
