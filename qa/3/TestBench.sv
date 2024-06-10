`timescale 100ps / 100ps
//
`default_nettype none

module TestBench;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 37;
  always #(clk_tk / 2) clk = ~clk;

  wire [5:0] led;
  wire flash_clk;
  reg flash_miso = 1;
  wire flash_mosi;
  wire flash_cs;

  Top dut (
      .sys_clk(clk),
      .sys_rst_n(sys_rst_n),
      .led(led),

      // flash
      .flash_clk (flash_clk),
      .flash_miso(flash_miso),
      .flash_mosi(flash_mosi),
      .flash_cs  (flash_cs)
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #1000 sys_rst_n <= 1;

    // while (!dut.rpll_lock) #clk_tk;
    // $display("rpll locked");

    // while (!dut.br_init_calib) #clk_tk;
    // $display("psram init calib");

    while (dut.clock_cycle < 1000) #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire
