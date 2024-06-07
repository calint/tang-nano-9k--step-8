`timescale 1ns / 1ps `default_nettype none

module TestBench;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  BurstRAM #(
      .DATA_FILE("RAM.mem"),  // initial RAM content
      .DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
      .BURST_COUNT(4)  // 4 * 64 bit data per burst
  ) burst_ram (
      .clk(clk),
      .rst(!sys_rst_n),
      .cmd(br_cmd),  // 0: read, 1: write
      .cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .addr(br_addr),  // 8 bytes word
      .wr_data(br_wr_data),  // data to write
      .data_mask(br_data_mask),  // not implemented (same as 0 in IP component)
      .rd_data(br_rd_data),  // read data
      .rd_data_ready(br_rd_data_ready),  // rd_data is valid
      .busy(br_busy)
  );
  wire br_cmd;
  wire br_cmd_en;
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_ready;
  wire br_busy;

  Cache #(
      .LINE_IX_BITWIDTH(1),
      .BURST_RAM_DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH)
  ) cache (
      .clk(clk),
      .rst(!sys_rst_n),
      .address(address),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .data_in(data_in),
      .write_enable(write_enable),
      .busy(busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd(br_cmd),
      .br_cmd_en(br_cmd_en),
      .br_addr(br_addr),
      .br_wr_data(br_wr_data),
      .br_data_mask(br_data_mask),
      .br_rd_data(br_rd_data),
      .br_rd_data_ready(br_rd_data_ready),
      .br_busy(br_busy)
  );
  reg [31:0] address;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;
  wire busy;

  reg clk = 1;
  reg sys_rst_n = 0;

  localparam clk_tk = 4;
  always #(clk_tk / 2) clk = ~clk;

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

    while (br_busy) #clk_tk;

    // // dump the cache
    // for (i = 0; i < 8; i = i + 1) begin
    //   $display("1). %h : %h  %h  %h  %h", cache.tag.data[i], cache.data0.data[i],
    //            cache.data1.data[i], cache.data2.data[i], cache.data3.data[i]);
    // end

    // // write
    // address <= 4;
    // data_in <= 32'habcd_ef12;
    // write_enable <= 4'b1111;
    // #clk_tk;

    // // write
    // address <= 8;
    // data_in <= 32'habcd_1234;
    // write_enable <= 4'b1111;
    // #clk_tk;

    // read; cache miss
    address <= 16;
    write_enable <= 0;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    // one cycle delay. value for address 4
    if (data_out == 32'hD5B8A9C4) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    // read; cache hit
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C3E6F && data_out_ready) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // read; cache miss, invalid line
    address <= 32;
    write_enable <= 0;
    #clk_tk;

    if (!data_out_ready) $display("Test 3 passed");
    else $display("Test 3 FAILED");

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h2F5E3C7A && data_out_ready) $display("Test 4 passed");
    else $display("Test 4 FAILED");

    // read; cache hit valid
    address <= 12;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'h9D8E2F17 && data_out_ready) $display("Test 5 passed");
    else $display("Test 5 FAILED");

    // write; cache hit
    address <= 8;
    data_in <= 32'h0000_00ad;
    write_enable <= 4'b0001;
    #clk_tk;

    // read; cache hit valid
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C3Ead && data_out_ready) $display("Test 6 passed");
    else $display("Test 6 FAILED");

    #clk_tk;

    // write
    address <= 8;
    data_in <= 32'h00008765;
    write_enable <= 4'b0011;
    #clk_tk;

    // read it back
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hAB4C8765 && data_out_ready) $display("Test 8 passed");
    else $display("Test 8 FAILED");

    // write
    address <= 8;
    data_in <= 32'hfeef0000;
    write_enable <= 4'b1100;
    #clk_tk;

    // read it back
    address <= 8;
    write_enable <= 0;
    #clk_tk;

    if (data_out == 32'hfeef8765 && data_out_ready) $display("Test 9 passed");
    else $display("Test 9 FAILED");

    // cache miss, evict then write
    address <= 64;
    data_in <= 32'habcdef12;
    write_enable <= 4'b1111;
    #clk_tk;

    while (busy) #clk_tk;

    // read it back
    address <= 64;
    write_enable <= 0;
    #clk_tk;

    while (busy) #clk_tk;

    if (data_out == 32'habcdef12 && data_out_ready) $display("Test 10 passed");
    else $display("Test 10 FAILED");

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire
