import param_pkg::*;
module tb_apb_completer;
  parameter bit READY_MODE = ALWAYS;
  parameter int WIDTH_ADDR = 4;
  parameter int WIDTH_ACCADDR = WIDTH_ADDR - 2;
  parameter int WIDTH_DATA = 32;

  logic [WIDTH_DATA-1:0] exp_mem[2**(WIDTH_ACCADDR)];
  bit pclk = 0, presetn = 1;
  string wave_name;
  logic psel, pwrite, penable, pready, pslverr;
  logic [WIDTH_ADDR-1:0] paddr;
  logic [WIDTH_DATA-1:0] pwdata, prdata;
  wire [WIDTH_ACCADDR-1:0] acc_addr = paddr[WIDTH_ADDR-1:2];

  `include "tb_tasks.svh"

  always #5 pclk = ~pclk;
  apb_completer #(.ALWAYS_READY(READY_MODE == ALWAYS)) dut (.*);
  initial begin
    $display("-----------------");
    $display(READY_MODE);
    reset_and_read("Reset and Read ");
    write_and_read("Write and Read");
    reset_and_read("Reset after Write");
    $display("[REAULT]: total write transaction: %0d, total read transaction: %d, total error: %d",
             write_trans, read_trans, total_err);
    $finish();
  end

  initial begin
    if (READY_MODE == ALWAYS) $dumpfile("wave_always_ready.vcd");
    else $dumpfile("wave_random_delay.vcd");
    $dumpvars();
  end

  task automatic reset_and_read(string name);
    begin_case(name);

    apb_reset();
    for (int i = 0; i < 2 ** WIDTH_ADDR; i = i + 1) begin
      apb_read(.paddr_(i));
    end

    end_case();
  endtask

  task automatic write_and_read(string name);
    begin_case(name);
    for (int aw = 0; aw < 2 ** WIDTH_ADDR; aw = aw + 1) begin
      apb_write(.paddr_(aw), .pwdata_(aw << 24));
      for (int ar = 0; ar < 2 ** WIDTH_ADDR; ar = ar + 1) begin
        apb_read(.paddr_(ar));
      end
    end
    end_case();
  endtask

endmodule

