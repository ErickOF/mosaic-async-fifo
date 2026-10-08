`timescale 1ns / 1ps
`ifdef MOSAIC_FORMAL
// Digital overapproximation of first-stage capture, not an analog model.
// Each channel independently samples a coherent source word now or holds for
// one extra destination edge. Later synchronizer stages remain exact RTL.
module async_fifo_capture_formal #(
    parameter int unsigned WIDTH = 1
) (
    input logic i_clk,
    i_rstb,
    input logic [WIDTH-1:0] i_word,
    output logic [WIDTH-1:0] o_word
);
    (* anyseq *)logic defer_capture;
    logic deferred;
    always @(posedge i_clk or negedge i_rstb) begin
        if (!i_rstb) begin
            o_word   <= '0;
            deferred <= 0;
        end else if (defer_capture && !deferred) begin
            deferred <= 1;
        end else begin
            o_word   <= i_word;
            deferred <= 0;
        end
    end
    // Require a real held, stale sample and a forced capture despite another
    // defer request. Nominal-only witnesses cannot close the delayed profiles.
    always @(posedge i_clk) begin
        cover (i_rstb && deferred && o_word != i_word);
        cover (i_rstb && deferred && defer_capture);
    end
endmodule
`endif
