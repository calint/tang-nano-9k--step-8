//
// cache interfacing with burst ram memory
//
`default_nettype none

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

    // burst ram wiring
    output reg br_cmd,  // 0: read, 1: write
    output reg br_cmd_en,  // 1: cmd and addr is valid
    output reg [BURST_RAM_DEPTH_BITWIDTH-1:0] br_addr,  // 8 bytes word
    output reg [63:0] br_wr_data,  // data to write
    output reg [7:0] br_data_mask,  // not implemented (same as 0 in IP component)
    input wire [63:0] br_rd_data,  // read data
    input wire br_rd_data_ready,  // rd_data is valid
    input wire br_busy
);

  localparam ZEROS_BITWIDTH = 2;  // leading zeros in the address
  localparam COLUMN_IX_BITWIDTH = 3;  // 8 elements per line
  localparam LINE_COUNT = 2 ** LINE_IX_BITWIDTH;
  localparam TAG_BITWIDTH = 32 - LINE_IX_BITWIDTH - COLUMN_IX_BITWIDTH - ZEROS_BITWIDTH;
  localparam LINE_VALID_BIT = TAG_BITWIDTH;
  localparam LINE_DIRTY_BIT = TAG_BITWIDTH + 1;

  // wires dividing the address into components
  // |tag|line| col |00| address
  //                |00| ignored (4 bytes word aligned)
  //          | col |    data_ix: the index of the data in the cached line
  //     |line|          line_ix: index in array where tag and cached data is stored
  // |tag|               tag: the rest of the upper bits of the address

  // extract cache line info from current address
  wire [COLUMN_IX_BITWIDTH-1:0] column_ix = address[COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:COLUMN_IX_BITWIDTH];
  wire [LINE_IX_BITWIDTH-1:0] line_ix =  address[LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:LINE_IX_BITWIDTH];
  wire [TAG_BITWIDTH-1:0] line_tag_in = address[TAG_BITWIDTH+LINE_IX_BITWIDTH+COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH-1-:TAG_BITWIDTH];

  // starting address in burst ram for the cache line containing the requested address
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] burst_ram_cache_line_address = address[31:COLUMN_IX_BITWIDTH+ZEROS_BITWIDTH]<<2;
  // note: <<2 because a cache line contains 4 reads from the burst (32 B / 8 B = 4)

  // 4 column cache line

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) tag (
      .clk(clk),
      .write_enable(write_enable_tag),
      .address(line_ix),
      .data_in(tag_data_in),
      .data_out(line_tag_and_valid_dirty)
  );
  wire [31:0] line_tag_and_valid_dirty;
  reg [3:0] write_enable_tag;
  reg [31:0] tag_data_in;
  reg write_line_dirty_bit;

  // extract portions of the combined tag, valid, dirty line info
  wire line_valid = line_tag_and_valid_dirty[LINE_VALID_BIT];
  wire line_dirty = line_tag_and_valid_dirty[LINE_DIRTY_BIT];
  wire [TAG_BITWIDTH-1:0] line_tag = line_tag_and_valid_dirty[TAG_BITWIDTH-1:0];

  // starting address in burst ram for the cache line tag
  wire [BURST_RAM_DEPTH_BITWIDTH-1:0] burst_ram_dirty_cache_line_write_address = {line_tag,line_ix}<<2;
  // note: <<2 because a cache line contains 4 burst ram words (32 B / 8 B = 4)

  wire cache_line_hit = line_valid && line_tag_in == line_tag;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data0 (
      .clk(clk),
      .write_enable(write_enable_0),
      .address(line_ix),
      .data_in(data_in_0),
      .data_out(data0_out)
  );
  wire [31:0] data0_out;
  reg  [ 3:0] write_enable_0;
  reg  [31:0] data_in_0;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data1 (
      .clk(clk),
      .write_enable(write_enable_1),
      .address(line_ix),
      .data_in(data_in_1),
      .data_out(data1_out)
  );
  wire [31:0] data1_out;
  reg  [ 3:0] write_enable_1;
  reg  [31:0] data_in_1;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data2 (
      .clk(clk),
      .write_enable(write_enable_2),
      .address(line_ix),
      .data_in(data_in_2),
      .data_out(data2_out)
  );
  wire [31:0] data2_out;
  reg  [ 3:0] write_enable_2;
  reg  [31:0] data_in_2;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data3 (
      .clk(clk),
      .write_enable(write_enable_3),
      .address(line_ix),
      .data_in(data_in_3),
      .data_out(data3_out)
  );
  wire [31:0] data3_out;
  reg  [ 3:0] write_enable_3;
  reg  [31:0] data_in_3;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data4 (
      .clk(clk),
      .write_enable(write_enable_4),
      .address(line_ix),
      .data_in(data_in_4),
      .data_out(data4_out)
  );
  wire [31:0] data4_out;
  reg  [ 3:0] write_enable_4;
  reg  [31:0] data_in_4;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data5 (
      .clk(clk),
      .write_enable(write_enable_5),
      .address(line_ix),
      .data_in(data_in_5),
      .data_out(data5_out)
  );
  wire [31:0] data5_out;
  reg  [ 3:0] write_enable_5;
  reg  [31:0] data_in_5;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data6 (
      .clk(clk),
      .write_enable(write_enable_6),
      .address(line_ix),
      .data_in(data_in_6),
      .data_out(data6_out)
  );
  wire [31:0] data6_out;
  reg  [ 3:0] write_enable_6;
  reg  [31:0] data_in_6;

  BESDPB #(
      .ADDRESS_BITWIDTH(LINE_IX_BITWIDTH)
  ) data7 (
      .clk(clk),
      .write_enable(write_enable_7),
      .address(line_ix),
      .data_in(data_in_7),
      .data_out(data7_out)
  );
  wire [31:0] data7_out;
  reg  [ 3:0] write_enable_7;
  reg  [31:0] data_in_7;

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

    // if it is a write
    write_enable_tag = 0;
    tag_data_in = 0;
    write_enable_0 = 0;
    write_enable_1 = 0;
    write_enable_2 = 0;
    write_enable_3 = 0;
    write_enable_4 = 0;
    write_enable_5 = 0;
    write_enable_6 = 0;
    write_enable_7 = 0;

    if (burst_fetching) begin
      // writing to the cache line in a burst read
      // wire the controls from burst control
      write_enable_tag = burst_write_enable_tag;
      write_enable_0   = burst_write_enable_0;
      write_enable_1   = burst_write_enable_1;
      write_enable_2   = burst_write_enable_2;
      write_enable_3   = burst_write_enable_3;
      write_enable_4   = burst_write_enable_4;
      write_enable_5   = burst_write_enable_5;
      write_enable_6   = burst_write_enable_6;
      write_enable_7   = burst_write_enable_7;
    end else if (write_enable) begin
      if (cache_line_hit) begin
        write_enable_tag = 4'b1111;
        tag_data_in = {1'b1, 1'b1, line_tag_in};
        // note: { dirty, valid, tag }
        case (column_ix)
          0: write_enable_0 = write_enable;
          1: write_enable_1 = write_enable;
          2: write_enable_2 = write_enable;
          3: write_enable_3 = write_enable;
          4: write_enable_4 = write_enable;
          5: write_enable_5 = write_enable;
          6: write_enable_6 = write_enable;
          7: write_enable_7 = write_enable;
        endcase
      end else begin  // not (cache_line_hit)
      end
    end
  end

  reg [7:0] state;
  localparam STATE_IDLE = 8'b0000_0001;
  localparam STATE_FETCH_WAIT_FOR_DATA_READY = 8'b0000_0010;
  localparam STATE_FETCH_READ_1 = 8'b0000_0100;
  localparam STATE_FETCH_READ_2 = 8'b0000_1000;
  localparam STATE_FETCH_READ_3 = 8'b0001_0000;
  localparam STATE_FETCH_READ_FINISH = 8'b0010_0000;
  localparam STATE_WRITE_1 = 8'b0000_0100;
  localparam STATE_WRITE_2 = 8'b0000_1000;
  localparam STATE_WRITE_3 = 8'b0001_0000;
  localparam STATE_WRITE_FINISH = 8'b0010_0000;

  reg burst_fetching;  // high if in burst fetch operation
  reg burst_writing;  // high if in burst write operation

  assign busy = burst_fetching | burst_writing;

  reg [3:0] burst_write_enable_tag;
  reg [3:0] burst_write_enable_0;
  reg [3:0] burst_write_enable_1;
  reg [3:0] burst_write_enable_2;
  reg [3:0] burst_write_enable_3;
  reg [3:0] burst_write_enable_4;
  reg [3:0] burst_write_enable_5;
  reg [3:0] burst_write_enable_6;
  reg [3:0] burst_write_enable_7;

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
      burst_fetching <= 0;
      burst_writing <= 0;
      state <= STATE_IDLE;
    end else begin
      case (state)

        STATE_IDLE: begin
          if (!cache_line_hit) begin
            if (write_enable) begin
              // write
              if (line_dirty) begin
                br_cmd <= 1;  // command write
                br_addr <= burst_ram_dirty_cache_line_write_address;
                br_cmd_en <= 1;
                br_wr_data[31:0] <= data0_out;
                br_wr_data[63:32] <= data1_out;
                burst_writing <= 1;
                state <= STATE_WRITE_1;
              end
            end else begin
              // read
              br_cmd <= 0;  // command read
              br_addr <= burst_ram_cache_line_address;
              br_cmd_en <= 1;
              burst_fetching <= 1;
              state <= STATE_FETCH_WAIT_FOR_DATA_READY;
            end
          end
        end

        STATE_FETCH_WAIT_FOR_DATA_READY: begin
          br_cmd_en <= 0;
          if (br_rd_data_ready) begin
            // first data has arrived
            burst_write_enable_0 <= 4'b1111;
            data_in_0 <= br_rd_data[31:0];

            burst_write_enable_1 <= 4'b1111;
            data_in_1 <= br_rd_data[63:32];
            state <= STATE_FETCH_READ_1;
          end
        end

        STATE_FETCH_READ_1: begin
          // second data has arrived
          burst_write_enable_0 <= 0;
          burst_write_enable_1 <= 0;

          burst_write_enable_2 <= 4'b1111;
          data_in_2 <= br_rd_data[31:0];

          burst_write_enable_3 <= 4'b1111;
          data_in_3 <= br_rd_data[63:32];

          state <= STATE_FETCH_READ_2;
        end

        STATE_FETCH_READ_2: begin
          // third data has arrived
          burst_write_enable_2 <= 0;
          burst_write_enable_3 <= 0;

          burst_write_enable_4 <= 4'b1111;
          data_in_4 <= br_rd_data[31:0];

          burst_write_enable_5 <= 4'b1111;
          data_in_5 <= br_rd_data[63:32];

          state <= STATE_FETCH_READ_3;
        end

        STATE_FETCH_READ_3: begin
          // last data has arrived
          burst_write_enable_4 <= 0;
          burst_write_enable_5 <= 0;

          burst_write_enable_6 <= 4'b1111;
          data_in_6 <= br_rd_data[31:0];

          burst_write_enable_7 <= 4'b1111;
          data_in_7 <= br_rd_data[63:32];

          // write the tag
          burst_write_enable_tag <= 4'b1111;
          write_line_dirty_bit <= 0;

          state <= STATE_FETCH_READ_FINISH;
        end

        STATE_FETCH_READ_FINISH: begin
          burst_write_enable_6 <= 0;
          burst_write_enable_7 <= 0;
          burst_write_enable_tag <= 0;
          burst_fetching <= 0;
          state <= STATE_IDLE;
        end

        STATE_WRITE_1: begin
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data2_out;
          br_wr_data[63:32] <= data3_out;
          state <= STATE_WRITE_2;
        end

        STATE_WRITE_2: begin
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data4_out;
          br_wr_data[63:32] <= data5_out;
          state <= STATE_WRITE_3;
        end

        STATE_WRITE_3: begin
          br_cmd_en <= 0;
          br_wr_data[31:0] <= data6_out;
          br_wr_data[63:32] <= data7_out;
          state <= STATE_WRITE_FINISH;
        end

        STATE_WRITE_FINISH: begin
          // start reading the cache line
          br_cmd <= 0;  // command read
          br_addr <= burst_ram_cache_line_address;
          br_cmd_en <= 1;
          burst_writing <= 0;
          state <= STATE_FETCH_WAIT_FOR_DATA_READY;
        end

      endcase
    end
  end

endmodule

`default_nettype wire
