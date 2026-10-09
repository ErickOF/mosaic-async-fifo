# Required crossing inventory for the qualified site CDC/RDC adapter:
# Write domain: i_w_clk, active-low i_w_rstb.
# Read domain: i_r_clk, active-low i_r_rstb.
# r_gray -> r_gray_sync[0] -> ... -> r_gray_sync[SYNC_STAGES-1], write clock.
# w_gray -> w_gray_sync[0] -> ... -> w_gray_sync[SYNC_STAGES-1], read clock.
# r_up -> r_up_sync[0] -> ... -> r_up_sync[SYNC_STAGES-1], write clock.
# w_up -> w_up_sync[0] -> ... -> w_up_sync[SYNC_STAGES-1], read clock.
# Every stage must survive mapping, no intermediate stage may feed logic.
# Dual-clock storage payload crossing needs a recognized FIFO protocol proof,
# not an unqualified multi-bit synchronizer waiver.
# Local resets assert asynchronously and release from separate synchronizers.
# A one-sided reset cancels the epoch and propagates domain-down before recovery.
error "BLOCKED: async_fifo CDC/RDC commands and storage crossing policy require site qualification"
