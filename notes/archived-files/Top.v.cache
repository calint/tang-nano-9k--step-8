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

  Cache #(
      .LINE_IX_BITWIDTH(10)
  ) cache (
      .clk(sys_clk),
      .rst_n(sys_rst_n),
      .address(address),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .data_in(data_in),
      .write_enable(write_enable)
  );

  reg [31:0] address;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in;
  reg [3:0] write_enable;

  reg [3:0] state;

  // some code so that Gowin EDA doesn't optimize it away
  always @(posedge sys_clk) begin
    if (!sys_rst_n) begin
      state   <= 0;
      address <= 0;
    end else begin
      led[5] = btn1;  // note: to rid off 'unused warning'
      case (state)
        0: begin
          led <= {data_out_ready, data_out[3:0]};
          data_in <= 32'h1234_5678;
          write_enable <= 4'b1111;
          state <= 1;
        end
        1: begin
          led <= {data_out_ready, data_out[3:0]};
          write_enable <= 0;
          address <= address + 4;
          state <= 2;
        end
        2: begin
          led <= {data_out_ready, data_out[3:0]};
          data_in <= 32'h1234_5678;
          write_enable <= 4'b1111;
          state <= 3;
        end
        3: begin
          led <= {data_out_ready, data_out[3:0]};
          write_enable <= 0;
          address <= address + 4;
          state <= 0;
        end
      endcase
    end
  end

endmodule

`default_nettype wire
