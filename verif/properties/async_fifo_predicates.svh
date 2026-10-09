// Shared predicates for SVA simulation and Yosys procedural formal assertions.
function automatic logic gray_single_step(input logic [PTR_WIDTH-1:0] difference);
    gray_single_step = (difference & (difference - PTR_WIDTH'(1))) == '0;
endfunction

function automatic logic write_controls_known_now();
    write_controls_known_now = !$isunknown(i_w_rstb) && !$isunknown(i_w_valid) &&
        !$isunknown(o_w_ready) && !$isunknown(o_w_full) && !$isunknown(o_w_init_done) &&
        !$isunknown(o_w_almost_full) && !$isunknown(o_w_level);
endfunction

function automatic logic read_controls_known_now();
    read_controls_known_now = !$isunknown(i_r_rstb) && !$isunknown(i_r_ready) &&
        !$isunknown(o_r_valid) && !$isunknown(o_r_empty) && !$isunknown(o_r_init_done) &&
        !$isunknown(o_r_almost_empty) && !$isunknown(o_r_level);
endfunction

// Check final crossing stages directly. An unknown may otherwise be masked by
// a disabled endpoint or an unrelated known bit in a flag comparison.
function automatic logic write_synchronizers_known_now();
    write_synchronizers_known_now = !$isunknown(r_gray_final) && !$isunknown(r_up_final);
endfunction

function automatic logic read_synchronizers_known_now();
    read_synchronizers_known_now = !$isunknown(w_gray_final) && !$isunknown(w_up_final);
endfunction

function automatic logic [PTR_WIDTH-1:0] binary_to_gray(input logic [PTR_WIDTH-1:0] value);
    binary_to_gray = value ^ (value >> 1);
endfunction

function automatic logic [PTR_WIDTH-1:0] gray_to_binary(input logic [PTR_WIDTH-1:0] value);
    logic [PTR_WIDTH-1:0] result;
    result[PTR_WIDTH-1] = value[PTR_WIDTH-1];
    for (int bit_index = PTR_WIDTH - 2; bit_index >= 0; bit_index--) begin
        result[bit_index] = result[bit_index+1] ^ value[bit_index];
    end
    gray_to_binary = result;
endfunction

// Expected state is derived from the contract's handshakes, not DUT next-state
// nets. Otherwise a wrong next-state expression could validate itself.
function automatic logic [PTR_WIDTH-1:0] expected_write_pointer();
    expected_write_pointer = w_bin + PTR_WIDTH'(i_w_valid && o_w_ready);
endfunction

function automatic logic [PTR_WIDTH-1:0] expected_read_pointer();
    expected_read_pointer = r_bin + PTR_WIDTH'(o_r_valid && i_r_ready);
endfunction

function automatic logic expected_full();
    logic [PTR_WIDTH-1:0] full_mask;
    full_mask = PTR_WIDTH'(3) << (PTR_WIDTH - 2);
    expected_full = !o_w_init_done || predicted_write_gray == (r_gray_final ^ full_mask);
endfunction

function automatic logic expected_empty();
    expected_empty = !o_r_init_done || predicted_read_gray == w_gray_final;
endfunction

function automatic logic [LEVEL_WIDTH-1:0] expected_write_level();
    expected_write_level = o_w_init_done ?
        LEVEL_WIDTH'(predicted_write_pointer - observed_read_pointer) : '0;
endfunction

function automatic logic [LEVEL_WIDTH-1:0] expected_read_level();
    expected_read_level = o_r_init_done ?
        LEVEL_WIDTH'(observed_write_pointer - predicted_read_pointer) : '0;
endfunction

function automatic logic expected_read_load();
    expected_read_load = o_r_init_done && !predicted_empty && (o_r_empty || (o_r_valid && i_r_ready));
endfunction

// Cross-domain state here is observation-only. Ownership has no delivery
// obligation in a canceled epoch, including the peer-reset propagation window.
function automatic logic live_epoch();
    live_epoch = i_w_rstb && i_r_rstb && w_up && r_up && w_seen_remote && r_seen_remote;
endfunction

function automatic logic [PTR_WIDTH-1:0] live_distance();
    live_distance = w_bin - r_bin;
endfunction

function automatic logic write_reset_state();
    write_reset_state = w_bin == '0 && w_gray == '0 && r_gray_final == '0 &&
        !r_up_final && !w_up && !w_seen_remote && o_w_full && o_w_level == '0 &&
        !o_w_init_done && !o_w_ready;
endfunction

function automatic logic read_reset_state();
    read_reset_state = r_bin == '0 && r_gray == '0 && w_gray_final == '0 &&
        !w_up_final && !r_up && !r_seen_remote && o_r_empty && o_r_level == '0 &&
        o_r_data == '0 && !o_r_init_done && !o_r_valid;
endfunction
