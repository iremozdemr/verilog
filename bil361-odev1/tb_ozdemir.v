`timescale 1ns/1ps
module tb_ozdemir;
  reg clk_i = 0;
  reg rst_i = 1;
  wire [31:0] pc_o;
  wire [1023:0] regs_o;
  wire data_mem_we_o;
  wire [31:0] data_mem_addr_o;
  wire [31:0] data_mem_wdata_o;
  reg  [31:0] data_mem_rdata_i;
  reg  [31:0] inst_i;
  wire [1:0]  cur_stage_o;

  ozdemir dut(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .inst_i(inst_i),
    .pc_o(pc_o),
    .regs_o(regs_o),
    .data_mem_we_o(data_mem_we_o),
    .data_mem_addr_o(data_mem_addr_o),
    .data_mem_wdata_o(data_mem_wdata_o),
    .data_mem_rdata_i(data_mem_rdata_i),
    .cur_stage_o(cur_stage_o)
  );

  reg [31:0] rom_le [0:63];
  reg [31:0] dmem   [0:255];

  function [31:0] to_le(input [31:0] w);
    begin
      to_le = {w[7:0], w[15:8], w[23:16], w[31:24]};
    end
  endfunction

  function [31:0] getreg(input [1023:0] bus, input integer idx);
    begin
      getreg = bus[(31-idx)*32 +: 32];
    end
  endfunction

  always #5 clk_i = ~clk_i;

  always @(*) begin
    inst_i = rom_le[pc_o[31:2]];
  end

  always @(*) begin
    data_mem_rdata_i = dmem[data_mem_addr_o[31:2]];
  end

  always @(posedge clk_i) begin
    if (data_mem_we_o) dmem[data_mem_addr_o[31:2]] <= data_mem_wdata_o;
  end

  integer i;
  initial begin
    for (i = 0; i < 64; i = i + 1) rom_le[i] = to_le(32'h00000013);
    for (i = 0; i < 256; i = i + 1) dmem[i] = 32'h00000000;

    rom_le[0] = to_le(32'h000120B7);
    rom_le[1] = to_le(32'h00508093);
    rom_le[2] = to_le(32'h00102023);
    rom_le[3] = to_le(32'h00002103);
    rom_le[4] = to_le(32'h0020F1B3);

    $dumpfile("chk.vcd");
    $dumpvars(0, tb_ozdemir);

    #20 rst_i = 0;
    #400;

    if (dmem[0] !== 32'h00012005) $fatal(1, "DMEM_MISMATCH");
    if (getreg(regs_o, 1) !== 32'h00012005) $fatal(1, "X1_MISMATCH");
    if (getreg(regs_o, 2) !== 32'h00012005) $fatal(1, "X2_MISMATCH");
    if (getreg(regs_o, 3) !== 32'h00012005) $fatal(1, "X3_MISMATCH");

    $display("PASS");
    $finish;
  end
endmodule