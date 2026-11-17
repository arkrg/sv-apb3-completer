int total_err = 0;
int prev_err = 0;
int prev_wrt = 0;
int prev_rdt = 0;
int case_err = 0;
int cyc = 0;
int write_trans = 0;
int read_trans = 0;
string case_name;

task automatic begin_case(string name);
  case_name = name;
  case_err  = 0;
  prev_err  = total_err;
  prev_wrt  = write_trans;
  prev_rdt  = read_trans;
  $display("Start %s", name);
endtask

task automatic end_case();
  $display("[%s] %s, Write: %d Read: %d ", case_err == 0 ? "PASS" : "FAIL", case_name,
           write_trans - prev_wrt, read_trans - prev_rdt);
  total_err += case_err;
endtask

task automatic apb_reset();
  presetn = 0;
  exp_mem[0] <= 32'h05AD_D00D;
  for (int i = 1; i < 2 ** (WIDTH_ACCADDR); i = i + 1) exp_mem[i] <= 32'h01CE_B007;
  repeat (2) @(posedge pclk);
  presetn <= 1;
  repeat (1) @(posedge pclk);
endtask

task automatic apb_setup(input bit [WIDTH_ADDR-1:0] paddr_, input bit pwrite_,
                         input bit [WIDTH_DATA-1:0] pwdata_ = 32'h05AD_D00D);
  psel <= 1;
  penable <= 0;
  paddr <= paddr_;
  pwrite <= pwrite_;
  if (pwrite_) pwdata <= pwdata_;
  @(posedge pclk);
  penable <= 1;
endtask

task automatic apb_write(input bit [WIDTH_ADDR-1:0] paddr_, input bit [WIDTH_DATA-1:0] pwdata_);
  apb_setup(.paddr_(paddr_), .pwrite_(1), .pwdata_(pwdata_));
  wait_pready(4);
  if (acc_addr != 0) exp_mem[acc_addr] <= pwdata_;
  write_trans++;
endtask

task automatic apb_read(input bit [WIDTH_ADDR-1:0] paddr_);
  apb_setup(.paddr_(paddr_), .pwrite_(0));
  wait_pready(4);
  comp_data(exp_mem[acc_addr], acc_addr == 0);
  read_trans++;
endtask

task automatic comp_data(input bit [WIDTH_DATA-1:0] exp_data, exp_slverr);
  if (exp_data != prdata) begin
    $display(" [%t] [MISMATCH] expected data = %h got = %h", $time, exp_data, prdata);
    case_err++;
  end
  if (exp_slverr != pslverr) begin
    $display(" [%t] [MISMATCH] expected slverr = %b got = %b", $time, exp_slverr, pslverr);
    case_err++;
  end
endtask
task automatic wait_pready(input int max_cyc);
  do begin
    @(posedge pclk);
    if (cyc == 4) begin
      $display(" [%t] [FAIL] pready didn't come", $time);
      case_err++;
      cyc = 0;
      break;
    end
    cyc++;
  end while (!pready);
  cyc = 0;
endtask
