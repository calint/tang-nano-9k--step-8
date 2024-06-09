//
// flash to cache loader
// initial code from:
// https://github.com/lushaylabs/tangnano9k-series-examples/blob/master/flash/flash.v
//
`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module Flash #(
    parameter STARTUP_WAIT = 32'd10000000,
    parameter TRANSFER_BYTES_NUM = 32'h0001_0000
) (
    input  wire clk,
    output reg  done,

    // interface to flash
    output reg  flash_clk,
    input  wire flash_miso,
    output reg  flash_mosi,
    output reg  flash_cs,

    // interface to cache
    output reg [31:0] cache_address,
    output reg [31:0] cache_data_in,
    output reg [3:0] cache_write_enable,
    input wire cache_busy
);

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

  always_ff @(posedge clk) begin
    case (state)

      STATE_INIT_POWER: begin
        flash_clk <= 0;
        flash_mosi <= 0;
        flash_cs <= 1;
        done <= 0;
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
              done  <= 1;
              state <= STATE_DONE;
            end
          end
        end
      end

      STATE_DONE: begin
      end

    endcase
  end
endmodule
