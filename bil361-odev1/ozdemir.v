module ozdemir(
  input  wire        clk_i,
  input  wire        rst_i,
  input  wire [31:0] inst_i,
  output reg  [31:0] pc_o,
  output wire [1023:0] regs_o,
  output reg         data_mem_we_o,
  output reg  [31:0] data_mem_addr_o,
  output reg  [31:0] data_mem_wdata_o,
  input  wire [31:0] data_mem_rdata_i,
  output reg  [1:0]  cur_stage_o
);

  reg [31:0] pc_reg;
  reg [31:0] rfile[0:31];
  reg [31:0] instr;
  reg [1:0]  phase;

  reg [4:0]  rd_q, rs1_q, rs2_q;
  reg [31:0] rs1_val_q, rs2_val_q;
  reg [31:0] immI_q, immS_q, immB_q, immU_q, immJ_q;

  reg        is_load_q;
  reg        is_store_q;

  reg        ex_wb_en_q;
  reg [31:0] ex_result_q;
  reg        ex_pc_jump_q;
  reg [31:0] ex_pc_next_q;

  reg [7:0]  ex_left;
  reg [1:0]  srt_step_q;
  reg [1:0]  ldmax_step_q;
  reg [31:0] ldmax_rd_q, ldmax_rs1_q, ldmax_rs2_q;

  reg        mac_active;
  reg [31:0] mac_addr_accum, mac_addr_a, mac_addr_b;
  reg [31:0] mac_val_a, mac_val_b;

  function [31:0] sext12(input [11:0] x);
    begin
      sext12 = {{20{x[11]}}, x};
    end
  endfunction

  function [31:0] zext12(input [11:0] x);
    begin
      zext12 = {20'b0, x};
    end
  endfunction

  function [31:0] sext13_b(input [12:0] x);
    begin
      sext13_b = {{19{x[12]}}, x};
    end
  endfunction

  function [31:0] sext21_j(input [20:0] x);
    begin
      sext21_j = {{11{x[20]}}, x};
    end
  endfunction

  function [31:0] sext11(input [10:0] x);
    begin
      sext11 = {{21{x[10]}}, x};
    end
  endfunction

  genvar gi;
  generate
    for (gi=0; gi<32; gi=gi+1) begin : G_PACK
      assign regs_o[(31-gi)*32 +: 32] = rfile[gi];
    end
  endgenerate

  integer i;

  wire [6:0] opcode = instr[6:0];
  wire [2:0] funct3 = instr[14:12];
  wire [6:0] funct7 = instr[31:25];
  wire [4:0] rd     = instr[11:7];
  wire [4:0] rs1    = instr[19:15];
  wire [4:0] rs2    = instr[24:20];

  localparam [6:0] OPC_STD_LUI   = 7'b0110111;
  localparam [6:0] OPC_STD_AUIPC = 7'b0010111;
  localparam [6:0] OPC_STD_JAL   = 7'b1101111;
  localparam [6:0] OPC_STD_JALR  = 7'b1100111;
  localparam [6:0] OPC_STD_LOAD  = 7'b0000011;
  localparam [6:0] OPC_STD_STORE = 7'b0100011;
  localparam [6:0] OPC_STD_BR    = 7'b1100011;
  localparam [6:0] OPC_STD_ALUI  = 7'b0010011;
  localparam [6:0] OPC_STD_ALUR  = 7'b0110011;

  localparam [6:0] OPC_C1 = 7'b1110111;
  localparam [6:0] OPC_C2 = 7'b1111111;

  wire op_subabs = (opcode==OPC_C1) && (funct7==7'b0000000) && (funct3==3'b000);
  wire op_avg    = (opcode==OPC_C1) && (funct3==3'b100);
  wire op_movu   = (opcode==OPC_C1) && (funct3==3'b101);
  wire op_srt    = (opcode==OPC_C1) && (funct7==7'b0000010) && (funct3==3'b001);
  wire op_ldmax  = (opcode==OPC_C1) && (funct7==7'b0000100) && (funct3==3'b110);
  wire op_srch   = (opcode==OPC_C1) && (funct7==7'b0001000) && (funct3==3'b111);
  wire op_selp   = (opcode==OPC_C1) && (funct3==3'b010);
  wire op_selc   = (opcode==OPC_C2) && (funct3==3'b000);
  wire op_mac    = (opcode==OPC_C2) && (funct3==3'b111);

  wire [31:0] immI_w = sext12(instr[31:20]);
  wire [31:0] immS_w = sext12({instr[31:25], instr[11:7]});
  wire [12:0] immB_p = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  wire [31:0] immB_w = sext13_b(immB_p);
  wire [31:0] immU_w = {instr[31:12], 12'b0};
  wire [20:0] immJ_p = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
  wire [31:0] immJ_w = sext21_j(immJ_p);

  wire        sel_s1  = instr[31];
  wire [1:0]  sel_s2  = instr[31:30];

  wire [10:0] immC2_p = {instr[7], instr[29:25], instr[11:8], 1'b0};
  wire [31:0] immC2_w = sext11(immC2_p);

  wire [31:0] canon_i = { inst_i[7:0], inst_i[15:8], inst_i[23:16], inst_i[31:24] };

  always @* begin
    immI_q = immI_w;
    immS_q = immS_w;
    immB_q = immB_w;
    immU_q = immU_w;
    immJ_q = immJ_w;
  end

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      pc_reg          <= 32'd0;
      pc_o            <= 32'd0;
      phase           <= 2'd0;
      cur_stage_o     <= 2'd0;
      instr           <= 32'd0;
      data_mem_we_o   <= 1'b0;
      data_mem_addr_o <= 32'd0;
      data_mem_wdata_o<= 32'd0;
      is_load_q       <= 1'b0;
      is_store_q      <= 1'b0;
      ex_wb_en_q      <= 1'b0;
      ex_result_q     <= 32'd0;
      ex_pc_jump_q    <= 1'b0;
      ex_pc_next_q    <= 32'd0;
      ex_left         <= 8'd0;
      srt_step_q      <= 2'd0;
      ldmax_step_q    <= 2'd0;
      ldmax_rd_q      <= 32'd0;
      ldmax_rs1_q     <= 32'd0;
      ldmax_rs2_q     <= 32'd0;
      mac_active      <= 1'b0;
      mac_addr_accum  <= 32'd0;
      mac_addr_a      <= 32'd0;
      mac_addr_b      <= 32'd0;
      mac_val_a       <= 32'd0;
      mac_val_b       <= 32'd0;
      for (i=0;i<32;i=i+1) rfile[i] <= 32'd0;
    end else begin
      rfile[0] <= 32'd0;

      case (phase)
        2'd0: begin
          cur_stage_o <= 2'd0;
          pc_o        <= pc_reg;
          instr       <= canon_i;
          phase       <= 2'd1;
        end

        2'd1: begin
          cur_stage_o <= 2'd1;
          rd_q        <= rd;
          rs1_q       <= rs1;
          rs2_q       <= rs2;
          rs1_val_q   <= rfile[rs1];
          rs2_val_q   <= rfile[rs2];

          is_load_q   <= (opcode==OPC_STD_LOAD)  && (funct3==3'b010);
          is_store_q  <= (opcode==OPC_STD_STORE) && (funct3==3'b010);

          if (op_srt) begin
            ex_left    <= 8'd2;
            srt_step_q <= 2'd0;
            mac_active <= 1'b0;
          end else if (op_ldmax) begin
            ex_left      <= 8'd3;
            ldmax_step_q <= 2'd0;
            mac_active   <= 1'b0;
          end else if (op_mac) begin
            ex_left        <= ({6'b0, sel_s2} + 8'd1) * 8'd4;
            mac_addr_accum <= immC2_w;
            mac_addr_a     <= rfile[rs1];
            mac_addr_b     <= rfile[rs2];
            mac_val_a      <= 32'd0;
            mac_val_b      <= 32'd0;
            mac_active     <= 1'b1;
          end else begin
            ex_left    <= 8'd0;
            mac_active <= 1'b0;
          end

          ex_wb_en_q   <= 1'b0;
          ex_result_q  <= 32'd0;
          ex_pc_jump_q <= 1'b0;
          ex_pc_next_q <= 32'd0;

          phase <= 2'd2;
        end

        2'd2: begin
          cur_stage_o      <= 2'd2;
          data_mem_we_o    <= 1'b0;
          data_mem_addr_o  <= 32'd0;
          data_mem_wdata_o <= 32'd0;

          if (is_load_q) begin
            data_mem_addr_o <= rs1_val_q + immI_q;
            ex_result_q     <= data_mem_rdata_i;
            ex_wb_en_q      <= (rd_q!=5'd0);
          end
          if (is_store_q) begin
            data_mem_addr_o <= rs1_val_q + immS_q;
            data_mem_wdata_o<= rs2_val_q;
            data_mem_we_o   <= 1'b1;
            ex_wb_en_q      <= 1'b0;
            ex_result_q     <= 32'd0;
          end

          if (op_srt) begin
            if (ex_left > 0) begin
              if (srt_step_q==2'd0) begin
                data_mem_addr_o  <= rfile[rd_q];
                data_mem_wdata_o <= ($signed(rs1_val_q) <= $signed(rs2_val_q)) ? rs1_val_q : rs2_val_q;
                data_mem_we_o    <= 1'b1;
                srt_step_q       <= 2'd1;
              end else begin
                data_mem_addr_o  <= rfile[rd_q] + 32'd4;
                data_mem_wdata_o <= ($signed(rs1_val_q) > $signed(rs2_val_q)) ? rs1_val_q : rs2_val_q;
                data_mem_we_o    <= 1'b1;
              end
              ex_left <= ex_left - 8'd1;
            end
          end else if (op_ldmax) begin
            if (ex_left > 0) begin
              case (ldmax_step_q)
                2'd0: begin
                  data_mem_addr_o <= rfile[rd_q];
                  ldmax_rd_q      <= data_mem_rdata_i;
                  ldmax_step_q    <= 2'd1;
                end
                2'd1: begin
                  data_mem_addr_o <= rfile[rs1_q];
                  ldmax_rs1_q     <= data_mem_rdata_i;
                  ldmax_step_q    <= 2'd2;
                end
                default: begin
                  data_mem_addr_o <= rfile[rs2_q];
                  ldmax_rs2_q     <= data_mem_rdata_i;
                end
              endcase
              ex_left <= ex_left - 8'd1;
            end
            if (ex_left==8'd1) begin
              ex_result_q <= ( ((ldmax_rd_q >= ldmax_rs1_q) ? ldmax_rd_q : ldmax_rs1_q) >= ldmax_rs2_q )
                              ? ((ldmax_rd_q >= ldmax_rs1_q) ? ldmax_rd_q : ldmax_rs1_q)
                              : ldmax_rs2_q;
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
          end else if (mac_active) begin
            if (ex_left > 0) begin
              case ((ex_left-8'd1) & 8'h03)
                8'd3: begin
                  data_mem_addr_o <= mac_addr_a;
                end
                8'd2: begin
                  mac_val_a       <= data_mem_rdata_i;
                  data_mem_addr_o <= mac_addr_b;
                end
                8'd1: begin
                  mac_val_b       <= data_mem_rdata_i;
                  data_mem_addr_o <= mac_addr_accum;
                end
                default: begin
                  data_mem_addr_o  <= mac_addr_accum;
                  data_mem_wdata_o <= data_mem_rdata_i + (mac_val_a * mac_val_b);
                  data_mem_we_o    <= 1'b1;
                  mac_addr_a       <= mac_addr_a + 32'd4;
                  mac_addr_b       <= mac_addr_b + 32'd4;
                end
              endcase
              ex_left <= ex_left - 8'd1;
            end
            if (ex_left==8'd1) begin
              ex_wb_en_q  <= 1'b0;
              ex_result_q <= 32'd0;
            end
          end else begin
            case (opcode)
              OPC_STD_LUI:   begin ex_wb_en_q<=1'b1; ex_result_q<=immU_q; end
              OPC_STD_AUIPC: begin ex_wb_en_q<=1'b1; ex_result_q<=pc_reg + immU_q; end
              OPC_STD_JAL:   begin ex_wb_en_q<= (rd_q!=5'd0); ex_result_q<= pc_reg + 32'd4; ex_pc_jump_q<=1'b1; ex_pc_next_q<= pc_reg + immJ_q; end
              OPC_STD_JALR:  begin ex_wb_en_q<= (rd_q!=5'd0); ex_result_q<= pc_reg + 32'd4; ex_pc_jump_q<=1'b1; ex_pc_next_q<= (rs1_val_q + immI_q) & ~32'd1; end
              OPC_STD_BR: begin
                if ((funct3==3'b000 && (rs1_val_q==rs2_val_q)) ||
                    (funct3==3'b101 && ($signed(rs1_val_q) >= $signed(rs2_val_q)))) begin
                  ex_pc_jump_q <= 1'b1;
                  ex_pc_next_q <= pc_reg + immB_q;
                end
                ex_wb_en_q <= 1'b0;
                ex_result_q<=32'd0;
              end
              OPC_STD_ALUI: begin
                case (funct3)
                  3'b000: begin ex_result_q <= rs1_val_q + immI_q; ex_wb_en_q <= (rd_q!=5'd0); end
                  3'b011: begin ex_result_q <= ($unsigned(rs1_val_q) < $unsigned(immI_q)) ? 32'd1 : 32'd0; ex_wb_en_q <= (rd_q!=5'd0); end
                  3'b100: begin ex_result_q <= rs1_val_q ^ immI_q; ex_wb_en_q <= (rd_q!=5'd0); end
                  3'b001: begin ex_result_q <= rs1_val_q << instr[24:20]; ex_wb_en_q <= (rd_q!=5'd0); end
                  default: begin ex_result_q <= 32'd0; ex_wb_en_q <= 1'b0; end
                endcase
              end
              OPC_STD_ALUR: begin
                if      (funct3==3'b000 && funct7==7'b0000000) begin ex_result_q<= rs1_val_q + rs2_val_q; ex_wb_en_q<=(rd_q!=5'd0); end
                else if (funct3==3'b000 && funct7==7'b0100000) begin ex_result_q<= rs1_val_q - rs2_val_q; ex_wb_en_q<=(rd_q!=5'd0); end
                else if (funct3==3'b010 && funct7==7'b0000000) begin ex_result_q<= ($signed(rs1_val_q) <  $signed(rs2_val_q)) ? 32'd1:32'd0; ex_wb_en_q<=(rd_q!=5'd0); end
                else if (funct3==3'b011 && funct7==7'b0000000) begin ex_result_q<= ($unsigned(rs1_val_q)< $unsigned(rs2_val_q)) ? 32'd1:32'd0; ex_wb_en_q<=(rd_q!=5'd0); end
                else if (funct3==3'b101 && funct7==7'b0100000) begin ex_result_q<= $signed(rs1_val_q) >>> rs2_val_q[4:0]; ex_wb_en_q<=(rd_q!=5'd0); end
                else if (funct3==3'b111 && funct7==7'b0000000) begin ex_result_q<= rs1_val_q & rs2_val_q; ex_wb_en_q<=(rd_q!=5'd0); end
                else begin ex_result_q<=32'd0; ex_wb_en_q<=1'b0; end
              end
              default: begin end
            endcase

            if (op_subabs) begin
              if ($signed(rs1_val_q - rs2_val_q) < 0)
                ex_result_q <= rs2_val_q - rs1_val_q;
              else
                ex_result_q <= rs1_val_q - rs2_val_q;
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
            if (op_avg) begin
              ex_result_q <= $signed(rs1_val_q + immI_q) >>> 1;
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
            if (op_movu) begin
              ex_result_q <= zext12(instr[31:20]);
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
            if (op_srch) begin
              ex_result_q <= ((rfile[rs1_q][7:0]   == rs2_val_q[7:0]) ||
                              (rfile[rs1_q][15:8]  == rs2_val_q[7:0]) ||
                              (rfile[rs1_q][23:16] == rs2_val_q[7:0]) ||
                              (rfile[rs1_q][31:24] == rs2_val_q[7:0])) ? 32'd1 : 32'd0;
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
            if (op_selp) begin
              ex_result_q <= sel_s1 ? {16'b0, rs1_val_q[31:16]} : {16'b0, rs1_val_q[15:0]};
              ex_wb_en_q  <= (rd_q!=5'd0);
            end
            if (op_selc) begin
              if (sel_s2!=2'b11) begin
                if ((sel_s2==2'b00 && (rs1_val_q==rs2_val_q)) ||
                    (sel_s2==2'b01 && ($signed(rs1_val_q) >= $signed(rs2_val_q))) ||
                    (sel_s2==2'b10 && ($signed(rs1_val_q) <  $signed(rs2_val_q)))) begin
                  ex_pc_jump_q <= 1'b1;
                  ex_pc_next_q <= pc_reg + immC2_w;
                end
              end
              ex_wb_en_q <= 1'b0;
              ex_result_q<=32'd0;
            end
          end

          if (op_srt || op_ldmax || mac_active) begin
            phase <= (ex_left==8'd1) ? 2'd3 : 2'd2;
          end else begin
            phase <= 2'd3;
          end
        end

        2'd3: begin
          cur_stage_o <= 2'd3;
          if (ex_wb_en_q && (rd_q!=5'd0)) begin
            rfile[rd_q] <= ex_result_q;
          end
          if (ex_pc_jump_q) begin
            pc_reg <= ex_pc_next_q;
          end else begin
            pc_reg <= pc_reg + 32'd4;
          end

          ex_wb_en_q   <= 1'b0;
          ex_result_q  <= 32'd0;
          ex_pc_jump_q <= 1'b0;
          ex_pc_next_q <= 32'd0;
          phase        <= 2'd0;
        end

        default: begin
          phase <= 2'd0;
        end
      endcase
    end
  end
endmodule