`timescale 1ns / 1ps
`ifndef MOSAIC_FORMAL
// The simulator accepts unpacked array ports. Pack observation data here so
// the same behavioral checker also works with the Yosys formal frontend.
module async_fifo_sim_checker #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH = 8,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1,
    localparam int unsigned PTR_WIDTH = (DEPTH >= 2 ? $clog2(DEPTH) : 1) + 1,
    localparam int unsigned LEVEL_WIDTH = DEPTH >= 2 ? $clog2(DEPTH + 1) : 2,
    localparam int unsigned PAYLOAD_WIDTH = DATA_WIDTH > 0 ? DATA_WIDTH : 1,
    localparam int unsigned STORAGE_DEPTH = DEPTH >= 2 ? DEPTH : 2
) (
    input logic i_w_clk,
    i_w_rstb,
    i_w_valid,
    o_w_ready,
    o_w_full,
    o_w_almost_full,
    o_w_init_done,
    input logic [PAYLOAD_WIDTH-1:0] i_w_data,
    input logic [LEVEL_WIDTH-1:0] o_w_level,
    input logic i_r_clk,
    i_r_rstb,
    o_r_valid,
    i_r_ready,
    o_r_empty,
    o_r_almost_empty,
    o_r_init_done,
    input logic [PAYLOAD_WIDTH-1:0] o_r_data,
    input logic [LEVEL_WIDTH-1:0] o_r_level,
    input logic [PTR_WIDTH-1:0] w_bin,
    w_gray,
    r_bin,
    r_gray,
    r_gray_final,
    w_gray_final,
    input logic r_up_final,
    w_up_final,
    w_up,
    r_up,
    w_seen_remote,
    r_seen_remote,
    push,
    pop,
    r_data_enable,
    input logic [PAYLOAD_WIDTH-1:0] r_data_next,
    input logic [PAYLOAD_WIDTH-1:0] storage_words[STORAGE_DEPTH]
);
    wire [STORAGE_DEPTH*PAYLOAD_WIDTH-1:0] storage_snapshot;
    for (genvar word_index = 0; word_index < STORAGE_DEPTH; word_index++) begin : g_observation
        assign storage_snapshot[word_index*PAYLOAD_WIDTH+:PAYLOAD_WIDTH] = storage_words[word_index];
    end

    async_fifo_sva #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) u_behavior (
        .*
    );
endmodule
`endif
