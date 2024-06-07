`timescale 100ps / 100ps
//
`default_nettype none

module TestBench;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 37;
  always #(clk_tk / 2) clk = ~clk;

  wire clkout;
  wire lock;
  wire clkoutp;
  wire clkoutd;
  wire clkin = clk;

  Gowin_rPLL rpll (
      .clkout(clkout),  //output clkout
      .lock(lock),  //output lock
      .clkoutp(clkoutp),  //output clkoutp
      .clkoutd(clkoutd),  //output clkoutd
      .clkin(clkin)  //input clkin
  );

  wire clk_d = clk;
  wire memory_clk = clkout;
  wire memory_clk_p = clkoutp;
  wire pll_lock=lock;
  wire rst_n = sys_rst_n;
  wire [1:0] O_psram_ck;
  wire [1:0] O_psram_ck_n;
  wire [15:0] IO_psram_dq;
  wire [1:0] IO_psram_rwds;
  wire [1:0] O_psram_cs_n;
  wire [1:0] O_psram_reset_n;
  wire [63:0] wr_data;
  wire [63:0] rd_data;
  wire rd_data_valid;
  wire [20:0] addr;
  wire cmd;
  wire cmd_en;
  wire init_calib;
  wire clk_out;
  wire [7:0] data_mask;

  PSRAM_Memory_Interface_HS_V2_Top psram (
      .clk_d(clk_d),  //input clk_d
      .memory_clk(memory_clk),  //input memory_clk
      .memory_clk_p(memory_clk_p),  //input memory_clk_p
      .pll_lock(pll_lock),  //input pll_lock
      .rst_n(rst_n),  //input rst_n
      .O_psram_ck(O_psram_ck),  //output [1:0] O_psram_ck
      .O_psram_ck_n(O_psram_ck_n),  //output [1:0] O_psram_ck_n
      .IO_psram_dq(IO_psram_dq),  //inout [15:0] IO_psram_dq
      .IO_psram_rwds(IO_psram_rwds),  //inout [1:0] IO_psram_rwds
      .O_psram_cs_n(O_psram_cs_n),  //output [1:0] O_psram_cs_n
      .O_psram_reset_n(O_psram_reset_n),  //output [1:0] O_psram_reset_n
      .wr_data(wr_data),  //input [63:0] wr_data
      .rd_data(rd_data),  //output [63:0] rd_data
      .rd_data_valid(rd_data_valid),  //output rd_data_valid
      .addr(addr),  //input [20:0] addr
      .cmd(cmd),  //input cmd
      .cmd_en(cmd_en),  //input cmd_en
      .init_calib(init_calib),  //output init_calib
      .clk_out(clk_out),  //output clk_out
      .data_mask(data_mask)  //input [7:0] data_mask
  );

  reg [31:0] address;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;
  wire busy;

  Cache #(
      .LINE_IX_BITWIDTH(1),
      .BURST_RAM_DEPTH_BITWIDTH(21)
  ) cache (
      .clk(clk_out),
      .rst(!sys_rst_n || !lock || !init_calib),
      .address(address),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .data_in(data_in),
      .write_enable(write_enable),
      .busy(busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd(cmd),
      .br_cmd_en(cmd_en),
      .br_addr(addr),
      .br_wr_data(wr_data),
      .br_data_mask(data_mask),
      .br_rd_data(rd_data),
      .br_rd_data_valid(rd_data_valid)
  );

  integer i;

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    // clear the cache
    for (i = 0; i < 2 ** 10; i = i + 1) begin
      cache.tag.data[i]   = 0;
      cache.data0.data[i] = 0;
      cache.data1.data[i] = 0;
      cache.data2.data[i] = 0;
      cache.data3.data[i] = 0;
      cache.data4.data[i] = 0;
      cache.data5.data[i] = 0;
      cache.data6.data[i] = 0;
      cache.data7.data[i] = 0;
    end

    // for (i = 0; i < 4; i = i + 1) begin
    //   $display(" tag[%0d]: %h", i, cache.tag.data[i]);
    //   $display("data0[%0d]: %h", i, cache.data0.data[i]);
    //   $display("data1[%0d]: %h", i, cache.data1.data[i]);
    //   $display("data2[%0d]: %h", i, cache.data2.data[i]);
    //   $display("data3[%0d]: %h", i, cache.data3.data[i]);
    //   $display("data4[%0d]: %h", i, cache.data4.data[i]);
    //   $display("data5[%0d]: %h", i, cache.data5.data[i]);
    //   $display("data6[%0d]: %h", i, cache.data6.data[i]);
    //   $display("data7[%0d]: %h", i, cache.data7.data[i]);
    // end

    #clk_tk;
    sys_rst_n <= 1;

    // wait for burst RAM to initiate
    while (!init_calib || !lock) #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire
