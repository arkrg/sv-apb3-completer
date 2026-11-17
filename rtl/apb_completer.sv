module apb_completer #(
    parameter bit ALWAYS_READY = 0,
    parameter bit [3:0] SEED = 4'b0001,
    parameter int WIDTH_DATA = 32,
    parameter int WIDTH_ADDR = 4
) (

    input  logic                  pclk,
    input  logic                  presetn,
    input  logic                  psel,
    input  logic [WIDTH_ADDR-1:0] paddr,
    input  logic                  pwrite,
    input  logic [WIDTH_DATA-1:0] pwdata,
    input  logic                  penable,
    output logic [WIDTH_DATA-1:0] prdata,
    output logic                  pready,
    output logic                  pslverr
);
  logic [WIDTH_DATA-1:0] pre_prdata;
  logic [3:0] lsfr_out;
  logic pre_pslverr, resp_enable;

  wire is_setup = {psel, penable} == 2'b10;
  wire is_access = {psel, penable} == 2'b11;
  wire [WIDTH_ADDR-3:0] acc_register = paddr[WIDTH_ADDR-1:2];

  logic [WIDTH_DATA-1:0] regs[2**WIDTH_ADDR];

  always_ff @(posedge pclk or presetn) begin
    if (!presetn) begin
      for (int i = 0; i < 2 ** (WIDTH_ADDR - 2); i = i + 1) regs[i] <= 32'h01CE_B007;
    end else begin
      if (is_access & pwrite & resp_enable) regs[acc_register] <= pwdata;
    end
  end
  always_comb begin
    if (is_access) begin
      pre_prdata  = (acc_register == 0) ? 32'h05AD_D00D : regs[acc_register];
      pre_pslverr = (acc_register == 0) ? 1 : 0;
    end else begin
      pre_prdata  = 0;
      pre_pslverr = 0;
    end
  end

  resp_control #(
      .SEED(SEED)
  ) u_rand_tikgen (
      .clk(pclk),
      .rstn(presetn),
      .is_always(ALWAYS_READY),
      .update_count(is_setup),
      .resp_enable
  );

  assign pready  = resp_enable ? 1'b1 : 0;
  assign pslverr = resp_enable ? pre_pslverr : 0;
  assign prdata  = resp_enable ? pre_prdata : 0;

endmodule

module resp_control #(
    parameter bit [3:0] SEED = 4'd1
) (
    input  clk,
    input  rstn,
    input  is_always,
    input  update_count,
    output resp_enable
);
  logic [3:0] lsfr_out;
  logic tick;
  tick_generator #(
      .WIDTH_COUNT(2)
  ) u_tikgen (
      .*,
      .is_always,
      .update_count,
      .max_count(lsfr_out[1:0]),
      .tick
  );

  lfsr_4b #(
      .SEED(SEED)
  ) u_lfsr (
      .*,
      .enable(~is_always),
      .out(lsfr_out)
  );
  assign resp_enable = (is_always) ? 1 : tick;
endmodule

module tick_generator #(
    parameter int WIDTH_COUNT = 2
) (
    input clk,
    input rstn,
    input is_always,
    input update_count,
    input [WIDTH_COUNT-1:0] max_count,
    output tick
);
  logic [WIDTH_COUNT-1:0] c_count, n_count;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) c_count <= 0;
    else begin
      if (!is_always) begin
        if (update_count) c_count <= max_count;
        else c_count <= n_count;
      end
    end
  end
  assign n_count = (c_count == 0) ? 0 : c_count - 1;
  assign tick = (is_always) ? 1 : (update_count) ? 0 : (c_count == 0);
endmodule

