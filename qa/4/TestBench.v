`timescale 100ps / 100ps
//
`default_nettype none

module TestBench;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 37;
  always #(clk_tk / 2) clk = ~clk;

  Top dut (
      .sys_clk  (clk),
      .sys_rst_n(sys_rst_n)
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #1000 sys_rst_n <= 1;

    while(!dut.rpll_lock) #clk_tk;
    $display("rpll locked");

    while(!dut.br_init_calib) #clk_tk;
    $display("psram init calib");

    $finish;
  end

endmodule

`default_nettype wire
