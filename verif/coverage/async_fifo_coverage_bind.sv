`ifndef MOSAIC_FORMAL
bind async_fifo async_fifo_sim_coverage #(
    .DEPTH(DEPTH),
    .SYNC_STAGES(SYNC_STAGES),
    .ALMOST_FULL_LEVEL(ALMOST_FULL_LEVEL),
    .ALMOST_EMPTY_LEVEL(ALMOST_EMPTY_LEVEL)
) u_coverage (
    .r_gray_words(r_gray_sync),
    .w_gray_words(w_gray_sync),
    .r_up_words  (r_up_sync),
    .w_up_words  (w_up_sync),
    .*
);
`endif
