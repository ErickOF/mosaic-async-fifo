`timescale 1ns / 1ps
// Digital RTL-state faults, separate from observation-only checker controls.
// The same compiled design and bound SVA run without a fault as the baseline.
module async_fifo_fault_tb #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned DEPTH = 4,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1
);
    localparam int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1);
    localparam int unsigned WAIT_CYCLES = 4 * (SYNC_STAGES + DEPTH + 4);
    logic i_w_clk, i_r_clk;
    logic i_w_rstb = 1, i_r_rstb = 1;
    logic i_w_valid = 0, i_r_ready = 0;
    logic [DATA_WIDTH-1:0] i_w_data = 0, o_r_data;
    wire o_w_ready, o_w_full, o_w_almost_full, o_w_init_done;
    wire o_r_valid, o_r_empty, o_r_almost_empty, o_r_init_done;
    wire [LEVEL_WIDTH-1:0] o_w_level, o_r_level;
    string fault = "";
    logic [DATA_WIDTH-1:0] corrupted_word;
    int unsigned delivered = 0;

    always #3 i_w_clk = !i_w_clk;
    always #5 i_r_clk = !i_r_clk;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) dut (
        .*
    );

    // These bounds apply only to the ideal digital clocks in this fixture,
    // not to analog synchronization latency or system-level clock fairness.
    task automatic await_startup;
        for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
            @(negedge i_r_clk);
            if (o_w_init_done && o_r_init_done) return;
        end
        $fatal(1, "FAULT_DETECTED %s initialization", fault);
    endtask

    task automatic reset_fifo;
        i_w_valid = 0;
        i_r_ready = 0;
        i_w_rstb  = 0;
        i_r_rstb  = 0;
        #20;
        @(negedge i_w_clk);
        i_w_rstb = 1;
        @(negedge i_r_clk);
        i_r_rstb = 1;
        await_startup();
        repeat (4) @(negedge i_w_clk);
    endtask

    task automatic write_record(input logic [DATA_WIDTH-1:0] value);
        @(negedge i_w_clk);
        i_w_data  = value;
        i_w_valid = 1;
        for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
            @(posedge i_w_clk);
            if (o_w_ready) begin
                @(negedge i_w_clk);
                i_w_valid = 0;
                return;
            end
        end
        $fatal(1, "FAULT_DETECTED %s write acceptance", fault);
    endtask

    task automatic read_record(input logic [DATA_WIDTH-1:0] expected);
        for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
            @(negedge i_r_clk);
            if (o_r_valid) begin
                if (o_r_data !== expected) $fatal(1, "FAULT_DETECTED %s payload mismatch", fault);
                i_r_ready = 1;
                @(posedge i_r_clk);
                @(negedge i_r_clk);
                i_r_ready = 0;
                delivered++;
                return;
            end
        end
        $fatal(1, "FAULT_DETECTED %s read visibility", fault);
    endtask

    task automatic await_capacity;
        for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
            @(negedge i_w_clk);
            if (o_w_ready && !o_w_full && o_w_level == '0 &&
                o_r_empty && !o_r_valid && o_r_level == '0) begin
                if (o_w_almost_full !==
                    (o_w_init_done && o_w_level >= LEVEL_WIDTH'(ALMOST_FULL_LEVEL)) ||
                    o_r_almost_empty !==
                    (!o_r_init_done || o_r_level <= LEVEL_WIDTH'(ALMOST_EMPTY_LEVEL)))
                    $fatal(1, "FAULT_DETECTED %s threshold mismatch", fault);
                return;
            end
        end
        $fatal(1, "FAULT_DETECTED %s write capacity", fault);
    endtask

    initial begin
        i_w_clk = 0;
        i_r_clk = 0;
        if ($value$plusargs("FAULT=%s", fault)) begin
            if (fault != "write_pointer_stage0" && fault != "write_pointer_final" &&
                fault != "read_pointer_stage0" && fault != "read_pointer_final" &&
                fault != "write_up_stage0" && fault != "write_up_final" &&
                fault != "read_up_stage0" && fault != "read_up_final" &&
                fault != "full_flag" && fault != "empty_flag" &&
                fault != "memory_hold" && fault != "memory_write")
                $fatal(1, "invalid FAULT");
        end
        #1;
        // Domain-up mutations prevent initial startup with both clocks running.
        case (fault)
            "write_up_stage0": force dut.r_up_sync[0] = 0;
            "write_up_final":  force dut.r_up_sync[SYNC_STAGES-1] = 0;
            "read_up_stage0":  force dut.w_up_sync[0] = 0;
            "read_up_final":   force dut.w_up_sync[SYNC_STAGES-1] = 0;
            default: begin
            end
        endcase
        if (fault == "write_up_stage0" || fault == "write_up_final" ||
            fault == "read_up_stage0" || fault == "read_up_final")
            $display("INJECTED_RTL_FAULT %s", fault);
        reset_fifo();

        // Initialize real storage before mutation, without assuming power-on
        // values. Reset leaves these accepted zero records in memory.
        for (int index = 0; index < DEPTH; index++) write_record('0);
        for (int index = 0; index < DEPTH; index++) read_record('0);
        await_capacity();
        reset_fifo();

        if (fault == "read_pointer_stage0") force dut.w_gray_sync[0] = '0;
        if (fault == "read_pointer_final") force dut.w_gray_sync[SYNC_STAGES-1] = '0;
        if (fault == "write_pointer_stage0") force dut.r_gray_sync[0] = '0;
        if (fault == "write_pointer_final") force dut.r_gray_sync[SYNC_STAGES-1] = '0;
        if (fault == "memory_write") force dut.memory[0] = '0;
        if (fault == "empty_flag") force dut.o_r_empty = 0;
        if (fault == "read_pointer_stage0" || fault == "read_pointer_final" ||
            fault == "write_pointer_stage0" || fault == "write_pointer_final" ||
            fault == "memory_write" || fault == "empty_flag")
            $display("INJECTED_RTL_FAULT %s", fault);
        if (fault == "empty_flag") begin
            repeat (WAIT_CYCLES) @(negedge i_r_clk);
            $fatal(1, "RTL_FAULT_ESCAPED %s", fault);
        end

        for (int index = 0; index < DEPTH; index++) write_record('1);
        wait (o_w_full);
        repeat (3) @(negedge i_w_clk);
        if (fault == "full_flag") force dut.o_w_full = 0;
        if (fault == "memory_hold") begin
            corrupted_word = dut.memory[DEPTH-1] ^ DATA_WIDTH'(1);
            force dut.memory[DEPTH-1] = corrupted_word;
        end
        if (fault == "full_flag" || fault == "memory_hold") begin
            $display("INJECTED_RTL_FAULT %s", fault);
            repeat (WAIT_CYCLES) @(negedge i_w_clk);
            $fatal(1, "RTL_FAULT_ESCAPED %s", fault);
        end
        for (int index = 0; index < DEPTH; index++) read_record('1);
        await_capacity();
        if (fault != "") $fatal(1, "RTL_FAULT_ESCAPED %s", fault);
        if (delivered != 2 * DEPTH) $fatal(1, "fault baseline did not check every record");
        $display("FAULT_BASELINE_PASS records=%0d", delivered);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "FAULT_FIXTURE_TIMEOUT");
    end
endmodule
