`timescale 1ns / 1ps
// Independent multiclock queue model. Safety does not assume clock fairness.
module async_fifo_formal #(
    parameter int unsigned DATA_WIDTH = 1,
    parameter int unsigned DEPTH = 2,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1,
    parameter bit RUNTIME_RESET = 0,
    parameter bit VARIABLE_CAPTURE = 0
);
    localparam int unsigned ADDR_WIDTH  = $clog2(DEPTH);
    localparam int unsigned PTR_WIDTH   = ADDR_WIDTH + 1;
    localparam int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1);
    // Include the sticky peer-shutdown edge after the final synchronized sample.
    localparam int unsigned RESET_EDGES = SYNC_STAGES + int'(VARIABLE_CAPTURE) + 1;
    logic i_w_clk = 0, i_r_clk = 0;
    logic [3:0] startup = 0;
    (* anyseq *) logic w_tick, r_tick;
    (* anyseq *) logic i_w_valid, i_r_ready;
    (* anyseq *) logic [DATA_WIDTH-1:0] i_w_data;
    wire i_w_rstb, i_r_rstb;
    wire w_step = startup < 8 || w_tick;
    wire r_step = startup < 8 || r_tick;
    wire w_rise = w_step && !i_w_clk;
    wire r_rise = r_step && !i_r_clk;
    logic [$clog2(RESET_EDGES+1)-1:0] w_reset_peer_edges = 0, r_reset_peer_edges = 0;
    wire o_w_ready, o_w_full, o_w_almost_full, o_w_init_done;
    wire o_r_valid, o_r_empty, o_r_almost_empty, o_r_init_done;
    wire [DATA_WIDTH-1:0] o_r_data;
    wire [LEVEL_WIDTH-1:0] o_w_level, o_r_level;

    always @($global_clock) begin
        if (startup < 15) startup <= startup + 1'b1;
        if (w_step) i_w_clk <= !i_w_clk;
        if (r_step) i_r_clk <= !i_r_clk;
        if (i_w_rstb) w_reset_peer_edges <= 0;
        else if (r_rise && w_reset_peer_edges < RESET_EDGES)
            w_reset_peer_edges <= w_reset_peer_edges + 1'b1;
        if (i_r_rstb) r_reset_peer_edges <= 0;
        else if (w_rise && r_reset_peer_edges < RESET_EDGES)
            r_reset_peer_edges <= r_reset_peer_edges + 1'b1;
    end

    if (RUNTIME_RESET) begin : g_runtime_reset
        (* anyseq *) logic request_w_reset, request_r_reset;
        logic w_reset = 0, r_reset = 0;
        assign i_w_rstb = w_reset;
        assign i_r_rstb = r_reset;
        // Assertion is independent of either clock. Release is on a local
        // falling edge after the peer could observe shutdown, or while the
        // peer is also reset. This is an environment contract, not a DUT fact.
        always @($global_clock) begin
            if (startup < 6 || request_w_reset) w_reset <= 0;
            else if (i_w_clk && w_step && (!i_r_rstb || w_reset_peer_edges == RESET_EDGES))
                w_reset <= 1;
            if (startup < 6 || request_r_reset) r_reset <= 0;
            else if (i_r_clk && r_step && (!i_w_rstb || r_reset_peer_edges == RESET_EDGES))
                r_reset <= 1;
        end
    end else begin : g_startup_reset
        assign i_w_rstb = startup >= 6;
        assign i_r_rstb = startup >= 6;
    end

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL),
        .FORMAL_RUNTIME_RESET(RUNTIME_RESET),
        .FORMAL_VARIABLE_CAPTURE(VARIABLE_CAPTURE)
    ) dut (
        .*
    );

    // Any raw reset cancels the reference epoch. A fresh epoch needs overlapping
    // raw resets, but not simultaneous init_done: writes can initialize first.
    // No reference address or epoch decision reads internal DUT state.
    logic global_history = 0, joint_reset_seen = 0;
    always @($global_clock) begin
        global_history <= 1;
        if (!i_w_rstb && !i_r_rstb) joint_reset_seen <= 1;
        else if (global_history && (($past(
                i_w_rstb
            ) && !i_w_rstb) || ($past(
                i_r_rstb
            ) && !i_r_rstb)))
            joint_reset_seen <= 0;
    end
    wire reference_active = joint_reset_seen && i_w_rstb && i_r_rstb;
    wire reference_rstb = i_w_rstb && i_r_rstb;
    logic [DATA_WIDTH-1:0] reference_memory[DEPTH];
    logic [PTR_WIDTH-1:0] reference_w = 0, reference_r = 0;
    logic producer_past_valid = 0;
    wire [PTR_WIDTH-1:0] occupancy = reference_w - reference_r;
    always @(posedge i_w_clk or negedge reference_rstb) begin
        if (!reference_rstb) begin
            reference_w <= 0;
            producer_past_valid <= 0;
        end else begin
            producer_past_valid <= reference_active;
            if (reference_active && i_w_valid && o_w_ready) reference_w <= reference_w + 1'b1;
        end
    end
    always @(posedge i_w_clk) begin
        if (reference_active) begin
            if (producer_past_valid && $past(
                    reference_active && o_w_init_done && i_w_valid && !o_w_ready
                )) begin
                assume (i_w_valid && i_w_data == $past(i_w_data));
            end
            if (reference_active && o_w_init_done) begin
                assert (occupancy <= PTR_WIDTH'(DEPTH));
                assert (PTR_WIDTH'(o_w_level) >= occupancy);
            end
            if (reference_active && i_w_valid && o_w_ready) begin
                assert (occupancy < PTR_WIDTH'(DEPTH));
                reference_memory[reference_w[ADDR_WIDTH-1:0]] <= i_w_data;
            end
        end
    end
    always @(posedge i_r_clk or negedge reference_rstb) begin
        if (!reference_rstb) reference_r <= 0;
        else if (reference_active && o_r_valid && i_r_ready) reference_r <= reference_r + 1'b1;
    end
    always @(posedge i_r_clk) begin
        if (reference_active) begin
            if (o_r_init_done) begin
                assert (occupancy <= PTR_WIDTH'(DEPTH));
                assert (PTR_WIDTH'(o_r_level) <= occupancy);
            end
            if (o_r_valid) begin
                assert (occupancy != 0);
                assert (o_r_data == reference_memory[reference_r[ADDR_WIDTH-1:0]]);
            end
        end
    end
    always @(posedge i_w_clk) begin
        cover (reference_active && o_w_init_done && o_w_full);
        cover (reference_active && reference_w[PTR_WIDTH-1]);
    end
    always @(posedge i_r_clk) begin
        cover (reference_active && o_r_init_done && o_r_valid && !i_r_ready);
        cover (reference_active && reference_r[PTR_WIDTH-1]);
    end

    if (RUNTIME_RESET) begin : g_reset_obligations
        logic canceled_w = 0, canceled_r = 0, canceled_both = 0;
        logic canceled_empty = 0, canceled_partial = 0, canceled_full = 0;
        logic canceled_stall = 0;
        logic recovered_write = 0, recovered_read = 0;
        logic [1:0] cancellations = 0;
        logic [2:0] w_stopped = 0, r_stopped = 0;
        always @($global_clock) begin
            if (w_step) w_stopped <= 0;
            else if (w_stopped < 7) w_stopped <= w_stopped + 1'b1;
            if (r_step) r_stopped <= 0;
            else if (r_stopped < 7) r_stopped <= r_stopped + 1'b1;
            if (global_history && $past(
                    reference_active && o_w_init_done && o_r_init_done
                ) && !reference_active) begin
                canceled_w <= !i_w_rstb && i_r_rstb;
                canceled_r <= i_w_rstb && !i_r_rstb;
                canceled_both <= !i_w_rstb && !i_r_rstb;
                canceled_empty <= $past(occupancy) == 0;
                canceled_partial <= $past(occupancy) > 0 && $past(occupancy) < DEPTH;
                canceled_full <= $past(occupancy) == DEPTH;
                canceled_stall <= $past(o_r_valid && !i_r_ready);
                if (cancellations < 3) cancellations <= cancellations + 1'b1;
                recovered_write <= 0;
                recovered_read  <= 0;
            end
            if (cancellations != 0 && reference_active && w_rise && i_w_valid && o_w_ready)
                recovered_write <= 1;
            if (cancellations != 0 && reference_active && r_rise && o_r_valid && i_r_ready)
                recovered_read <= 1;

            // Bounded observation, conditional on actual destination edges.
            // These assertions make no eventual-progress/fairness claim.
            if (!i_w_rstb && i_r_rstb && w_reset_peer_edges == RESET_EDGES)
                assert (!o_r_init_done && !o_r_valid);
            if (!i_r_rstb && i_w_rstb && r_reset_peer_edges == RESET_EDGES)
                assert (!o_w_init_done && !o_w_ready);

            cover (canceled_empty);
            cover (canceled_partial);
            cover (canceled_full);
            cover (canceled_stall);
            cover (canceled_both);
            cover (canceled_w && !i_w_rstb && w_stopped >= 3);
            cover (canceled_r && !i_r_rstb && r_stopped >= 3);
            cover (canceled_both && !i_w_rstb && !i_r_rstb && w_stopped >= 3 && r_stopped >= 3);
            cover (canceled_w && !i_w_rstb && i_r_rstb && w_reset_peer_edges == RESET_EDGES);
            cover (canceled_r && i_w_rstb && !i_r_rstb && r_reset_peer_edges == RESET_EDGES);
            cover (canceled_w && i_w_rstb && i_r_rstb && !o_r_init_done);
            cover (canceled_r && i_w_rstb && i_r_rstb && !o_w_init_done);
            cover (recovered_write && recovered_read);
            cover (cancellations >= 2 && recovered_read);
        end
    end
endmodule
