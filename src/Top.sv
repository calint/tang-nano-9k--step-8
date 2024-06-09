`timescale 100ps / 100ps
//
`default_nettype none

module Top (
    input wire sys_clk,  // 27 MHz
    input wire sys_rst_n,
    output reg [5:0] led,
    input wire uart_rx,
    output wire uart_tx,
    input wire btn1,

    // Magic ports for PSRAM to be inferred
    output wire [ 1:0] O_psram_ck,
    output wire [ 1:0] O_psram_ck_n,
    inout  wire [ 1:0] IO_psram_rwds,
    inout  wire [15:0] IO_psram_dq,
    output wire [ 1:0] O_psram_reset_n,
    output wire [ 1:0] O_psram_cs_n
);

  assign uart_tx = uart_rx;

  // -- Gowin_rPLLs
  wire rpll_clkout;
  wire rpll_lock;
  wire rpll_clkoutp;
  wire rpll_clkin = sys_clk;

  Gowin_rPLL rpll (
      .clkout(rpll_clkout),  //output clkout 54 MHz
      .lock(rpll_lock),  //output lock
      .clkoutp(rpll_clkoutp),  //output clkoutp 54 MHz 90 degrees phased
      .clkin(rpll_clkin)  //input clkin 27 MHz
  );

  // -- PSRAM_Memory_Interface_HS_V2_Top
  wire br_clk_d = sys_clk;
  wire br_memory_clk = rpll_clkout;
  wire br_memory_clk_p = rpll_clkoutp;
  wire br_pll_lock = rpll_lock;
  wire rst_n = sys_rst_n;
  wire [63:0] br_wr_data;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire [20:0] br_addr;
  wire br_cmd;
  wire br_cmd_en;
  wire br_init_calib;
  wire br_clk_out;
  wire [7:0] br_data_mask;

  PSRAM_Memory_Interface_HS_V2_Top psram (
      .clk_d(br_clk_d),  //input clk_d
      .memory_clk(br_memory_clk),  //input memory_clk
      .memory_clk_p(br_memory_clk_p),  //input memory_clk_p
      .pll_lock(br_pll_lock),  //input pll_lock
      .rst_n(rst_n),  //input rst_n
      .O_psram_ck(O_psram_ck),  //output [1:0] O_psram_ck
      .O_psram_ck_n(O_psram_ck_n),  //output [1:0] O_psram_ck_n
      .IO_psram_dq(IO_psram_dq),  //inout [15:0] IO_psram_dq
      .IO_psram_rwds(IO_psram_rwds),  //inout [1:0] IO_psram_rwds
      .O_psram_cs_n(O_psram_cs_n),  //output [1:0] O_psram_cs_n
      .O_psram_reset_n(O_psram_reset_n),  //output [1:0] O_psram_reset_n
      .wr_data(br_wr_data),  //input [63:0] wr_data
      .rd_data(br_rd_data),  //output [63:0] rd_data
      .rd_data_valid(br_rd_data_valid),  //output rd_data_valid
      .addr(br_addr),  //input [20:0] addr
      .cmd(br_cmd),  //input cmd
      .cmd_en(br_cmd_en),  //input cmd_en
      .init_calib(br_init_calib),  //output init_calib
      .clk_out(br_clk_out),  //output clk_out
      .data_mask(br_data_mask)  //input [7:0] data_mask
  );

  localparam BURST_RAM_DEPTH_BITWIDTH = 21;

  // -- Cache
  reg [31:0] address;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;
  wire busy;

  Cache #(
      .LINE_IX_BITWIDTH(10),
      .BURST_RAM_DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH)
  ) cache (
      .clk(br_clk_out),
      .rst(!sys_rst_n || !br_init_calib),
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
      .br_rd_data_valid(br_rd_data_valid)
  );

  reg [3:0] state;

  // some code so that Gowin EDA doesn't optimize it away
  always @(posedge sys_clk) begin
    if (!sys_rst_n || !br_init_calib) begin
      address <= 0;
      data_in <= 0;
      write_enable <= 0;
      state <= 0;
    end else begin
      led[5] = btn1;  // note: to rid off 'unused warning'
      case (state)

        0: begin  // wait for initiation / busy
          led <= {busy, data_out_ready, data_out[3:0]};
          if (br_init_calib) begin
            state <= 1;
          end
        end

        1: begin  // read from cache
          led <= {busy, data_out_ready, data_out[3:0]};
          write_enable <= 0;
          state <= 2;
        end

        2: begin
          led <= {busy, data_out_ready, data_out[3:0]};
          if (data_out_ready) begin
            state <= 3;
          end
        end

        3: begin  // write to cache
          led <= {busy, data_out_ready, data_out[3:0]};
          write_enable <= 4'b1111;
          address <= address + 4;
          state <= 4;
        end

        4: begin  // wait for write to be done
          led <= {busy, data_out_ready, data_out[3:0]};
          if (!busy) begin
            state <= 1;
          end
        end

      endcase
    end
  end

endmodule

`default_nettype wire
