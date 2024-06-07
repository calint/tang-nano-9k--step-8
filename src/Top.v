`timescale 100ps / 100ps
//
`default_nettype none

module Top (
    input wire sys_clk,  // 27 MHz
    input wire sys_rst_n,
    output reg [5:0] led,
    input wire uart_rx,
    output wire uart_tx,
    input wire btn1
);

  assign uart_tx = uart_rx;

  localparam BURST_RAM_DEPTH_BITWIDTH = 4;

  //-- BurstRAM
  wire br_cmd;
  wire br_cmd_en;
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_ready;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE("RAM.mem"),  // initial RAM content
      .DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
      .BURST_COUNT(4)  // 4 * 64 bit data per burst
  ) burst_ram (
      .clk(sys_clk),
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
      .clk(sys_clk),
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

  reg [3:0] state;

  // some code so that Gowin EDA doesn't optimize it away
  always @(posedge sys_clk) begin
    if (!sys_rst_n) begin
      address <= 0;
      data_in <= 0;
      write_enable <= 0;
      state <= 0;
    end else begin
      led[5] = btn1;  // note: to rid off 'unused warning'
      case (state)

        0: begin  // wait for initiation / busy
          led <= {busy, data_out_ready, data_out[3:0]};
          if (!br_busy) begin
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
          state <= 0;
        end

      endcase
    end
  end

endmodule

`default_nettype wire
