`timescale 1ns / 1ps
module async_fifo_tb #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH = 8,
    parameter int unsigned SYNC_STAGES = 2,
    parameter int unsigned ALMOST_FULL_LEVEL = DEPTH - 1,
    parameter int unsigned ALMOST_EMPTY_LEVEL = 1
);
    localparam int unsigned LEVEL_WIDTH = $clog2(DEPTH + 1);
    logic i_w_clk, i_r_clk;
    logic i_w_rstb, i_r_rstb;
    logic i_w_valid, i_r_ready;
    logic [DATA_WIDTH-1:0] i_w_data, o_r_data;
    logic o_w_ready, o_w_full, o_w_almost_full, o_w_init_done;
    logic o_r_valid, o_r_empty, o_r_almost_empty, o_r_init_done;
    logic [LEVEL_WIDTH-1:0] o_w_level, o_r_level;
    logic [DATA_WIDTH-1:0] expected_queue[$];
    int w_period = 3, r_period = 5;
    bit w_run = 0, r_run = 1;
    int source_mode = 0, sink_mode = 0;
    int unsigned next_record, pushed, popped, cancelled;
    int unsigned random_w, random_r;
    bit accounting = 0;
    bit source_accepted;
    int full_hits, empty_hits, stall_hits;
    int w_wraps, r_wraps;
    int unsigned w_edges, r_edges, drift_read_edges;
    int unsigned scenario_hits[string];
    bit equal_phase_drift = 0;
    time last_write_rise, drift_start_time;
    string required_scenarios[] = '{
        "stopped_startup_write",
        "stopped_startup_read",
        "skewed_assert_write_first",
        "skewed_assert_read_first",
        "equal_phase_drift",
        "equal_drift_write",
        "equal_drift_read",
        "equal_drift_slow_edges",
        "equal_drift_fast_edges",
        "equal_drift_phase_0",
        "equal_drift_phase_1",
        "equal_drift_phase_2",
        "equal_drift_phase_3",
        "equal_drift_phase_4",
        "reset_stop_w_w_first",
        "reset_stop_w_r_first",
        "reset_stop_r_w_first",
        "reset_stop_r_r_first",
        "reset_stop_both_w_first",
        "reset_stop_both_r_first"
    };
    time scoreboard_time = '1;
    int pre_edge_level = 0;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .SYNC_STAGES(SYNC_STAGES),
        .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
        .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
    ) dut (
        .*
    );

    // Periods vary at runtime but are strictly positive in every scenario.
    // This waiver is simulation-only and never changes the RTL lint policy.
    /* verilator lint_off ZERODLY */
    initial
        forever begin
            #(w_period);
            if (w_run) i_w_clk = !i_w_clk;
            else i_w_clk = 0;
        end
    initial begin
        int delay_ns;
        bit drift_interval;
        #1;
        forever begin
            delay_ns = r_period;
            drift_interval = equal_phase_drift;
            if (drift_interval) begin
                if (drift_read_edges == 0) drift_start_time = $time;
                delay_ns += drift_read_edges % 40 < 20 ? 1 : -1;
            end
            #(delay_ns);
            if (r_run) i_r_clk = !i_r_clk;
            else i_r_clk = 0;
            if (r_run && drift_interval) begin
                if (equal_phase_drift)
                    scenario_hits[drift_read_edges % 40 < 20 ?
                        "equal_drift_slow_edges" : "equal_drift_fast_edges"]++;
                drift_read_edges++;
            end
        end
    end

    always @(i_w_clk) w_edges++;
    always @(i_r_clk) r_edges++;

    function automatic logic [DATA_WIDTH-1:0] record_pattern(input int unsigned record_id);
        logic [DATA_WIDTH-1:0] pattern;
        for (int bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
            pattern[bit_index] = ((record_id >> (bit_index % 32)) & 1) != 0;
        end
        return pattern;
    endfunction

    always @(negedge i_w_clk) begin
        random_w = (random_w << 1) ^ (random_w[31] ? 32'h04c11db7 : 32'h0);
        if (!i_w_rstb || !accounting) begin
            i_w_valid = 0;
        end else if (!i_w_valid || source_accepted) begin
            i_w_valid = source_mode == 1 || (source_mode == 2 && random_w[2:0] != 0);
            i_w_data  = record_pattern(next_record);
        end
    end
    always @(negedge i_r_clk) begin
        random_r  = (random_r << 1) ^ (random_r[31] ? 32'h04c11db7 : 32'h0);
        i_r_ready = accounting && (sink_mode == 1 || (sink_mode == 2 && random_r[2:0] > 2));
    end

    // Both coincident edges must see the same occupancy before either handshake.
    task automatic snapshot_level;
        if (scoreboard_time != $time) begin
            scoreboard_time = $time;
            pre_edge_level  = expected_queue.size();
        end
    endtask

    // The model records handshakes only, never DUT pointers or memory contents.
    always @(posedge i_w_clk) begin
        last_write_rise = $time;
        snapshot_level();
        source_accepted = i_w_valid && o_w_ready;
        if (accounting && o_w_init_done) begin
            if (int'(o_w_level) < pre_edge_level || int'(o_w_level) > DEPTH)
                $fatal(1, "write estimate is not conservative");
            if (o_w_almost_full != (o_w_level >= LEVEL_WIDTH'(ALMOST_FULL_LEVEL)))
                $fatal(1, "almost-full threshold mismatch");
            if (o_w_full) full_hits++;
        end
        if (accounting && i_w_valid && o_w_ready) begin
            if (expected_queue.size() >= DEPTH) $fatal(1, "overflow");
            expected_queue.push_back(i_w_data);
            next_record++;
            pushed++;
            if ((pushed % DEPTH) == 0) w_wraps++;
            if (equal_phase_drift) scenario_hits["equal_drift_write"]++;
        end
    end
    always @(posedge i_r_clk) begin
        logic [DATA_WIDTH-1:0] expected;
        if (equal_phase_drift) begin
            scenario_hits[
                $sformatf("equal_drift_phase_%0d", int'(($time-last_write_rise)%(2*w_period))/2)]++;
        end
        snapshot_level();
        if (accounting && o_r_init_done) begin
            if (int'(o_r_level) > pre_edge_level) $fatal(1, "read estimate is not conservative");
            if (o_r_almost_empty != (o_r_level <= LEVEL_WIDTH'(ALMOST_EMPTY_LEVEL)))
                $fatal(1, "almost-empty threshold mismatch");
            if (o_r_empty) empty_hits++;
            if (o_r_valid && !i_r_ready) stall_hits++;
        end
        if (accounting && o_r_valid && i_r_ready) begin
            if (expected_queue.size() == 0) $fatal(1, "underflow");
            expected = expected_queue.pop_front();
            if (o_r_data !== expected)
                $fatal(1, "FIFO order/data mismatch: expected %h got %h", expected, o_r_data);
            popped++;
            if ((popped % DEPTH) == 0) r_wraps++;
            if (equal_phase_drift) scenario_hits["equal_drift_read"]++;
        end
    end

    task automatic cancel_epoch;
        accounting  = 0;
        source_mode = 0;
        sink_mode   = 0;
        cancelled += expected_queue.size();
        expected_queue.delete();
        i_w_valid = 0;
        i_r_ready = 0;
        source_accepted = 0;
    endtask

    task automatic check_reset_outputs(input bit writer);
        if (writer) begin
            if (i_w_rstb || o_w_init_done || o_w_ready || !o_w_full || o_w_level != '0)
                $fatal(1, "write reset did not force safe public state");
        end else begin
            if (i_r_rstb || o_r_init_done || o_r_valid || !o_r_empty ||
                o_r_level != '0 || o_r_data != '0)
                $fatal(1, "read reset did not force safe public state");
        end
    endtask

    task automatic check_startup_blocked;
        if (o_w_init_done || o_r_init_done || o_w_ready || o_r_valid)
            $fatal(1, "startup accepted traffic without both domains released and clocked");
    endtask

    // Assertion order: zero is simultaneous, one is write first, two is read first.
    task automatic reset_fifo(input bit skew_release = 0, input int assertion_order = 0);
        cancel_epoch();
        if (assertion_order == 0) begin
            i_w_rstb = 0;
            i_r_rstb = 0;
        end else begin
            if (assertion_order == 1) i_w_rstb = 0;
            else i_r_rstb = 0;
            #1ps;
            check_reset_outputs(assertion_order == 1);
            #(2 * (SYNC_STAGES + 4) * (assertion_order == 1 ? r_period : w_period));
            if (assertion_order == 1) begin
                if (o_r_init_done || o_r_valid)
                    $fatal(1, "skewed assertion left reader operational");
                i_r_rstb = 0;
                scenario_hits["skewed_assert_write_first"]++;
            end else begin
                if (o_w_init_done || o_w_ready)
                    $fatal(1, "skewed assertion left writer operational");
                i_w_rstb = 0;
                scenario_hits["skewed_assert_read_first"]++;
            end
        end
        #(20 * (w_period + r_period));
        @(negedge i_w_clk);
        i_w_rstb = 1;
        if (skew_release) #(12 * r_period);
        @(negedge i_r_clk);
        i_r_rstb = 1;
        wait (o_w_init_done && o_r_init_done);
        #(4 * (w_period + r_period));
        accounting = 1;
    endtask

    task automatic pause_clock(input bit writer);
        if (writer) begin
            if (w_run) @(negedge i_w_clk);
            w_run = 0;
        end else begin
            if (r_run) @(negedge i_r_clk);
            r_run = 0;
        end
        #1ps;
    endtask

    task automatic release_reset(input bit writer);
        if (writer) begin
            @(negedge i_w_clk);
            i_w_rstb = 1;
        end else begin
            @(negedge i_r_clk);
            i_r_rstb = 1;
        end
    endtask

    task automatic startup_stopped(input bit writer);
        int unsigned edges;
        pause_clock(writer);
        cancel_epoch();
        i_w_rstb = 0;
        i_r_rstb = 0;
        #1ps;
        check_reset_outputs(1);
        check_reset_outputs(0);
        edges = writer ? w_edges : r_edges;
        #(20 * (w_period + r_period));
        release_reset(!writer);
        #(20 * (w_period + r_period));
        check_startup_blocked();
        if ((writer ? w_edges : r_edges) != edges || (writer ? i_w_clk : i_r_clk))
            $fatal(1, "stopped startup clock changed");
        if (writer) w_run = 1;
        else r_run = 1;
        release_reset(writer);
        wait (o_w_init_done && o_r_init_done);
        #(4 * (w_period + r_period));
        accounting = 1;
        scenario_hits[writer?"stopped_startup_write" : "stopped_startup_read"]++;
    endtask

    task automatic prepare_full_fifo;
        source_mode = 1;
        sink_mode   = 0;
        wait (o_w_full && expected_queue.size() == DEPTH && o_r_valid);
    endtask

    // Cross stopped write/read/both clocks with both reset assertion orders.
    // Restart one domain first, with the other still stopped and held in reset.
    task automatic reset_stopped(input int stopped, input bit first_writer);
        bit early_writer;
        int unsigned before_w, before_r, pending, before_cancel, before_pop;
        string stopped_name;
        prepare_full_fifo();
        if (stopped == 0 || stopped == 2) pause_clock(1);
        if (stopped == 1 || stopped == 2) pause_clock(0);
        before_w = w_edges;
        before_r = r_edges;
        pending = expected_queue.size();
        before_cancel = cancelled;
        cancel_epoch();
        if (first_writer) i_w_rstb = 0;
        else i_r_rstb = 0;
        #1ps;
        check_reset_outputs(first_writer);
        #(2 * (SYNC_STAGES + 4) * (w_period + r_period));
        if (first_writer && r_run && (o_r_init_done || o_r_valid))
            $fatal(1, "running read peer missed reset during clock stop");
        if (!first_writer && w_run && (o_w_init_done || o_w_ready))
            $fatal(1, "running write peer missed reset during clock stop");
        if (first_writer) i_r_rstb = 0;
        else i_w_rstb = 0;
        #1ps;
        check_reset_outputs(!first_writer);
        #(20 * (w_period + r_period));
        if (cancelled != before_cancel + pending) $fatal(1, "stopped reset cancellation mismatch");
        if ((stopped == 0 || stopped == 2) && (w_edges != before_w || i_w_clk))
            $fatal(1, "write clock moved while stopped for reset");
        if ((stopped == 1 || stopped == 2) && (r_edges != before_r || i_r_clk))
            $fatal(1, "read clock moved while stopped for reset");
        check_reset_outputs(1);
        check_reset_outputs(0);

        early_writer = stopped == 2 ? first_writer : stopped == 1;
        if (early_writer) w_run = 1;
        else r_run = 1;
        release_reset(early_writer);
        #(20 * (w_period + r_period));
        check_startup_blocked();
        if ((early_writer ? r_edges : w_edges) != (early_writer ? before_r : before_w))
            $fatal(1, "late startup clock did not remain stopped");
        if (early_writer) r_run = 1;
        else w_run = 1;
        release_reset(!early_writer);
        wait (o_w_init_done && o_r_init_done);
        #(4 * (w_period + r_period));
        accounting  = 1;
        before_pop  = popped;
        source_mode = 1;
        sink_mode   = 1;
        #(80 * DEPTH * (w_period + r_period));
        drain_fifo();
        if (popped == before_pop) $fatal(1, "no checked post-reset records");
        stopped_name = stopped == 2 ? "both" : stopped == 0 ? "w" : "r";
        scenario_hits[$sformatf("reset_stop_%s_%s_first", stopped_name, first_writer?"w" : "r")]++;
    endtask

    task automatic drain_fifo;
        source_mode = 0;
        sink_mode   = 1;
        // One offered record may be held by a stalled producer when drain starts.
        wait (!i_w_valid);
        wait (expected_queue.size() == 0);
        #(12 * (w_period + r_period));
        if (!o_r_empty || o_r_valid) $fatal(1, "drain failed");
    endtask

    initial begin
        i_w_clk = 0;
        i_r_clk = 0;
        // Assert reset explicitly below, so a stopped clock is not needed to
        // initialize reset-to-one state in a two-state simulator.
        i_w_rstb = 1;
        i_r_rstb = 1;
        i_w_valid = 0;
        i_r_ready = 0;
        i_w_data = 0;
        source_accepted = 0;
        next_record = 0;
        pushed = 0;
        popped = 0;
        cancelled = 0;
        random_w = 32'h53a912f1;
        random_r = 32'h7681c032;
        full_hits = 0;
        empty_hits = 0;
        stall_hits = 0;
        w_wraps = 0;
        r_wraps = 0;
        w_edges = 0;
        r_edges = 0;
        drift_read_edges = 0;
        last_write_rise = 0;
        drift_start_time = 0;
        #1;
        // No write edge has occurred before the first stopped-clock startup.
        startup_stopped(1);
        // Fill, stall a valid head, then reset while full.
        source_mode = 1;
        sink_mode   = 0;
        wait (o_w_full && expected_queue.size() == DEPTH);
        #(20 * (w_period + r_period));
        reset_fifo(1);

        startup_stopped(0);
        for (int order = 1; order <= 2; order++) begin
            prepare_full_fifo();
            reset_fifo(1, order);
        end

        // A prefetched array of visible records must pop without output bubbles.
        source_mode = 1;
        sink_mode   = 0;
        wait (expected_queue.size() == DEPTH && o_r_level == LEVEL_WIDTH'(DEPTH));
        source_mode = 0;
        sink_mode   = 1;
        @(negedge i_r_clk);
        for (int record_index = 0; record_index < DEPTH; record_index++) begin
            @(posedge i_r_clk);
            if (!o_r_valid || !i_r_ready) $fatal(1, "registered output inserted a bubble");
        end
        drain_fifo();

        // Reset a partially filled FIFO with a held output offer.
        source_mode = 1;
        sink_mode   = 0;
        wait (expected_queue.size() >= DEPTH / 2 && o_r_valid);
        reset_fifo();

        // Exercise several asynchronous frequency ratios, phase walks, and wraps.
        for (int scenario = 0; scenario < 4; scenario++) begin
            case (scenario)
                0: begin
                    w_period = 2;
                    r_period = 7;
                end
                1: begin
                    w_period = 11;
                    r_period = 3;
                end
                2: begin
                    w_period = 5;
                    r_period = 5;
                end
                3: begin
                    w_period = 7;
                    r_period = 11;
                end
                default: $fatal(1, "invalid test scenario");
            endcase
            source_mode = 2;
            sink_mode   = 2;
            #(600 * DEPTH * (w_period + r_period));
            drain_fifo();
        end

        // Ten slow read cycles and ten fast cycles retain the write clock's
        // nominal frequency while walking relative phase in both directions.
        w_period = 5;
        r_period = 5;
        repeat (4) @(negedge i_r_clk);
        drift_read_edges = 0;
        equal_phase_drift = 1;
        source_mode = 2;
        sink_mode = 2;
        wait (drift_read_edges >= 40 * DEPTH);
        #1ps;
        if ($time - drift_start_time != 200 * DEPTH ||
            scenario_hits["equal_drift_slow_edges"] != 20 * DEPTH ||
            scenario_hits["equal_drift_fast_edges"] != 20 * DEPTH)
            $fatal(1, "phase drift did not preserve the equal mean clock rate");
        equal_phase_drift = 0;
        drain_fifo();
        scenario_hits["equal_phase_drift"]++;

        // Runtime period changes make phase relationships non-periodic.
        source_mode = 2;
        sink_mode   = 2;
        for (int interval_index = 0; interval_index < 100; interval_index++) begin
            w_period = 2 + int'(random_w % 11);
            r_period = 2 + int'(random_r % 13);
            #(20 * (w_period + r_period));
        end
        drain_fifo();

        source_mode = 1;
        sink_mode   = 0;
        @(negedge i_r_clk);
        r_run = 0;
        wait (o_w_full);
        #(40 * w_period);
        r_run = 1;
        drain_fifo();

        source_mode = 1;
        sink_mode   = 1;
        #(80 * (w_period + r_period));
        @(negedge i_w_clk);
        w_run = 0;
        #(80 * r_period);
        w_run = 1;
        drain_fifo();

        w_period = 3;
        r_period = 5;
        for (int stopped = 0; stopped < 3; stopped++) begin
            reset_stopped(stopped, 1);
            reset_stopped(stopped, 0);
        end

        // A one-sided reset cancels traffic and must not self-reinitialize.
        accounting = 0;
        cancelled += expected_queue.size();
        expected_queue.delete();
        i_w_rstb = 0;
        #(20 * (w_period + r_period));
        if (o_r_init_done || o_r_valid) $fatal(1, "peer reset did not disable reader");
        @(negedge i_w_clk);
        i_w_rstb = 1;
        #(20 * (w_period + r_period));
        if (o_w_init_done || o_r_init_done) $fatal(1, "uncoordinated recovery was accepted");
        reset_fifo(1);

        // Exercise the symmetric one-sided read reset while traffic is active.
        source_mode = 1;
        sink_mode   = 0;
        wait (o_r_valid);
        accounting = 0;
        cancelled += expected_queue.size();
        expected_queue.delete();
        i_r_rstb = 0;
        #(20 * (w_period + r_period));
        if (o_w_init_done || o_w_ready) $fatal(1, "peer reset did not disable writer");
        @(negedge i_r_clk);
        i_r_rstb = 1;
        #(20 * (w_period + r_period));
        if (o_w_init_done || o_r_init_done) $fatal(1, "uncoordinated read recovery was accepted");
        reset_fifo();
        source_mode = 1;
        sink_mode   = 1;
        #(80 * DEPTH * (w_period + r_period));
        drain_fifo();

        if (full_hits == 0 || empty_hits == 0 || stall_hits == 0 || w_wraps < 10 || r_wraps < 10)
            $fatal(1, "inadequate boundary/wrap coverage");
        if (pushed != popped + cancelled) $fatal(1, "reset cancellation accounting mismatch");
        foreach (required_scenarios[index]) begin
            string scenario_name;
            scenario_name = required_scenarios[index];
            if (scenario_hits[scenario_name] == 0)
                $fatal(1, "missing required scenario %s", scenario_name);
            $display("SCENARIO_PASS %s hits=%0d", scenario_name, scenario_hits[scenario_name]);
        end
        $display(
            "PASS async_fifo width=%0d depth=%0d sync=%0d pushes=%0d pops=%0d cancelled=%0d wraps=%0d/%0d",
            DATA_WIDTH, DEPTH, SYNC_STAGES, pushed, popped, cancelled, w_wraps, r_wraps);
        $finish;
    end
    initial begin
        #100000000;
        $fatal(1, "asynchronous FIFO regression timed out");
    end
    /* verilator lint_on ZERODLY */
endmodule
