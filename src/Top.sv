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
    output wire [ 1:0] O_psram_cs_n,

    // flash
    output reg  flash_clk,
    input  wire flash_miso,
    output reg  flash_mosi,
    output reg  flash_cs
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

  PSRAM_Memory_Interface_HS_V2_Top br (
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
  reg [31:0] cache_address;
  wire [31:0] cache_data_out;
  wire cache_data_out_ready;
  reg [31:0] cache_data_in;
  reg [3:0] cache_write_enable;
  wire cache_busy;

  Cache #(
      .LINE_IX_BITWIDTH(9),
      .BURST_RAM_DEPTH_BITWIDTH(BURST_RAM_DEPTH_BITWIDTH)
  ) cache (
      .clk(br_clk_out),
      .rst(!sys_rst_n || !br_init_calib),

      // .address(connect_flash_to_cache ? flash_cache_address : cache_address),
      .address(cache_address),
      .data_in(cache_data_in),
      .write_enable(cache_write_enable),
      .data_out(cache_data_out),
      .data_out_ready(cache_data_out_ready),
      .busy(cache_busy),

      // burst ram wiring; prefix 'br_'
      .br_cmd(br_cmd),
      .br_cmd_en(br_cmd_en),
      .br_addr(br_addr),
      .br_wr_data(br_wr_data),
      .br_data_mask(br_data_mask),
      .br_rd_data(br_rd_data),
      .br_rd_data_valid(br_rd_data_valid)
  );

  // ----------------------------------------------------------
  localparam STARTUP_WAIT = 1_000_000;
  localparam TRANSFER_BYTES_NUM = 32'h0001_0000;

  reg [23:0] read_address = 0;
  reg [7:0] command = 8'h03;
  reg [7:0] current_byte_out = 0;
  reg [7:0] current_byte_num = 0;
  reg [7:0] data_in[32];

  localparam STATE_INIT_POWER = 8'd0;
  localparam STATE_LOAD_CMD_TO_SEND = 8'd1;
  localparam STATE_SEND = 8'd2;
  localparam STATE_LOAD_ADDRESS_TO_SEND = 8'd3;
  localparam STATE_READ_DATA = 8'd4;
  localparam STATE_START_WRITE_TO_CACHE = 8'd5;
  localparam STATE_WRITE_TO_CACHE = 8'd6;
  localparam STATE_DONE = 8'd7;

  reg [23:0] data_to_send = 0;
  reg [ 8:0] bits_to_send = 0;

  reg [32:0] counter = 0;
  reg [ 2:0] state = 0;
  reg [ 2:0] return_state = 0;

  always_ff @(posedge br_clk_out) begin
    if (!sys_rst_n) begin
      flash_clk <= 0;
      flash_mosi <= 0;
      flash_cs <= 1;
      state <= STATE_INIT_POWER;
    end else begin
      case (state)

        STATE_INIT_POWER: begin
          if (counter > STARTUP_WAIT) begin
            state <= STATE_LOAD_CMD_TO_SEND;
            counter <= 0;
            current_byte_num <= 0;
            current_byte_out <= 0;
          end else begin
            counter <= counter + 1;
          end
        end

        STATE_LOAD_CMD_TO_SEND: begin
          flash_cs <= 0;
          data_to_send[23-:8] <= command;
          bits_to_send <= 8;
          state <= STATE_SEND;
          return_state <= STATE_LOAD_ADDRESS_TO_SEND;
        end

        STATE_SEND: begin
          if (counter == 0) begin
            flash_clk <= 0;
            flash_mosi <= data_to_send[23];
            data_to_send <= {data_to_send[22:0], 1'b0};
            bits_to_send <= bits_to_send - 1;
            counter <= 1;
          end else begin
            counter   <= 0;
            flash_clk <= 1;
            if (bits_to_send == 0) begin
              state <= return_state;
            end
          end
        end

        STATE_LOAD_ADDRESS_TO_SEND: begin
          data_to_send <= read_address;
          bits_to_send <= 24;
          state <= STATE_SEND;
          return_state <= STATE_READ_DATA;
          current_byte_num <= 0;
        end

        STATE_READ_DATA: begin
          if (counter[0] == 0) begin
            flash_clk <= 0;
            counter   <= counter + 1;
            if (counter[3:0] == 0 && counter > 0) begin
              data_in[current_byte_num] <= current_byte_out;
              current_byte_num <= current_byte_num + 1;
              if (current_byte_num == 31) begin
                state <= STATE_DONE;
              end
            end
          end else begin
            flash_clk <= 1;
            current_byte_out <= {current_byte_out[6:0], flash_miso};
            counter <= counter + 1;
          end
        end

        STATE_START_WRITE_TO_CACHE: begin
          flash_cs <= 1;
          counter <= read_address;
          read_address <= read_address + 32;
          state <= STATE_WRITE_TO_CACHE;
        end

        STATE_WRITE_TO_CACHE: begin
          if (!cache_busy) begin
            if (counter == 32) begin
              cache_write_enable <= 0;
              counter <= STARTUP_WAIT;
              state <= STATE_INIT_POWER;
            end else begin
              cache_address <= counter;
              cache_data_in = {
                data_in[counter+3], data_in[counter+2], data_in[counter+1], data_in[counter]
              };
              cache_write_enable <= 4'b1111;
              counter <= counter + 4;
              if (counter == TRANSFER_BYTES_NUM) begin
                state <= STATE_DONE;
              end
            end
          end
        end

        STATE_DONE: begin
        end

      endcase
    end
  end



















  // reg [3:0] state;

  // // some code so that Gowin EDA doesn't optimize it away
  // always_ff @(posedge sys_clk) begin
  //   if (!sys_rst_n || !br_init_calib) begin
  //     cache_address <= 0;
  //     cache_data_in <= 0;
  //     cache_write_enable <= 0;
  //     connect_flash_to_cache <= 1;
  //     state <= 0;
  //   end else begin
  //     led[5] = btn1;  // note: to rid off 'unused warning'
  //     case (state)

  //       0: begin  // wait for initiation of PSRAM
  //         led <= {rpll_lock, br_init_calib};
  //         if (br_init_calib && rpll_lock) begin
  //           state <= 5;
  //         end
  //       end

  //       5: begin  // load cache from flashs
  //         if (flash_done) begin
  //           connect_flash_to_cache <= 0;
  //           state <= 1;
  //         end
  //       end

  //       1: begin  // read from cache
  //         led <= {cache_busy, cache_data_out_ready, cache_data_out[3:0]};
  //         cache_write_enable <= 0;
  //         state <= 2;
  //       end

  //       2: begin
  //         led <= {cache_busy, cache_data_out_ready, cache_data_out[3:0]};
  //         if (cache_data_out_ready) begin
  //           state <= 3;
  //         end
  //       end

  //       3: begin  // write to cache
  //         led <= {cache_busy, cache_data_out_ready, cache_data_out[3:0]};
  //         cache_write_enable <= 4'b1111;
  //         cache_address <= cache_address + 4;
  //         state <= 4;
  //       end

  //       4: begin  // wait for write to be done
  //         led <= {cache_busy, cache_data_out_ready, cache_data_out[3:0]};
  //         if (!cache_busy) begin
  //           state <= 1;
  //         end
  //       end

  //     endcase
  //   end
  // end

endmodule

`default_nettype wire
