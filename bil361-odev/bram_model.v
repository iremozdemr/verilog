`timescale 1ns / 1ps

module bram_model #(
   parameter  DATA_WIDTH = 32,
   parameter  BRAM_DEPTH = 128,
   localparam ADDR_WIDTH = $clog2(BRAM_DEPTH)
) (
   input                       clk_i,
   input      [DATA_WIDTH-1:0] data_i,
   input      [ADDR_WIDTH-1:0] addr_i,
   input                       wr_en_i,
   input                       cmd_en_i,
   output reg [DATA_WIDTH-1:0] data_o
);

   reg [DATA_WIDTH-1:0] ram[0:(1<<ADDR_WIDTH)-1];

   always @(posedge clk_i) begin
      if (cmd_en_i) begin
         if (wr_en_i) begin
            ram[addr_i] <= data_i;
         end
         data_o <= ram[addr_i];
      end
   end
endmodule
