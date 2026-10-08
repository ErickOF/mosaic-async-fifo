`timescale 1ns / 1ps
`ifndef MOSAIC_FORMAL
// Passive simulation timing observations. No requested test mode is credited.
module async_fifo_timing_coverage #(
    parameter int unsigned DEPTH = 8,
    parameter int unsigned SYNC_STAGES = 2,
    localparam int unsigned PTR_WIDTH = $clog2(DEPTH) + 1
) (
    input logic i_w_clk,
    i_r_clk,
    i_w_rstb,
    i_r_rstb,
    input logic i_w_valid,
    o_w_ready,
    o_r_valid,
    i_r_ready,
    input logic o_w_init_done,
    o_r_init_done,
    input logic w_up,
    r_up,
    w_seen_remote,
    r_seen_remote,
    input logic [PTR_WIDTH-1:0] w_bin,
    r_bin
);
    wire operational = i_w_rstb && i_r_rstb && o_w_init_done && o_r_init_done;
    wire both_initialized = o_w_init_done && o_r_init_done;
    wire [PTR_WIDTH-1:0] occupancy = w_bin - r_bin;
    realtime last_w_fall, last_r_fall, w_period, r_period;
    int unsigned w_edges, r_edges;
    bit w_period_known, r_period_known, w_fall_seen, r_fall_seen;
    bit reset_active;
    int init_order;
    realtime first_init_time;
    bit first_w_seen, first_r_seen, first_reported;
    realtime first_w_time, first_r_time;

    initial begin
        last_w_fall = 0;
        last_r_fall = 0;
        w_period = 0;
        r_period = 0;
        w_edges = 0;
        r_edges = 0;
        w_period_known = 0;
        r_period_known = 0;
        w_fall_seen = 0;
        r_fall_seen = 0;
        reset_active = 0;
        init_order = -1;
        first_init_time = 0;
        first_w_seen = 0;
        first_r_seen = 0;
        first_reported = 0;
        first_w_time = 0;
        first_r_time = 0;
    end

    always @(posedge i_w_clk) w_edges++;
    always @(posedge i_r_clk) r_edges++;
    // Completed falling-edge periods are stable before the next rising sample.
    always @(negedge i_w_clk) begin
        if (w_fall_seen) begin
            w_period = $realtime - last_w_fall;
            w_period_known = 1;
        end
        last_w_fall = $realtime;
        w_fall_seen = 1;
    end
    always @(negedge i_r_clk) begin
        if (r_fall_seen) begin
            r_period = $realtime - last_r_fall;
            r_period_known = 1;
        end
        last_r_fall = $realtime;
        r_fall_seen = 1;
    end

    // 0 write faster, 1 equal completed periods, 2 read faster, 3 write
    // inactive, 4 read inactive. Unknown startup history is never credited.
    function automatic int clock_relation();
        if (!w_period_known || !r_period_known) return -1;
        if ($realtime - last_w_fall > 2.0 * w_period) return 3;
        if ($realtime - last_r_fall > 2.0 * r_period) return 4;
        if (w_period < r_period) return 0;
        if (w_period == r_period) return 1;
        return 2;
    endfunction
    function automatic int occupancy_boundary();
        if (occupancy == '0) return 0;
        if (occupancy == PTR_WIDTH'(DEPTH)) return 2;
        return 1;
    endfunction
    // COV-001 applies only to generated covergroup definitions, not observers.
    /* verilator lint_off VARHIDDEN */
    /* verilator lint_off UNUSEDSIGNAL */
    `define FIFO_CLOCK_CG(NAME) \
    covergroup NAME with function sample(int relation, int boundary, int stages); \
        option.per_instance = 1; \
        ratio: coverpoint relation { \
            bins write_faster = {0}; bins equal_periods = {1}; bins read_faster = {2}; \
            bins write_inactive = {3}; bins read_inactive = {4}; \
        } \
        occupancy_state: coverpoint boundary { \
            bins empty = {0}; bins partial = {1}; bins full = {2}; \
        } \
        sync_depth: coverpoint stages { bins current_depth = {SYNC_STAGES}; } \
        clock_occupancy: cross ratio, occupancy_state; \
        depth_ratio: cross sync_depth, ratio; \
    endgroup
    `FIFO_CLOCK_CG(write_clock_cg)
    `FIFO_CLOCK_CG(read_clock_cg)
    `undef FIFO_CLOCK_CG
    covergroup reset_cg with function sample (int state, int order, int stopped);
        option.per_instance = 1;
        occupancy_state: coverpoint state {
            bins uninitialized = {0}; bins empty = {1}; bins partial = {2}; bins full = {3};
        }
        assertion_order: coverpoint order {
            bins simultaneous = {0}; bins write_first = {1}; bins read_first = {2};
        }
        clock_activity: coverpoint stopped {
            bins both_running = {0};
            bins write_inactive = {1};
            bins read_inactive = {2};
            bins both_inactive = {3};
        }
        reset_state_skew_stop: cross occupancy_state, assertion_order, clock_activity;
    endgroup
    covergroup init_cg with function sample (int order, int direction);
        option.per_instance = 1;
        initialization_order: coverpoint order {
            bins write_first = {0}; bins read_first = {1}; bins simultaneous = {2};
        }
        transfer_direction: coverpoint direction {
            bins write_first = {0}; bins read_first = {1}; bins simultaneous = {2};
        }
        init_first_transfer: cross initialization_order, transfer_direction;
    endgroup
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on VARHIDDEN */
    write_clock_cg write_clock;
    read_clock_cg read_clock;
    reset_cg reset_events;
    init_cg init_events;
    initial begin
        write_clock  = new;
        read_clock   = new;
        reset_events = new;
        init_events  = new;
    end
    always @(posedge i_w_clk) begin
        if (operational && clock_relation() >= 0)
            write_clock.sample(clock_relation(), occupancy_boundary(), SYNC_STAGES);
    end
    always @(posedge i_r_clk) begin
        if (operational && clock_relation() >= 0)
            read_clock.sample(clock_relation(), occupancy_boundary(), SYNC_STAGES);
    end

    // Snapshot pre-NBA pointer state on the first assertion of a canceled
    // epoch. Observe actual edges in a bounded reset window, including when
    // both clocks stop. A lack of edges is an observation, not a run-mode hint.
    task automatic observe_reset(input int state, input int order);
        int unsigned before_w, before_r;
        realtime window;
        #1ps;
        before_w = w_edges;
        before_r = r_edges;
        window   = 2.0 * (w_period > r_period ? w_period : r_period);
        if (window < 32.0) window = 32.0;
        // Runtime bound above excludes zero delay. Simulation-only, TB-001.
        /* verilator lint_off ZERODLY */
        #(window);
        /* verilator lint_on ZERODLY */
        reset_events.sample(state, order,
                            int'(w_edges == before_w) + 2 * int'(r_edges == before_r));
    endtask
    always @(negedge i_w_rstb or negedge i_r_rstb or posedge both_initialized) begin
        if (both_initialized && i_w_rstb && i_r_rstb) reset_active = 0;
        else if ((!i_w_rstb || !i_r_rstb) && !reset_active) begin
            int state, order;
            reset_active = 1;
            state = w_up && r_up && w_seen_remote && r_seen_remote ? occupancy_boundary() + 1 : 0;
            order = !i_w_rstb && !i_r_rstb ? 0 : !i_w_rstb ? 1 : 2;
            fork
                observe_reset(state, order);
            join_none
        end
    end
    // Ties require the same actual assertion time, not a requested release
    // order. Domain-up propagation may reverse reset release and init order.
    always @(posedge o_w_init_done or posedge o_r_init_done or
        negedge i_w_rstb or negedge i_r_rstb) begin
        if (!i_w_rstb || !i_r_rstb) init_order = -1;
        else if (init_order == -1) begin
            first_init_time = $realtime;
            init_order = both_initialized ? 2 : o_w_init_done ? 0 : 1;
        end else if ($realtime == first_init_time && both_initialized) init_order = 2;
    end
    always @(posedge i_w_clk or negedge i_w_rstb or negedge i_r_rstb) begin
        if (!i_w_rstb || !i_r_rstb) first_w_seen <= 0;
        else if (!first_w_seen && i_w_valid && o_w_ready) begin
            first_w_seen <= 1;
            first_w_time <= $realtime;
        end
    end
    always @(posedge i_r_clk or negedge i_w_rstb or negedge i_r_rstb) begin
        if (!i_w_rstb || !i_r_rstb) first_r_seen <= 0;
        else if (!first_r_seen && o_r_valid && i_r_ready) begin
            first_r_seen <= 1;
            first_r_time <= $realtime;
        end
    end
    function automatic int first_direction();
        if (first_w_seen && first_r_seen && first_w_time == first_r_time) return 2;
        if (first_w_seen && (!first_r_seen || first_w_time < first_r_time)) return 0;
        return 1;
    endfunction
    // The next falling edge sees settled first-transfer timestamps, even for
    // coincident active edges. Read-first/tie bins remain visible, not waived.
    always @(negedge i_w_clk or negedge i_r_clk or negedge i_w_rstb or negedge i_r_rstb) begin
        if (!i_w_rstb || !i_r_rstb) first_reported <= 0;
        else if (!first_reported && (first_w_seen || first_r_seen)) begin
            init_events.sample(init_order, first_direction());
            first_reported <= 1;
        end
    end
endmodule
`endif
