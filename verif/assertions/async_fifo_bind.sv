`ifndef MOSAIC_FORMAL
bind async_fifo async_fifo_sim_checker #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
    .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
) u_checker (
    .r_gray_final(r_gray_sync[STAGES-1]),
    .w_gray_final(w_gray_sync[STAGES-1]),
    .r_up_final(r_up_sync[STAGES-1]),
    .w_up_final(w_up_sync[STAGES-1]),
    .storage_words(memory),
    .*
);
`endif
