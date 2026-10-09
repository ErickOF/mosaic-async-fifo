`timescale 1ns / 1ps
// Four-state payload transport, control-monitor controls, and parameter guards.
module async_fifo_four_state_tb #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned DEPTH = 4,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1
);
    localparam int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1);
    localparam int unsigned PAYLOAD_WIDTH = DATA_WIDTH > 0 ? DATA_WIDTH : 1;
    localparam int unsigned STORAGE_DEPTH = DEPTH >= 2 ? DEPTH : 2;
    localparam int unsigned CHECK_STAGES = SYNC_STAGES >= 2 ? SYNC_STAGES : 2;
    localparam int unsigned PTR_WIDTH = (DEPTH >= 2 ? $clog2(DEPTH) : 1) + 1;
    localparam int unsigned CORPUS_BURSTS = 3 * ((8 + STORAGE_DEPTH - 1) / STORAGE_DEPTH);
    logic i_w_clk = 0, i_r_clk = 0;
    logic i_w_rstb = 1, i_r_rstb = 1;
    logic i_w_valid = 0, i_r_ready = 0;
    logic [PAYLOAD_WIDTH-1:0] i_w_data = 0, o_r_data;
    wire o_w_ready, o_w_full, o_w_almost_full, o_w_init_done;
    wire o_r_valid, o_r_empty, o_r_almost_empty, o_r_init_done;
    wire [LEVEL_WIDTH-1:0] o_w_level, o_r_level;
    wire [STORAGE_DEPTH*PAYLOAD_WIDTH-1:0] storage_snapshot;
    string control_name, unknown_value;
    logic injected_bit;
    logic [PAYLOAD_WIDTH-1:0] expected_payloads[STORAGE_DEPTH];
    int unsigned pattern_hits[8];
    int unsigned records = 0;
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
    async_fifo_sva #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) u_checker (
        .i_w_clk(i_w_clk),
        .i_w_rstb(i_w_rstb),
        .i_w_valid(i_w_valid),
        .o_w_ready(o_w_ready),
        .o_w_full(o_w_full),
        .o_w_almost_full(o_w_almost_full),
        .o_w_init_done(o_w_init_done),
        .i_w_data(i_w_data),
        .o_w_level(o_w_level),
        .i_r_clk(i_r_clk),
        .i_r_rstb(i_r_rstb),
        .o_r_valid(o_r_valid),
        .i_r_ready(i_r_ready),
        .o_r_empty(o_r_empty),
        .o_r_almost_empty(o_r_almost_empty),
        .o_r_init_done(o_r_init_done),
        .o_r_data(o_r_data),
        .o_r_level(o_r_level),
        .w_bin(dut.w_bin),
        .w_gray(dut.w_gray),
        .r_bin(dut.r_bin),
        .r_gray(dut.r_gray),
        .r_gray_final(dut.r_gray_sync[CHECK_STAGES-1]),
        .w_gray_final(dut.w_gray_sync[CHECK_STAGES-1]),
        .r_up_final(dut.r_up_sync[CHECK_STAGES-1]),
        .w_up_final(dut.w_up_sync[CHECK_STAGES-1]),
        .w_up(dut.w_up),
        .r_up(dut.r_up),
        .w_seen_remote(dut.w_seen_remote),
        .r_seen_remote(dut.r_seen_remote),
        .push(dut.push),
        .pop(dut.pop),
        .r_data_enable(dut.r_data_enable),
        .r_data_next(dut.r_data_next),
        .storage_snapshot(storage_snapshot)
    );
    for (genvar word_index = 0; word_index < STORAGE_DEPTH; word_index++) begin : g_observation
        assign storage_snapshot[word_index*PAYLOAD_WIDTH+:PAYLOAD_WIDTH] = dut.memory[word_index];
    end

    function automatic logic [PAYLOAD_WIDTH-1:0] payload_pattern(input int pattern);
        logic [PAYLOAD_WIDTH-1:0] value;
        value = '0;
        if (pattern == 0) value = 'x;
        else if (pattern == 1) value = 'z;
        else if (pattern < 6) begin
            for (int bit_index = 0; bit_index < PAYLOAD_WIDTH; bit_index++) begin
                case ((bit_index + pattern - 2) % 4)
                    0: value[bit_index] = 0;
                    1: value[bit_index] = 1;
                    2: value[bit_index] = 1'bx;
                    3: value[bit_index] = 1'bz;
                    default: $fatal(1, "invalid mixed-payload bit");
                endcase
            end
        end else if (pattern == 6) value[PAYLOAD_WIDTH/2] = 1'bx;
        else begin
            value = '1;
            value[0] = 1'bz;
        end
        payload_pattern = value;
    endfunction

    task automatic write_payload(input logic [PAYLOAD_WIDTH-1:0] value);
        @(negedge i_w_clk);
        i_w_data  = value;
        i_w_valid = 1;
        do @(posedge i_w_clk); while (!o_w_ready);
        @(negedge i_w_clk);
        i_w_valid = 0;
    endtask

    task automatic read_payload(input logic [PAYLOAD_WIDTH-1:0] expected);
        wait (o_r_valid === 1'b1);
        repeat (4) begin
            @(negedge i_r_clk);
            if (o_r_data !== expected || o_r_valid !== 1'b1)
                $fatal(1, "unknown payload was corrupted");
            if ($isunknown(
                    {
                        o_w_ready,
                        o_w_full,
                        o_w_almost_full,
                        o_w_level,
                        o_w_init_done,
                        o_r_valid,
                        o_r_empty,
                        o_r_almost_empty,
                        o_r_level,
                        o_r_init_done
                    }
                ))
                $fatal(1, "payload contaminated control state");
        end
        i_r_ready = 1;
        @(posedge i_r_clk);
        @(negedge i_r_clk);
        i_r_ready = 0;
    endtask

    initial begin
        for (int pattern = 0; pattern < 8; pattern++) pattern_hits[pattern] = 0;
        // Explicit reset edges initialize four-state storage before clocking.
        #1;
        i_w_rstb = 0;
        i_r_rstb = 0;
        #20;
        @(negedge i_w_clk);
        i_w_rstb = 1;
        @(negedge i_r_clk);
        i_r_rstb = 1;
        wait (o_w_init_done && o_r_init_done);
        #40;
        if ($value$plusargs("CONTROL=%s", control_name)) begin
            if (!$value$plusargs("VALUE=%s", unknown_value)) $fatal(1, "missing VALUE");
            if (unknown_value == "X") injected_bit = 1'bx;
            else if (unknown_value == "Z") injected_bit = 1'bz;
            else $fatal(1, "invalid VALUE");
            // Deposit on a local falling edge. Icarus does not support forcing
            // unpacked variable-array words. The final-stage value remains
            // unknown through the next active sample, before its NBA overwrite.
            if (control_name == "i_w_rstb" || control_name == "i_w_valid" ||
                control_name == "r_gray_final" || control_name == "r_up_final")
                @(negedge i_w_clk);
            else @(negedge i_r_clk);
            if (control_name == "i_w_rstb") i_w_rstb = injected_bit;
            else if (control_name == "i_r_rstb") i_r_rstb = injected_bit;
            else if (control_name == "i_w_valid") i_w_valid = injected_bit;
            else if (control_name == "i_r_ready") i_r_ready = injected_bit;
            else if (control_name == "r_gray_final")
                dut.r_gray_sync[CHECK_STAGES-1] = {PTR_WIDTH{injected_bit}};
            else if (control_name == "w_gray_final")
                dut.w_gray_sync[CHECK_STAGES-1] = {PTR_WIDTH{injected_bit}};
            else if (control_name == "r_up_final") dut.r_up_sync[CHECK_STAGES-1] = injected_bit;
            else if (control_name == "w_up_final") dut.w_up_sync[CHECK_STAGES-1] = injected_bit;
            else $fatal(1, "invalid CONTROL");
            #1ps;
            // A passing disabled-monitor control must prove actual arrival at
            // the checker input, not merely print the requested target name.
            if ((control_name == "i_w_rstb" && i_w_rstb !== injected_bit) ||
                (control_name == "i_r_rstb" && i_r_rstb !== injected_bit) ||
                (control_name == "i_w_valid" && i_w_valid !== injected_bit) ||
                (control_name == "i_r_ready" && i_r_ready !== injected_bit) ||
                (control_name == "r_gray_final" &&
                    u_checker.r_gray_final !== {PTR_WIDTH{injected_bit}}) ||
                (control_name == "w_gray_final" &&
                    u_checker.w_gray_final !== {PTR_WIDTH{injected_bit}}) ||
                (control_name == "r_up_final" && u_checker.r_up_final !== injected_bit) ||
                (control_name == "w_up_final" && u_checker.w_up_final !== injected_bit))
                $fatal(1, "injection did not arrive");
            $display("UNKNOWN_STIMULUS_REACHED %s %s", control_name, unknown_value);
            #30;
`ifdef FIFO_DISABLE_CONTROL_MONITOR
            $display("DISABLED_MONITOR_CONTROL_PASS");
`else
            $fatal(1, "UNKNOWN_MONITOR_ESCAPED %s %s", control_name, unknown_value);
`endif
        end else begin
            // A verification-only force validates the independent payload check.
            if ($test$plusargs("CORRUPT_OUTPUT")) force dut.o_r_data = '0;
            if (PAYLOAD_WIDTH < 4) $fatal(1, "mixed payload corpus requires four bits");
            // Independent expected records remain queued together, so mixed
            // known/X/Z bits must survive storage, prefetch, stalls and wraps.
            for (int burst = 0; burst < CORPUS_BURSTS; burst++) begin
                for (int word_index = 0; word_index < STORAGE_DEPTH; word_index++) begin
                    expected_payloads[word_index] = payload_pattern(records % 8);
                    write_payload(expected_payloads[word_index]);
                    records++;
                end
                wait (o_w_full === 1'b1);
                for (int word_index = 0; word_index < STORAGE_DEPTH; word_index++) begin
                    read_payload(expected_payloads[word_index]);
                    pattern_hits[(burst*STORAGE_DEPTH+word_index)%8]++;
                end
                wait (o_r_empty === 1'b1 && o_r_valid === 1'b0 && o_w_level == '0);
            end
            for (int pattern = 0; pattern < 8; pattern++) begin
                int unsigned hits;
                hits = pattern_hits[pattern];
                if (hits < 3) $fatal(1, "missing payload pattern %0d", pattern);
                $display("FOUR_STATE_PATTERN_PASS pattern=%0d hits=%0d", pattern, hits);
            end
            $display("FOUR_STATE_PAYLOAD_PASS records=%0d bursts=%0d", records, CORPUS_BURSTS);
        end
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "four-state test timeout");
    end
endmodule
