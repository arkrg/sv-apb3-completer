// origin: lib-ip/lfsr_4b/rtl
module lfsr_4b #(
    parameter bit [3:0] SEED = 4'd1
) (
    input logic clk,
    input logic rstn,
    input logic enable,
    output logic [3:0] out
);
  logic [3:0] c_state, n_state;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) c_state <= SEED;
    else c_state <= n_state;
  end
  assign n_state = (enable) ? c_state << 1 | ^c_state[3:2] : c_state;
  assign out = c_state;
endmodule
