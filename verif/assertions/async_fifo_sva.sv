`timescale 1ns / 1ps
// One checker serves bound simulation and the explicit formal instance.
module async_fifo_sva #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH = 8,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1,
    localparam int unsigned ADDR_WIDTH = DEPTH >= 2 ? $clog2(DEPTH) : 1,
    localparam int unsigned PTR_WIDTH = ADDR_WIDTH + 1,
    localparam int unsigned LEVEL_WIDTH = DEPTH >= 2 ? $clog2(DEPTH + 1) : 2,
    localparam int unsigned PAYLOAD_WIDTH = DATA_WIDTH > 0 ? DATA_WIDTH : 1,
    localparam int unsigned STORAGE_DEPTH = DEPTH >= 2 ? DEPTH : 2
) (
    input logic i_w_clk,
    i_w_rstb,
    i_w_valid,
    o_w_ready,
    o_w_full,
    o_w_init_done,
    input logic [PAYLOAD_WIDTH-1:0] i_w_data,
    input logic o_w_almost_full,
    input logic [LEVEL_WIDTH-1:0] o_w_level,
    input logic i_r_clk,
    i_r_rstb,
    o_r_valid,
    i_r_ready,
    o_r_empty,
    o_r_init_done,
    input logic [PAYLOAD_WIDTH-1:0] o_r_data,
    input logic o_r_almost_empty,
    input logic [LEVEL_WIDTH-1:0] o_r_level,
    input logic [PTR_WIDTH-1:0] w_bin,
    w_gray,
    r_bin,
    r_gray,
    input logic [PTR_WIDTH-1:0] r_gray_final,
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
    input logic [STORAGE_DEPTH*PAYLOAD_WIDTH-1:0] storage_snapshot
);
    wire [PTR_WIDTH-1:0] predicted_write_pointer, predicted_read_pointer;
    wire [PTR_WIDTH-1:0] predicted_write_gray, predicted_read_gray;
    wire [PTR_WIDTH-1:0] observed_write_pointer, observed_read_pointer;
    wire predicted_full, predicted_empty;
    wire [LEVEL_WIDTH-1:0] predicted_write_level, predicted_read_level;
    `include "async_fifo_predicates.svh"

    assign predicted_write_pointer = expected_write_pointer();
    assign predicted_read_pointer = expected_read_pointer();
    assign predicted_write_gray = binary_to_gray(predicted_write_pointer);
    assign predicted_read_gray = binary_to_gray(predicted_read_pointer);
    assign observed_write_pointer = gray_to_binary(w_gray_final);
    assign observed_read_pointer = gray_to_binary(r_gray_final);
    assign predicted_full = expected_full();
    assign predicted_empty = expected_empty();
    assign predicted_write_level = expected_write_level();
    assign predicted_read_level = expected_read_level();

`ifdef MOSAIC_FOUR_STATE
    // The pinned four-state engine cannot parse concurrent SVA. These immediate
    // monitors use exactly the predicates consumed by SVA-capable simulators.
`ifndef FIFO_DISABLE_CONTROL_MONITOR
    always @(posedge i_w_clk) begin
        if (i_w_rstb === 1'b1 && !write_synchronizers_known_now())
            $fatal(1, "UNKNOWN_SYNCHRONIZER_DETECTED write");
        if (!write_controls_known_now())
            $fatal(
                1,
                "UNKNOWN_CONTROL_DETECTED write %b",
                {
                    i_w_rstb, i_w_valid, o_w_ready, o_w_full, o_w_init_done
                }
            );
    end
    always @(posedge i_r_clk) begin
        if (i_r_rstb === 1'b1 && !read_synchronizers_known_now())
            $fatal(1, "UNKNOWN_SYNCHRONIZER_DETECTED read");
        if (!read_controls_known_now())
            $fatal(
                1,
                "UNKNOWN_CONTROL_DETECTED read %b",
                {
                    i_r_rstb, i_r_ready, o_r_valid, o_r_empty, o_r_init_done
                }
            );
    end
`endif
`elsif MOSAIC_YOSYS_FORMAL
    logic w_past_valid = 0, r_past_valid = 0;
    // Reset can assert and release while a local clock is stopped. Invalidate
    // local temporal obligations on assertion, not only on a sampled low reset.
    always @(posedge i_w_clk or negedge i_w_rstb) begin
        if (!i_w_rstb) w_past_valid <= 0;
        else w_past_valid <= 1;
    end
    always @(posedge i_r_clk or negedge i_r_rstb) begin
        if (!i_r_rstb) r_past_valid <= 0;
        else r_past_valid <= 1;
    end
    logic global_past_valid = 0;
    always @($global_clock) begin
        global_past_valid <= 1;
        // One global observation after assertion sees settled asynchronous
        // state, even without a local edge. Release is modeled separately.
        if (global_past_valid && !i_w_rstb && !$past(i_w_rstb)) assert (write_reset_state());
        if (global_past_valid && !i_r_rstb && !$past(i_r_rstb)) assert (read_reset_state());
    end
    always @(posedge i_w_clk) begin
        if (i_w_rstb) begin
            assert (o_w_ready == (o_w_init_done && !o_w_full));
            assert (push == (i_w_valid && o_w_ready));
            assert (!push || (o_w_init_done && !o_w_full));
            assert (!o_w_init_done || (w_up && r_up_final));
            assert (w_gray == binary_to_gray(w_bin));
            assert (o_w_almost_full ==
                (o_w_init_done && o_w_level >= LEVEL_WIDTH'(ALMOST_FULL_LEVEL)));
            if (live_epoch() && push) assert (live_distance() < PTR_WIDTH'(DEPTH));
            if (w_seen_remote && !w_up) assert (!o_w_init_done && !o_w_ready && !push);
            assert (!o_w_ready || o_w_level < DEPTH);
            if (o_w_init_done) assert (o_w_level <= DEPTH);
            if (w_past_valid && $past(i_w_rstb)) begin
                assert (w_bin == $past(w_bin) + PTR_WIDTH'($past(i_w_valid && o_w_ready)));
                assert (gray_single_step(w_gray ^ $past(w_gray)));
                assert (o_w_full == $past(predicted_full));
                assert (o_w_level == $past(predicted_write_level));
                if ($past(w_seen_remote && !r_up_final)) assert (!w_up);
                if ($past(w_seen_remote && !w_up)) assert (!w_up);
                if ($past(w_seen_remote)) assert (w_seen_remote);
            end
        end
    end
    always @(posedge i_r_clk) begin
        if (i_r_rstb) begin
            assert (o_r_valid == (o_r_init_done && !o_r_empty));
            assert (pop == (o_r_valid && i_r_ready));
            assert (!pop || (o_r_init_done && !o_r_empty));
            assert (!o_r_init_done || (r_up && w_up_final));
            assert (r_gray == binary_to_gray(r_bin));
            assert (r_data_enable == expected_read_load());
            assert (o_r_almost_empty ==
                (!o_r_init_done || o_r_level <= LEVEL_WIDTH'(ALMOST_EMPTY_LEVEL)));
            if (live_epoch() && pop) assert (live_distance() != 0);
            if (r_seen_remote && !r_up) assert (!o_r_init_done && !o_r_valid && !pop);
            assert (!o_r_valid || o_r_level > 0);
            if (o_r_init_done) assert (o_r_level <= DEPTH);
            if (r_past_valid && $past(i_r_rstb)) begin
                assert (r_bin == $past(r_bin) + PTR_WIDTH'($past(o_r_valid && i_r_ready)));
                assert (gray_single_step(r_gray ^ $past(r_gray)));
                assert (o_r_empty == $past(predicted_empty));
                assert (o_r_level == $past(predicted_read_level));
                if ($past(r_data_enable))
                    assert (o_r_data == $past(r_data_next));
                    else assert (o_r_data == $past(o_r_data));
                if ($past(r_seen_remote && !w_up_final)) assert (!r_up);
                if ($past(r_seen_remote && !r_up)) assert (!r_up);
                if ($past(r_seen_remote)) assert (r_seen_remote);
                if ($past(o_r_init_done && o_r_valid && !i_r_ready) && o_r_init_done) begin
                    assert (o_r_valid && o_r_data == $past(o_r_data));
                end
            end
        end
    end
`else
    // A reset can occur entirely between local edges while that clock stops.
    // Clear history asynchronously so no obligation from the old epoch leaks
    // into the first post-reset sample, including in lowered SVA frontends.
    logic w_history_valid, r_history_valid;
    initial begin
        w_history_valid = 0;
        r_history_valid = 0;
    end
    always @(posedge i_w_clk or negedge i_w_rstb) begin
        if (!i_w_rstb) w_history_valid <= 0;
        else w_history_valid <= 1;
    end
    always @(posedge i_r_clk or negedge i_r_rstb) begin
        if (!i_r_rstb) r_history_valid <= 0;
        else r_history_valid <= 1;
    end
    // The pinned simulator does not defer assert-final evaluation past NBA.
    // One precision tick observes settled reset state even with a stopped
    // local clock. This scheduling allowance is not an ASIC timing budget.
    always @(negedge i_w_rstb) begin
        #1ps;
        write_async_reset : assert (write_reset_state());
    end
    always @(negedge i_r_rstb) begin
        #1ps;
        read_async_reset : assert (read_reset_state());
    end
    write_controls_known :
    assert property (@(posedge i_w_clk) write_controls_known_now());
    read_controls_known :
    assert property (@(posedge i_r_clk) read_controls_known_now());
    write_synchronizers_known :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) write_synchronizers_known_now());
    read_synchronizers_known :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) read_synchronizers_known_now());
    write_status :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb)
        o_w_ready == (o_w_init_done && !o_w_full));
    read_status :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        o_r_valid == (o_r_init_done && !o_r_empty));
    write_handshake :
    assert property (@(posedge i_w_clk) push == (i_w_valid && o_w_ready));
    read_handshake :
    assert property (@(posedge i_r_clk) pop == (o_r_valid && i_r_ready));
    write_permission :
    assert property (@(posedge i_w_clk) push |-> i_w_rstb && o_w_init_done && !o_w_full);
    read_permission :
    assert property (@(posedge i_r_clk) pop |-> i_r_rstb && o_r_init_done && !o_r_empty);
    write_init_prerequisites :
    assert property (@(posedge i_w_clk) o_w_init_done |-> i_w_rstb && w_up && r_up_final);
    read_init_prerequisites :
    assert property (@(posedge i_r_clk) o_r_init_done |-> i_r_rstb && r_up && w_up_final);
    write_reset_sample :
    assert property (@(posedge i_w_clk) !i_w_rstb |=> write_reset_state());
    read_reset_sample :
    assert property (@(posedge i_r_clk) !i_r_rstb |=> read_reset_state());
    write_gray_encoding :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) w_gray == binary_to_gray(w_bin));
    read_gray_encoding :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) r_gray == binary_to_gray(r_bin));
    write_full_prediction :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) 1'b1 |=> !w_history_valid || o_w_full == $past(
        predicted_full
    ));
    read_empty_prediction :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) 1'b1 |=> !r_history_valid || o_r_empty == $past(
        predicted_empty
    ));
    write_level_prediction :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) 1'b1 |=> !w_history_valid || o_w_level == $past(
        predicted_write_level
    ));
    read_level_prediction :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) 1'b1 |=> !r_history_valid || o_r_level == $past(
        predicted_read_level
    ));
    write_threshold :
    assert property (@(posedge i_w_clk) o_w_almost_full ==
        (o_w_init_done && o_w_level >= LEVEL_WIDTH'(ALMOST_FULL_LEVEL)));
    read_threshold :
    assert property (@(posedge i_r_clk) o_r_almost_empty ==
        (!o_r_init_done || o_r_level <= LEVEL_WIDTH'(ALMOST_EMPTY_LEVEL)));
    read_load_qualification :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        r_data_enable == expected_read_load());
    output_capture :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        r_data_enable |=> !r_history_valid || o_r_data === $past(
        r_data_next
    ));
    output_idle_hold :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) !r_data_enable |=> !r_history_valid || $stable(
        o_r_data
    ));
    write_live_slot :
    assert property (@(posedge i_w_clk) disable iff (!live_epoch())
        push |-> live_distance() < PTR_WIDTH'(DEPTH));
    read_live_slot :
    assert property (@(posedge i_r_clk) disable iff (!live_epoch()) pop |-> live_distance() != 0);
    write_peer_shutdown :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb)
        w_seen_remote && !r_up_final |=> !w_history_valid || !w_up);
    read_peer_shutdown :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        r_seen_remote && !w_up_final |=> !r_history_valid || !r_up);
    write_shutdown_sticky :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb)
        w_seen_remote && !w_up |=> !w_history_valid || !w_up);
    read_shutdown_sticky :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        r_seen_remote && !r_up |=> !r_history_valid || !r_up);
    write_shutdown_blocks :
    assert property (@(posedge i_w_clk) w_seen_remote && !w_up |->
        !o_w_init_done && !o_w_ready && !push);
    read_shutdown_blocks :
    assert property (@(posedge i_r_clk) r_seen_remote && !r_up |->
        !o_r_init_done && !o_r_valid && !pop);
    write_seen_sticky :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb)
        w_seen_remote |=> !w_history_valid || w_seen_remote);
    read_seen_sticky :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        r_seen_remote |=> !r_history_valid || r_seen_remote);
    write_level_range :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb)
        o_w_init_done |-> o_w_level <= LEVEL_WIDTH'(DEPTH));
    read_level_range :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb)
        o_r_init_done |-> o_r_level <= LEVEL_WIDTH'(DEPTH));
    write_pointer :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) 1'b1 |=> !w_history_valid || w_bin == $past(
        w_bin
    ) + PTR_WIDTH'($past(
        i_w_valid && o_w_ready
    )));
    read_pointer :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) 1'b1 |=> !r_history_valid || r_bin == $past(
        r_bin
    ) + PTR_WIDTH'($past(
        o_r_valid && i_r_ready
    )));
    write_gray :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb) 1'b1 |=> !w_history_valid || gray_single_step(
        w_gray ^ $past(w_gray)
    ));
    read_gray :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb) 1'b1 |=> !r_history_valid || gray_single_step(
        r_gray ^ $past(r_gray)
    ));
    output_hold :
    assert property (@(posedge i_r_clk) disable iff (!i_r_rstb || !i_w_rstb)
        o_r_init_done && o_r_valid && !i_r_ready |=>
        !r_history_valid || !o_r_init_done || (o_r_valid && $stable(
        o_r_data
    )));
    // Reset cancellation explicitly ends the producer's outstanding offer.
    input_hold :
    assert property (@(posedge i_w_clk) disable iff (!i_w_rstb || !i_r_rstb)
        o_w_init_done && i_w_valid && !o_w_ready |=>
        !w_history_valid || !o_w_init_done || (i_w_valid && $stable(
        i_w_data
    )));
`endif

    // Observe each real word. Reset never disables storage hold checks because
    // the payload array is intentionally unreset. Case equality preserves X/Z.
`ifndef MOSAIC_FOUR_STATE
    // Sample the packed array once. This also avoids frontend aliasing of
    // generated $past(word_data) expressions across different memory words.
    logic storage_past_valid;
    initial storage_past_valid = 0;
    logic previous_push;
    logic [ADDR_WIDTH-1:0] previous_write_address;
    logic [PAYLOAD_WIDTH-1:0] previous_write_data;
    logic [STORAGE_DEPTH*PAYLOAD_WIDTH-1:0] previous_storage;
    always @(posedge i_w_clk) begin
        storage_past_valid <= 1;
        previous_push <= push;
        previous_write_address <= w_bin[ADDR_WIDTH-1:0];
        previous_write_data <= i_w_data;
        previous_storage <= storage_snapshot;
    end
    for (genvar word_index = 0; word_index < STORAGE_DEPTH; word_index++) begin : g_storage
        wire [PAYLOAD_WIDTH-1:0] word_data =
            storage_snapshot[word_index*PAYLOAD_WIDTH+:PAYLOAD_WIDTH];
        wire [PAYLOAD_WIDTH-1:0] previous_word_data =
            previous_storage[word_index*PAYLOAD_WIDTH+:PAYLOAD_WIDTH];
        wire previous_word_write = previous_push &&
            previous_write_address == ADDR_WIDTH'(word_index);
`ifdef MOSAIC_YOSYS_FORMAL
        always @(posedge i_w_clk) begin
            if (storage_past_valid) begin
                if (previous_word_write)
                    assert (word_data == previous_write_data);
                    else assert (word_data == previous_word_data);
            end
        end
        always @(posedge i_r_clk) begin
            if (live_epoch() && o_r_valid && r_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(word_index))
                assert (o_r_data == word_data);
        end
`else
        storage_write :
        assert property (@(posedge i_w_clk)
            storage_past_valid && previous_word_write |-> word_data === previous_write_data);
        storage_hold :
        assert property (@(posedge i_w_clk)
            storage_past_valid && !previous_word_write |-> word_data === previous_word_data);
        visible_head :
        assert property (@(posedge i_r_clk) disable iff (!live_epoch())
            o_r_valid && r_bin[ADDR_WIDTH-1:0] == ADDR_WIDTH'(word_index) |->
            o_r_data === word_data);
`endif
    end
`endif
endmodule
