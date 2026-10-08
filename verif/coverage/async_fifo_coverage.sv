`timescale 1ns / 1ps
// Shared state observations. Simulation uses native per-bin covergroups.
`ifdef MOSAIC_YOSYS_FORMAL
`define FIFO_COVER(NAME, CLOCK, CONDITION) \
    always @(posedge CLOCK) begin \
        cover (CONDITION); \
    end
`else
`define FIFO_COVER(NAME, CLOCK, CONDITION) \
    NAME: cover property (@(posedge CLOCK) CONDITION);
`endif

module async_fifo_coverage #(
    parameter int unsigned DEPTH = 8,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1,
`ifdef MOSAIC_FORMAL
    parameter bit RUNTIME_RESET_COVERS = 0,
`endif
    localparam int unsigned PTR_WIDTH = $clog2(DEPTH) + 1,
    localparam int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1)
) (
    input logic i_w_clk,
    i_w_rstb,
    i_w_valid,
    o_w_ready,
    o_w_full,
    input logic o_w_almost_full,
    o_w_init_done,
    input logic i_r_clk,
    i_r_rstb,
    o_r_valid,
    i_r_ready,
    o_r_empty,
    input logic o_r_almost_empty,
    o_r_init_done,
    input logic [LEVEL_WIDTH-1:0] o_w_level,
    o_r_level,
    input logic [PTR_WIDTH-1:0] w_bin,
    r_bin,
    r_gray_final,
    w_gray_final,
    input logic [SYNC_STAGES*PTR_WIDTH-1:0] r_gray_stages,
    w_gray_stages,
    input logic [SYNC_STAGES-1:0] r_up_stages,
    w_up_stages
);
    localparam int unsigned ADDR_WIDTH = PTR_WIDTH - 1;
    wire operational = i_w_rstb && i_r_rstb && o_w_init_done && o_r_init_done;
    wire push = i_w_valid && o_w_ready;
    wire pop = o_r_valid && i_r_ready;
    logic w_history, r_history;
    logic previous_w_init, previous_r_init, previous_af, previous_ae;
    logic previous_w_phase, previous_r_phase;
    logic [SYNC_STAGES*PTR_WIDTH-1:0] previous_r_gray, previous_w_gray;
    logic [SYNC_STAGES-1:0] previous_r_up, previous_w_up;
    initial begin
        w_history = 0;
        r_history = 0;
    end

    // Local histories end at local reset. Threshold transitions additionally
    // require initialized samples on both sides of the transition.
    always @(posedge i_w_clk or negedge i_w_rstb) begin
        if (!i_w_rstb) w_history <= 0;
        else w_history <= 1;
    end
    always @(posedge i_w_clk) begin
        previous_w_init <= o_w_init_done;
        previous_af <= o_w_almost_full;
        previous_w_phase <= w_bin[PTR_WIDTH-1];
        previous_r_gray <= r_gray_stages;
        previous_r_up <= r_up_stages;
    end
    always @(posedge i_r_clk or negedge i_r_rstb) begin
        if (!i_r_rstb) r_history <= 0;
        else r_history <= 1;
    end
    always @(posedge i_r_clk) begin
        previous_r_init <= o_r_init_done;
        previous_ae <= o_r_almost_empty;
        previous_r_phase <= r_bin[PTR_WIDTH-1];
        previous_w_gray <= w_gray_stages;
        previous_w_up <= w_up_stages;
    end

    `FIFO_COVER(accepted_write, i_w_clk, i_w_rstb && o_w_init_done && push)
    `FIFO_COVER(observed_full, i_w_clk, i_w_rstb && o_w_init_done && o_w_full)
    `FIFO_COVER(accepted_read, i_r_clk, i_r_rstb && o_r_init_done && pop)
    `FIFO_COVER(stalled_output, i_r_clk, i_r_rstb && o_r_init_done && o_r_valid && !i_r_ready)
    `FIFO_COVER(observed_empty, i_r_clk, i_r_rstb && o_r_init_done && o_r_empty)

`ifdef MOSAIC_YOSYS_FORMAL
    // Check, rather than assume, why the two other wrap-phase pairs cannot
    // occur in the selected formal models. Simulation retains all pairs.
    always @(posedge i_w_clk) begin
        if (operational && w_history && w_bin[PTR_WIDTH-1] != previous_w_phase)
            assert (w_bin[PTR_WIDTH-1] != r_gray_final[PTR_WIDTH-1]);
    end
    always @(posedge i_r_clk) begin
        if (operational && r_history && r_bin[PTR_WIDTH-1] != previous_r_phase)
            assert (r_bin[PTR_WIDTH-1] == w_gray_final[PTR_WIDTH-1]);
    end
    // Pair current storage addresses at a real local transfer, not an offer
    // in the other clock domain. The queue scoreboard remains independent.
    for (genvar wa = 0; wa < DEPTH; wa++) begin : g_write_address
        for (genvar ra = 0; ra < DEPTH; ra++) begin : g_read_address
            `FIFO_COVER(address_pair_write, i_w_clk,
                        operational && push &&
                w_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(wa) &&
                r_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(ra))
            `FIFO_COVER(address_pair_read, i_r_clk,
                        operational && pop &&
                w_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(wa) &&
                r_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(ra))
        end
    end
    for (genvar activity = 0; activity < 2; activity++) begin : g_activity
        for (genvar full = 0; full < 2; full++) begin : g_full
            for (genvar empty = 0; empty < 2; empty++) begin : g_empty
                // Accepted push/full and accepted pop/empty are illegal.
                if (!(activity && full)) begin : g_write_legal
                    `FIFO_COVER(write_activity_status, i_w_clk,
                                operational &&
                        push == 1'(activity) && o_w_full == 1'(full) && o_r_empty == 1'(empty))
                end
                if (!(activity && empty)) begin : g_read_legal
                    `FIFO_COVER(read_activity_status, i_r_clk,
                                operational &&
                        pop == 1'(activity) && o_w_full == 1'(full) && o_r_empty == 1'(empty))
                end
            end
        end
    end
    for (genvar phase = 0; phase < 2; phase++) begin : g_local_phase
        `FIFO_COVER(write_phase, i_w_clk, operational && w_bin[PTR_WIDTH-1] == 1'(phase))
        `FIFO_COVER(read_phase, i_r_clk, operational && r_bin[PTR_WIDTH-1] == 1'(phase))
        for (genvar remote = 0; remote < 2; remote++) begin : g_remote_phase
            if (remote != phase) begin : g_write_reachable
                `FIFO_COVER(write_wrap_remote_phase, i_w_clk,
                            operational && w_history &&
                w_bin[PTR_WIDTH-1] != previous_w_phase && w_bin[PTR_WIDTH-1] == 1'(phase) &&
                r_gray_final[PTR_WIDTH-1] == 1'(remote))
            end
            if (remote == phase) begin : g_read_reachable
                `FIFO_COVER(read_wrap_remote_phase, i_r_clk,
                            operational && r_history &&
                r_bin[PTR_WIDTH-1] != previous_r_phase && r_bin[PTR_WIDTH-1] == 1'(phase) &&
                w_gray_final[PTR_WIDTH-1] == 1'(remote))
            end
        end
    end
    for (genvar level = 0; level <= DEPTH; level++) begin : g_level
        for (genvar stall = 0; stall < 2; stall++) begin : g_stall
            // Initialized source backpressure requires full. A valid stalled
            // output requires a nonzero read estimate.
            if (!stall || level == DEPTH) begin : g_source_legal
                `FIFO_COVER(source_stall_level, i_w_clk,
                            i_w_rstb && o_w_init_done &&
                    (i_w_valid && !o_w_ready) == 1'(stall) && o_w_level == LEVEL_WIDTH'(level))
            end
            if (!stall || level != 0) begin : g_destination_legal
                `FIFO_COVER(destination_stall_level, i_r_clk,
                            i_r_rstb && o_r_init_done &&
                    (o_r_valid && !i_r_ready) == 1'(stall) && o_r_level == LEVEL_WIDTH'(level))
            end
        end
        for (genvar entry = 0; entry < 2; entry++) begin : g_threshold_direction
            // Local writes/read pops increase/decrease by at most one.
            // Remote-pointer advances may skip levels on AF exit / AE exit.
            if ((entry && level == ALMOST_FULL_LEVEL) ||
                (!entry && level < ALMOST_FULL_LEVEL)) begin : g_af_legal
                `FIFO_COVER(almost_full_transition, i_w_clk,
                            i_w_rstb && w_history &&
                    previous_w_init && o_w_init_done && previous_af != o_w_almost_full &&
                    o_w_almost_full == 1'(entry) && o_w_level == LEVEL_WIDTH'(level))
            end
            if ((entry && level == ALMOST_EMPTY_LEVEL) ||
                (!entry && level > ALMOST_EMPTY_LEVEL)) begin : g_ae_legal
                `FIFO_COVER(almost_empty_transition, i_r_clk,
                            i_r_rstb && r_history &&
                    previous_r_init && o_r_init_done && previous_ae != o_r_almost_empty &&
                    o_r_almost_empty == 1'(entry) && o_r_level == LEVEL_WIDTH'(level))
            end
        end
    end
    for (genvar stage = 0; stage < SYNC_STAGES; stage++) begin : g_stage
        for (genvar direction = 0; direction < 2; direction++) begin : g_direction
            // Falling domain-up transitions require a runtime-reset harness.
            if (direction == 1 || RUNTIME_RESET_COVERS) begin : g_runtime_scope
                `FIFO_COVER(read_up_stage_transition, i_w_clk,
                            i_w_rstb && w_history &&
                    previous_r_up[stage] != r_up_stages[stage] && r_up_stages[stage] == 1'(direction))
                `FIFO_COVER(write_up_stage_transition, i_r_clk,
                            i_r_rstb && r_history &&
                    previous_w_up[stage] != w_up_stages[stage] && w_up_stages[stage] == 1'(direction))
            end
            for (genvar bit_index = 0; bit_index < PTR_WIDTH; bit_index++) begin : g_bit
                `FIFO_COVER(read_gray_stage_transition, i_w_clk,
                            i_w_rstb && w_history &&
                    previous_r_gray[stage*PTR_WIDTH+bit_index] !=
                    r_gray_stages[stage*PTR_WIDTH+bit_index] &&
                    r_gray_stages[stage*PTR_WIDTH+bit_index] == 1'(direction))
                `FIFO_COVER(write_gray_stage_transition, i_r_clk,
                            i_r_rstb && r_history &&
                    previous_w_gray[stage*PTR_WIDTH+bit_index] !=
                    w_gray_stages[stage*PTR_WIDTH+bit_index] &&
                    w_gray_stages[stage*PTR_WIDTH+bit_index] == 1'(direction))
            end
        end
    end
`else
    `include "async_fifo_state_covergroups.svh"
`endif
endmodule
`undef FIFO_COVER
