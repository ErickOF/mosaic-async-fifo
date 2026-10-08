`timescale 1ns / 1ps
`ifndef MOSAIC_FORMAL
// Pack real synchronizer arrays for the shared, formal-compatible state model.
module async_fifo_sim_coverage #(
    parameter int unsigned DEPTH = 8,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1,
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
    input logic w_up,
    r_up,
    w_seen_remote,
    r_seen_remote,
    input logic [LEVEL_WIDTH-1:0] o_w_level,
    o_r_level,
    input logic [PTR_WIDTH-1:0] w_bin,
    r_bin,
    input logic [PTR_WIDTH-1:0] r_gray_words[SYNC_STAGES],
    w_gray_words[SYNC_STAGES],
    input logic r_up_words[SYNC_STAGES],
    w_up_words[SYNC_STAGES]
);
    wire [SYNC_STAGES*PTR_WIDTH-1:0] r_gray_stages, w_gray_stages;
    wire [SYNC_STAGES-1:0] r_up_stages, w_up_stages;
    wire [PTR_WIDTH-1:0] r_gray_final = r_gray_words[SYNC_STAGES-1];
    wire [PTR_WIDTH-1:0] w_gray_final = w_gray_words[SYNC_STAGES-1];
    for (genvar stage = 0; stage < SYNC_STAGES; stage++) begin : g_pack
        assign r_gray_stages[stage*PTR_WIDTH+:PTR_WIDTH] = r_gray_words[stage];
        assign w_gray_stages[stage*PTR_WIDTH+:PTR_WIDTH] = w_gray_words[stage];
        assign r_up_stages[stage] = r_up_words[stage];
        assign w_up_stages[stage] = w_up_words[stage];
    end
    async_fifo_coverage #(
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) u_state (
        .*
    );
    async_fifo_timing_coverage #(
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES)
    ) u_timing (
        .i_w_clk(i_w_clk),
        .i_r_clk(i_r_clk),
        .i_w_rstb(i_w_rstb),
        .i_r_rstb(i_r_rstb),
        .i_w_valid(i_w_valid),
        .o_w_ready(o_w_ready),
        .o_r_valid(o_r_valid),
        .i_r_ready(i_r_ready),
        .o_w_init_done(o_w_init_done),
        .o_r_init_done(o_r_init_done),
        .w_up(w_up),
        .r_up(r_up),
        .w_seen_remote(w_seen_remote),
        .r_seen_remote(r_seen_remote),
        .w_bin(w_bin),
        .r_bin(r_bin)
    );
endmodule
`endif
