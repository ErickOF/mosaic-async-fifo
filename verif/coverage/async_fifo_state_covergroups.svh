// Distinct types preserve port identities. Each group has one sampling guard.
// The pinned simulator cannot qualify crosses with coverpoint/cross iff.
// Narrow automatic-bin vectors preserve individual native bin identities.
// COV-001 applies only to generated covergroup scaffolding.
/* verilator lint_off VARHIDDEN */
/* verilator lint_off UNUSEDSIGNAL */
`define FIFO_ADDRESS_CG(NAME) \
    covergroup NAME with function sample(bit [ADDR_WIDTH-1:0] wa, bit [ADDR_WIDTH-1:0] ra); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        write_address: coverpoint wa; read_address: coverpoint ra; \
        address_pair: cross write_address, read_address; \
    endgroup
`FIFO_ADDRESS_CG(write_address_cg)
`FIFO_ADDRESS_CG(read_address_cg)
`undef FIFO_ADDRESS_CG
`define FIFO_ACTIVITY_CG(NAME) \
    covergroup NAME with function sample(bit transfer, bit full, bit empty, bit phase); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        activity: coverpoint transfer; full_state: coverpoint full; empty_state: coverpoint empty; \
        local_phase: coverpoint phase; \
        activity_status: cross activity, full_state, empty_state; \
    endgroup
`FIFO_ACTIVITY_CG(write_activity_cg)
`FIFO_ACTIVITY_CG(read_activity_cg)
`undef FIFO_ACTIVITY_CG
`define FIFO_STALL_CG(NAME) \
    covergroup NAME with function sample(bit stalled, bit [LEVEL_WIDTH-1:0] level); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        stall: coverpoint stalled; local_level: coverpoint level; \
        stall_level: cross stall, local_level; \
    endgroup
`FIFO_STALL_CG(write_stall_cg)
`FIFO_STALL_CG(read_stall_cg)
`undef FIFO_STALL_CG
`define FIFO_WRAP_CG(NAME) \
    covergroup NAME with function sample(bit phase, bit remote); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        wrap_phase: coverpoint phase; remote_phase: coverpoint remote; \
        wrap_remote_phase: cross wrap_phase, remote_phase; \
    endgroup
`FIFO_WRAP_CG(write_wrap_cg)
`FIFO_WRAP_CG(read_wrap_cg)
`undef FIFO_WRAP_CG
`define FIFO_THRESHOLD_CG(NAME) \
    covergroup NAME with function sample(bit entry, bit [LEVEL_WIDTH-1:0] level); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        threshold_direction: coverpoint entry { bins entry = {1}; bins exit = {0}; } \
        threshold_level: coverpoint level; \
        threshold_transition: cross threshold_direction, threshold_level; \
    endgroup
`FIFO_THRESHOLD_CG(write_threshold_cg)
`FIFO_THRESHOLD_CG(read_threshold_cg)
`undef FIFO_THRESHOLD_CG

localparam int unsigned STAGE_INDEX_WIDTH = $clog2(SYNC_STAGES);
localparam int unsigned BIT_INDEX_WIDTH   = $clog2(PTR_WIDTH);
`define FIFO_GRAY_CG(NAME) \
    covergroup NAME with function sample( \
        bit [STAGE_INDEX_WIDTH-1:0] stage, bit [BIT_INDEX_WIDTH-1:0] bit_index, bit direction); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        sync_stage: coverpoint stage; pointer_bit: coverpoint bit_index; \
        transition_direction: coverpoint direction; \
        stage_bit_direction: cross sync_stage, pointer_bit, transition_direction; \
    endgroup
`FIFO_GRAY_CG(read_gray_cg)
`FIFO_GRAY_CG(write_gray_cg)
`undef FIFO_GRAY_CG
`define FIFO_UP_CG(NAME) \
    covergroup NAME with function sample(bit [STAGE_INDEX_WIDTH-1:0] stage, bit direction); \
        option.per_instance = 1; option.auto_bin_max = 65536; \
        sync_stage: coverpoint stage; transition_direction: coverpoint direction; \
        stage_direction: cross sync_stage, transition_direction; \
    endgroup
`FIFO_UP_CG(read_up_cg)
`FIFO_UP_CG(write_up_cg)
`undef FIFO_UP_CG
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on VARHIDDEN */

write_address_cg write_address;
read_address_cg read_address;
write_activity_cg write_activity;
read_activity_cg read_activity;
write_stall_cg write_stall;
read_stall_cg read_stall;
write_wrap_cg write_wrap;
read_wrap_cg read_wrap;
write_threshold_cg write_threshold;
read_threshold_cg read_threshold;
read_gray_cg read_gray;
write_gray_cg write_gray;
read_up_cg read_up;
write_up_cg write_up;
initial begin
    write_address = new;
    read_address = new;
    write_activity = new;
    read_activity = new;
    write_stall = new;
    read_stall = new;
    write_wrap = new;
    read_wrap = new;
    write_threshold = new;
    read_threshold = new;
    read_gray = new;
    write_gray = new;
    read_up = new;
    write_up = new;
end

// These independent single HDL counters validate each state cross's sample
// total. They are not SVA antecedent/vacuity or quantitative release closure.
`FIFO_COVER(coverage_write_address_sample, i_w_clk, operational && push)
`FIFO_COVER(coverage_read_address_sample, i_r_clk, operational && pop)
`FIFO_COVER(coverage_write_activity_sample, i_w_clk, operational)
`FIFO_COVER(coverage_read_activity_sample, i_r_clk, operational)
`FIFO_COVER(coverage_write_stall_sample, i_w_clk, i_w_rstb && o_w_init_done)
`FIFO_COVER(coverage_read_stall_sample, i_r_clk, i_r_rstb && o_r_init_done)
`FIFO_COVER(coverage_write_wrap_sample, i_w_clk,
            operational && w_history && w_bin[PTR_WIDTH-1] != previous_w_phase)
`FIFO_COVER(coverage_read_wrap_sample, i_r_clk,
            operational && r_history && r_bin[PTR_WIDTH-1] != previous_r_phase)
`FIFO_COVER(
    coverage_write_threshold_sample, i_w_clk,
    i_w_rstb && w_history && previous_w_init && o_w_init_done && previous_af != o_w_almost_full)
`FIFO_COVER(
    coverage_read_threshold_sample, i_r_clk,
    i_r_rstb && r_history && previous_r_init && o_r_init_done && previous_ae != o_r_almost_empty)

always @(posedge i_w_clk) begin
    if (operational) begin
        write_activity.sample(push, o_w_full, o_r_empty, w_bin[PTR_WIDTH-1]);
        if (push) write_address.sample(w_bin[ADDR_WIDTH-1:0], r_bin[ADDR_WIDTH-1:0]);
        if (w_history && w_bin[PTR_WIDTH-1] != previous_w_phase)
            write_wrap.sample(w_bin[PTR_WIDTH-1], r_gray_final[PTR_WIDTH-1]);
    end
    if (i_w_rstb && o_w_init_done) begin
        write_stall.sample(i_w_valid && !o_w_ready, o_w_level);
        if (ALMOST_FULL_LEVEL >= 1 && ALMOST_FULL_LEVEL <= DEPTH &&
            w_history && previous_w_init && previous_af != o_w_almost_full)
            write_threshold.sample(o_w_almost_full, o_w_level);
    end
    if (i_w_rstb && w_history) begin
        for (int stage = 0; stage < SYNC_STAGES; stage++) begin
            if (previous_r_up[stage] != r_up_stages[stage])
                read_up.sample(STAGE_INDEX_WIDTH'(stage), r_up_stages[stage]);
            for (int index = 0; index < PTR_WIDTH; index++) begin
                if (previous_r_gray[stage*PTR_WIDTH+index] != r_gray_stages[stage*PTR_WIDTH+index])
                    read_gray.sample(STAGE_INDEX_WIDTH'(stage), BIT_INDEX_WIDTH'(index),
                                     r_gray_stages[stage*PTR_WIDTH+index]);
            end
        end
    end
end
always @(posedge i_r_clk) begin
    if (operational) begin
        read_activity.sample(pop, o_w_full, o_r_empty, r_bin[PTR_WIDTH-1]);
        if (pop) read_address.sample(w_bin[ADDR_WIDTH-1:0], r_bin[ADDR_WIDTH-1:0]);
        if (r_history && r_bin[PTR_WIDTH-1] != previous_r_phase)
            read_wrap.sample(r_bin[PTR_WIDTH-1], w_gray_final[PTR_WIDTH-1]);
    end
    if (i_r_rstb && o_r_init_done) begin
        read_stall.sample(o_r_valid && !i_r_ready, o_r_level);
        if (ALMOST_EMPTY_LEVEL < DEPTH &&
            r_history && previous_r_init && previous_ae != o_r_almost_empty)
            read_threshold.sample(o_r_almost_empty, o_r_level);
    end
    if (i_r_rstb && r_history) begin
        for (int stage = 0; stage < SYNC_STAGES; stage++) begin
            if (previous_w_up[stage] != w_up_stages[stage])
                write_up.sample(STAGE_INDEX_WIDTH'(stage), w_up_stages[stage]);
            for (int index = 0; index < PTR_WIDTH; index++) begin
                if (previous_w_gray[stage*PTR_WIDTH+index] != w_gray_stages[stage*PTR_WIDTH+index])
                    write_gray.sample(STAGE_INDEX_WIDTH'(stage), BIT_INDEX_WIDTH'(index),
                                      w_gray_stages[stage*PTR_WIDTH+index]);
            end
        end
    end
end
