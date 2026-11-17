module tb_tick_generator;
  parameter bit ALWAYS_READY = 0;
  bit clk = 0, rstn = 1;
  logic is_always = 1, update_count = 0;
  logic [1:0] max_count = 3;
  wire tick;

  always #5 clk = ~clk;
  tick_generator dut (.*);
  initial begin
    rstn = 0;
    repeat (3) @(negedge clk) rstn <= 1;
    update_count <= 1;
    @(posedge clk) update_count <= 0;
    repeat (5) @(negedge clk) is_always <= 0;
    update_count <= 1;
    @(posedge clk) update_count <= 0;
    repeat (20) @(negedge clk);

    $finish();
  end

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars();
  end

endmodule
