//
// cache interfacing with burst RAM
//
// reviewed 2024-06-07

`timescale 100ps / 100ps
//
`default_nettype none
// `define DBG
// `define INFO

module Cache #(
    parameter LINE_IX_BITWIDTH = 8,
    parameter BURST_RAM_DEPTH_BITWIDTH = 4
) (
    input wire clk,
    input wire rst,
    input wire [31:0] address,
    output reg [31:0] data_out,
    output reg data_out_ready,
    input wire [31:0] data_in,
    input wire [3:0] write_enable,
    output wire busy,

    // burst RAM wiring; prefix 'br_'
    output reg br_cmd,  // 0: read, 1: write
    output reg br_cmd_en,  // 1: cmd and addr is valid
    output reg [BURST_RAM_DEPTH_BITWIDTH-1:0] br_addr,  // 8 bytes word
    output reg [63:0] br_wr_data,  // data to write
    output reg [7:0] br_data_mask,  // not implemented (same as 0 in IP component)
    input wire [63:0] br_rd_data,  // read data
    input wire br_rd_data_ready,  // rd_data is valid
    input wire br_busy
);

`ifdef INFO
  initial begin
    $display("Cache");
    $display("      lines: %0d", LINE_COUNT);
    $display("    columns: %0d x 4B", 2 ** COLUMN_IX_BITWIDTH);
    $display("        tag: %0d bits", TAG_BITWIDTH);
    $display(" cache size: %0d B", LINE_COUNT * (2 ** COLUMN_IX_BITWIDTH) * 4);
  end
`endif

  localparam ZEROS_BITWIDTH = 2;  // leading zeros in the address
  localparam COLUMN_IX_BITWIDTH = 3;  // 2 ^ 3 = 8 elements per line
  localparam LINE_COUNT = 2 ** LINE_IX_BITWIDTH;
  localparam TAG_BITWIDTH = 32 - LINE_IX_BITWIDTH - COLUMN_IX_BITWIDTH - ZEROS_BITWIDTH;
  localparam LINE_VALID_BIT = TAG_BITWIDTH;
  localparam LINE_DIRTY_BIT = TAG_BITWIDTH + 1;

  // wires dividing the address into components
  // |tag|line| col |00| address
  //                |00| ignored (4 bytes word aligned)
  //          | col |    column_ix: the index of the data in the cached line
  //     |line|          line_ix: index in array where tag and cached data is stored
  // |tag|               line_tag_from_address: upper bits followed by 'valid' and 'dirty' flag

  // extract cache line info from current address
  wire [COLUMN_IX_BITWIDTH-1:0] column_ix = address[COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:COLUMN_IX_BITWIDTH];
  wire [LINE_IX_BITWIDTH-1:0] line_ix =  address[LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:LINE_IX_BITWIDTH];
  wire [TAG_BITWIDTH-1:0] line_tag_from_address = address[TAG_BITWIDTH+LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:TAG_BITWIDTH];

  // starting address in burst RAM for the cache line containing the requested address
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] burst_cache_line_address = address[31:COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH]<<2;
  // note: <<2 because a cache line contains 4 reads from the burst (32 B / 8 B = 4)

  // 4 column cache line

  reg burst_reading;  // set if in burst read operation
  reg [31:0] burst_data_in_0;
  reg [31:0] burst_data_in_1;
  reg [31:0] burst_data_in_2;
  reg [31:0] burst_data_in_3;
  reg [31:0] burst_data_in_4;
  reg [31:0] burst_data_in_5;
  reg [31:0] burst_data_in_6;
  reg [31:0] burst_data_in_7;

  reg burst_writing;  // set if in burst write operation
  reg [3:0] burst_write_enable_tag;
  reg [3:0] burst_write_enable_0;
  reg [3:0] burst_write_enable_1;
  reg [3:0] burst_write_enable_2;
  reg [3:0] burst_write_enable_3;
  reg [3:0] burst_write_enable_4;
  reg [3:0] burst_write_enable_5;
  reg [3:0] burst_write_enable_6;
  reg [3:0] burst_write_enable_7;

  wire [31:0] line_tag_and_flags_from_cache;
  reg [3:0] write_enable_tag;
  reg [31:0] data_in_tag;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) tag (
      .clk(clk),
      .write_enable(write_enable_tag),
      .address(line_ix),
      .data_in(data_in_tag),
      .data_out(line_tag_and_flags_from_cache)
  );

  // extract portions of the combined tag, valid, dirty line info
  wire line_valid = line_tag_and_flags_from_cache[LINE_VALID_BIT];
  wire line_dirty = line_tag_and_flags_from_cache[LINE_DIRTY_BIT];
  wire [TAG_BITWIDTH-1:0] line_tag_from_cache = line_tag_and_flags_from_cache[TAG_BITWIDTH-1:0];

  // starting address in burst RAM for the cache line tag
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] burst_dirty_cache_line_address = {line_tag_from_cache,line_ix}<<2;
  // note: <<2 because a cache line contains a burst of 4 64 bit words (32 B / 8 B = 4)

  wire cache_line_hit = line_valid && line_tag_from_address == line_tag_from_cache;
  assign busy = !cache_line_hit;

  // 8 byte enabled semi dual port RAM blocks
  // 'data_in' connected either to the input if a cache hit write or to the state machine
  // that loads a cache lines
  wire [31:0] data0_out;
  reg  [ 3:0] write_enable_0;
  reg  [31:0] data_in_0;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data0 (
      .clk(clk),
      .write_enable(write_enable_0),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_0 : data_in_0),
      .data_out(data0_out)
  );

  wire [31:0] data1_out;
  reg  [ 3:0] write_enable_1;
  reg  [31:0] data_in_1;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data1 (
      .clk(clk),
      .write_enable(write_enable_1),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_1 : data_in_1),
      .data_out(data1_out)
  );

  wire [31:0] data2_out;
  reg  [ 3:0] write_enable_2;
  reg  [31:0] data_in_2;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data2 (
      .clk(clk),
      .write_enable(write_enable_2),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_2 : data_in_2),
      .data_out(data2_out)
  );

  wire [31:0] data3_out;
  reg  [ 3:0] write_enable_3;
  reg  [31:0] data_in_3;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data3 (
      .clk(clk),
      .write_enable(write_enable_3),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_3 : data_in_3),
      .data_out(data3_out)
  );

  wire [31:0] data4_out;
  reg  [ 3:0] write_enable_4;
  reg  [31:0] data_in_4;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data4 (
      .clk(clk),
      .write_enable(write_enable_4),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_4 : data_in_4),
      .data_out(data4_out)
  );

  wire [31:0] data5_out;
  reg  [ 3:0] write_enable_5;
  reg  [31:0] data_in_5;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data5 (
      .clk(clk),
      .write_enable(write_enable_5),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_5 : data_in_5),
      .data_out(data5_out)
  );

  wire [31:0] data6_out;
  reg  [ 3:0] write_enable_6;
  reg  [31:0] data_in_6;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data6 (
      .clk(clk),
      .write_enable(write_enable_6),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_6 : data_in_6),
      .data_out(data6_out)
  );

  wire [31:0] data7_out;
  reg  [ 3:0] write_enable_7;
  reg  [31:0] data_in_7;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data7 (
      .clk(clk),
      .write_enable(write_enable_7),
      .address(line_ix),
      .data_in(burst_reading ? burst_data_in_7 : data_in_7),
      .data_out(data7_out)
  );

  always @(*) begin
    case (column_ix)
      0: data_out = data0_out;
      1: data_out = data1_out;
      2: data_out = data2_out;
      3: data_out = data3_out;
      4: data_out = data4_out;
      5: data_out = data5_out;
      6: data_out = data6_out;
      7: data_out = data7_out;
    endcase

    // if it is a read
    data_out_ready = 0;
    if (!write_enable) begin
      data_out_ready = cache_line_hit;
    end

    // if it is a burst read of a cache line connect the 'write_enable_x' to
    // the the state machine 'burst_write_enable_x' register
    write_enable_tag = 0;
    data_in_tag = 0;
    write_enable_0 = 0;
    data_in_0 = 0;
    write_enable_1 = 0;
    data_in_1 = 0;
    write_enable_2 = 0;
    data_in_2 = 0;
    write_enable_3 = 0;
    data_in_3 = 0;
    write_enable_4 = 0;
    data_in_4 = 0;
    write_enable_5 = 0;
    data_in_5 = 0;
    write_enable_6 = 0;
    data_in_6 = 0;
    write_enable_7 = 0;
    data_in_7 = 0;

    if (burst_reading) begin
      // writing to the cache line in a burst read
      // wire the controls from burst control
      write_enable_tag = burst_write_enable_tag;
      write_enable_0 = burst_write_enable_0;
      write_enable_1 = burst_write_enable_1;
      write_enable_2 = burst_write_enable_2;
      write_enable_3 = burst_write_enable_3;
      write_enable_4 = burst_write_enable_4;
      write_enable_5 = burst_write_enable_5;
      write_enable_6 = burst_write_enable_6;
      write_enable_7 = burst_write_enable_7;
      data_in_tag = {1'b0, 1'b1, line_tag_from_address};
      // note: {dirty, valid, upper address bits}
    end else if (burst_writing) begin
      //
    end else if (write_enable) begin
`ifdef DBG
      $display("@(*) write 0x%h = 0x%h  mask: %b  line: %0d  column: %0d", address, data_in,
               write_enable, line_ix, column_ix);
`endif
      if (cache_line_hit) begin
`ifdef DBG
        $display("@(*) cache hit, set flag dirty");
`endif
        // enable write tag with dirty bit set
        write_enable_tag = 4'b1111;
        data_in_tag = {1'b1, 1'b1, line_tag_from_address};
        // note: { dirty, valid, tag }

        // connect 'data_in_x' to the input and set 'write_enable_x'
        // for the addressed data element in the cache line
        case (column_ix)
          0: begin
            write_enable_0 = write_enable;
            data_in_0 = data_in;
          end
          1: begin
            write_enable_1 = write_enable;
            data_in_1 = data_in;
          end
          2: begin
            write_enable_2 = write_enable;
            data_in_2 = data_in;
          end
          3: begin
            write_enable_3 = write_enable;
            data_in_3 = data_in;
          end
          4: begin
            write_enable_4 = write_enable;
            data_in_4 = data_in;
          end
          5: begin
            write_enable_5 = write_enable;
            data_in_5 = data_in;
          end
          6: begin
            write_enable_6 = write_enable;
            data_in_6 = data_in;
          end
          7: begin
            write_enable_7 = write_enable;
            data_in_7 = data_in;
          end
        endcase
      end else begin  // not (cache_line_hit)
`ifdef DBG
        $display("@(*) cache miss");
`endif
      end
    end else begin
`ifdef DBG
      $display("@(*) read 0x%h  line: %0d  column: %0d  data ready: %0d", address, line_ix,
               column_ix, data_out_ready);
`endif
    end
  end

  reg [10:0] state;
  localparam STATE_IDLE = 10'b00_0000_0001;
  localparam STATE_READ_WAIT_FOR_DATA_READY = 10'b00_0000_0010;
  localparam STATE_READ_1 = 10'b00_0000_0100;
  localparam STATE_READ_2 = 10'b00_0000_1000;
  localparam STATE_READ_3 = 10'b00_0001_0000;
  localparam STATE_READ_FINISH = 10'b00_0010_0000;
  localparam STATE_WRITE_1 = 10'b00_0100_0000;
  localparam STATE_WRITE_2 = 10'b00_1000_0000;
  localparam STATE_WRITE_3 = 10'b01_0000_0000;
  localparam STATE_WRITE_FINISH = 10'b10_0000_0000;

  always @(posedge clk) begin
    if (rst) begin
      burst_write_enable_tag <= 0;
      burst_write_enable_0 <= 0;
      burst_write_enable_1 <= 0;
      burst_write_enable_2 <= 0;
      burst_write_enable_3 <= 0;
      burst_write_enable_4 <= 0;
      burst_write_enable_5 <= 0;
      burst_write_enable_6 <= 0;
      burst_write_enable_7 <= 0;
      br_data_mask <= 4'b1111;
      burst_reading <= 0;
      burst_writing <= 0;
      state <= STATE_IDLE;
    end else begin
      case (state)

        STATE_IDLE: begin
          if (!cache_line_hit) begin
            // cache miss, start reading the addressed cache line
`ifdef DBG
            $display("@(c) cache miss address 0x%h  write mask: %b", address, write_enable);
`endif
            if (write_enable) begin
`ifdef DBG
              $display("@(c) write");
`endif
              // write
              if (line_dirty) begin
                // current cache line dirty; first write it back then read the addressed
                // cache line
`ifdef DBG
                $display("@(c) line dirty, evict to RAM address 0x%h",
                         burst_dirty_cache_line_address);
`endif
                br_cmd <= 1;  // command write
                br_addr <= burst_dirty_cache_line_address;
                br_cmd_en <= 1;
                br_wr_data[31:0] <= data0_out;
                br_wr_data[63:32] <= data1_out;
`ifdef DBG
                $display("@(c) write line (1): 0x%h%h", data0_out, data1_out);
`endif
                burst_writing <= 1;
                state <= STATE_WRITE_1;
              end
            end else begin  // not (line_dirty)
`ifdef DBG
              $display("@(c) read line from RAM address 0x%h", burst_cache_line_address);
`endif
              // read
              br_cmd <= 0;  // command read
              br_addr <= burst_cache_line_address;
              br_cmd_en <= 1;
              burst_reading <= 1;
              state <= STATE_READ_WAIT_FOR_DATA_READY;
            end
          end
        end

        STATE_READ_WAIT_FOR_DATA_READY: begin
          br_cmd_en <= 0;
          if (br_rd_data_ready) begin
            // first data has arrived
            burst_write_enable_0 <= 4'b1111;
            burst_data_in_0 <= br_rd_data[31:0];

            burst_write_enable_1 <= 4'b1111;
            burst_data_in_1 <= br_rd_data[63:32];
`ifdef DBG
            $display("@(c) read line (1): 0x%h", br_rd_data);
`endif
            state <= STATE_READ_1;
          end
        end

        STATE_READ_1: begin
          // second data has arrived
          burst_write_enable_0 <= 0;
          burst_write_enable_1 <= 0;

          burst_write_enable_2 <= 4'b1111;
          burst_data_in_2 <= br_rd_data[31:0];

          burst_write_enable_3 <= 4'b1111;
          burst_data_in_3 <= br_rd_data[63:32];
`ifdef DBG
          $display("@(c) read line (2): 0x%h", br_rd_data);
`endif
          state <= STATE_READ_2;
        end

        STATE_READ_2: begin
          // third data has arrived
          burst_write_enable_2 <= 0;
          burst_write_enable_3 <= 0;

          burst_write_enable_4 <= 4'b1111;
          burst_data_in_4 <= br_rd_data[31:0];

          burst_write_enable_5 <= 4'b1111;
          burst_data_in_5 <= br_rd_data[63:32];
`ifdef DBG
          $display("@(c) read line (3): 0x%h", br_rd_data);
`endif
          state <= STATE_READ_3;
        end

        STATE_READ_3: begin
          // last data has arrived
          burst_write_enable_4 <= 0;
          burst_write_enable_5 <= 0;

          burst_write_enable_6 <= 4'b1111;
          burst_data_in_6 <= br_rd_data[31:0];

          burst_write_enable_7 <= 4'b1111;
          burst_data_in_7 <= br_rd_data[63:32];

          // write the tag
          burst_write_enable_tag <= 4'b1111;
`ifdef DBG
          $display("@(c) read line (4): 0x%h", br_rd_data);
`endif
          state <= STATE_READ_FINISH;
        end

        STATE_READ_FINISH: begin
          burst_write_enable_6 <= 0;
          burst_write_enable_7 <= 0;
          // note: reading line can be initiated after a cache eviction
          //       'burst_write_enable_6' and 7 are then high, set to low
          burst_write_enable_tag <= 0;
          burst_reading <= 0;
          state <= STATE_IDLE;
        end

        STATE_WRITE_1: begin
`ifdef DBG
          $display("@(c) write line (2): 0x%h%h", data2_out, data3_out);
`endif
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data2_out;
          br_wr_data[63:32] <= data3_out;
          state <= STATE_WRITE_2;
        end

        STATE_WRITE_2: begin
`ifdef DBG
          $display("@(c) write line (3): 0x%h%h", data4_out, data5_out);
`endif
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data4_out;
          br_wr_data[63:32] <= data5_out;
          state <= STATE_WRITE_3;
        end

        STATE_WRITE_3: begin
`ifdef DBG
          $display("@(c) write line (4): 0x%h%h", data6_out, data7_out);
`endif
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data6_out;
          br_wr_data[63:32] <= data7_out;
          state <= STATE_WRITE_FINISH;
        end

        STATE_WRITE_FINISH: begin
`ifdef DBG
          $display("@(c) read line after eviction from RAM address 0x%h", burst_cache_line_address);
`endif
          // start reading the cache line
          br_cmd <= 0;  // command read
          br_addr <= burst_cache_line_address;
          br_cmd_en <= 1;
          burst_writing <= 0;
          burst_reading <= 1;
          state <= STATE_READ_WAIT_FOR_DATA_READY;
        end

      endcase
    end
  end

endmodule

`default_nettype wire
`undef DBG
`undef INFO
