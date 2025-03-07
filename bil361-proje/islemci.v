`timescale 1ns/1ps

`define BELLEK_ADRES    32'h8000_0000
`define VERI_BIT        32
`define ADRES_BIT       32
`define YAZMAC_SAYISI   32

module islemci (
    input                       clk,
    input                       rst,
    output  [`ADRES_BIT-1:0]    bellek_adres,
    input   [`VERI_BIT-1:0]     bellek_oku_veri,
    output  [`VERI_BIT-1:0]     bellek_yaz_veri,
    output                      bellek_yaz,
    output                      ilerle_cmb
);

localparam GETIR = 2'd0;
localparam COZYAZMACOKU = 2'd1;
localparam YURUTGERIYAZ = 2'd2;
reg [1:0] simdiki_asama_r;
reg [1:0] simdiki_asama_ns;
reg ilerle_cmb_r;
reg [`VERI_BIT-1:0] yazmac_obegi [0:`YAZMAC_SAYISI-1];
reg [`ADRES_BIT-1:0] ps_r;

//is kodlarini tanimladim
localparam RTYPE_ISKODU = 7'b0110011;  
//add sub and or xor
localparam ADDI_ISKODU = 7'b0010011;  
//addi
localparam LUI_ISKODU = 7'b0110111;  
//lui
localparam AUPIC_ISKODU = 7'b0010111;  
//auipc
localparam LOAD_ISKODU = 7'b0000011;  
//lw
localparam STORE_ISKODU = 7'b0100011;  
//sw
localparam JAL_ISKODU = 7'b1101111;  
//jal
localparam JALR_ISKODU = 7'b1100111;  
//jalr
localparam BEQ_ISKODU = 7'b1100011;  
//beq

//buyrukların kisimlarini tanimladim
reg [6:0] iskodu;
reg [4:0] rs1;
reg [4:0] rs2;
reg [4:0] rd;
reg [2:0] is3;
reg [6:0] is7;

reg [`VERI_BIT-1:0] op1;
reg [`VERI_BIT-1:0] op2;
reg [`VERI_BIT-1:0] anlik;
reg [`ADRES_BIT-1:0] adres;

reg [`VERI_BIT-1:0] buyruk;
reg [`VERI_BIT-1:0] bellek_yaz_veri_r;
reg bellek_yaz_r;

//bu kisim olmadan hata veriyordu
//yazmaclarin degerlerini sifirlamam gerekiyormus
integer i;
initial begin
    for (i = 0; i < `YAZMAC_SAYISI; i = i + 1) begin
        yazmac_obegi[i] = 0;
    end
end

always @* begin
    ilerle_cmb_r = 0;
    simdiki_asama_ns = simdiki_asama_r;
    bellek_yaz_veri_r = 0;
    bellek_yaz_r = 0;

    case (simdiki_asama_r)
        GETIR: begin
            ilerle_cmb_r = 1;
            simdiki_asama_ns = COZYAZMACOKU;
        end

        COZYAZMACOKU: begin
            ilerle_cmb_r = 1;
            simdiki_asama_ns = YURUTGERIYAZ;

            buyruk = bellek_oku_veri;
            iskodu = buyruk[6:0];
            rd = buyruk[11:7];
            is3 = buyruk[14:12];
            rs1 = buyruk[19:15];
            rs2 = buyruk[24:20];
            is7 = buyruk[31:25];

            op1 = yazmac_obegi[rs1];
            op2 = yazmac_obegi[rs2];

            //anliklar farkli buyruklarda farkli yerlerde oldugu icin:
            if (iskodu == ADDI_ISKODU || iskodu == LOAD_ISKODU || iskodu == JALR_ISKODU) begin
                anlik = {{20{buyruk[31]}}, buyruk[31:20]};
            end
            else if (iskodu == STORE_ISKODU || iskodu == BEQ_ISKODU) begin
                anlik = {{20{buyruk[31]}}, buyruk[31:25], buyruk[11:7]};
            end
            else if (iskodu == LUI_ISKODU || iskodu == AUPIC_ISKODU) begin
                anlik = {buyruk[31:12], 12'b0};
            end
            else if (iskodu == JAL_ISKODU) begin
                anlik = {{12{buyruk[31]}}, buyruk[19:12], buyruk[20], buyruk[30:21], 1'b0};
            end
        end

        YURUTGERIYAZ: begin
            ilerle_cmb_r = 1;
            simdiki_asama_ns = GETIR;

            case (iskodu)
                RTYPE_ISKODU: begin
                    case (is3)
                        3'b000: begin
                            //is7 degerine göre toplama veya cikarma yapilir
                            if (is7 == 7'b0100000) begin
                                yazmac_obegi[rd] = op1 - op2;
                            end else begin
                                yazmac_obegi[rd] = op1 + op2;
                            end
                        end
                        3'b100: yazmac_obegi[rd] = op1 ^ op2;
                        3'b110: yazmac_obegi[rd] = op1 | op2;
                        3'b111: yazmac_obegi[rd] = op1 & op2;
                    endcase
                end

                ADDI_ISKODU: yazmac_obegi[rd] = op1 + anlik;

                LUI_ISKODU: yazmac_obegi[rd] = anlik;

                LOAD_ISKODU: yazmac_obegi[rd] = bellek_oku_veri;

                STORE_ISKODU: begin
                    adres = op1 + anlik;

                    bellek_yaz_veri_r = yazmac_obegi[rs2];
                    bellek_yaz_r = 1'b1;
                end

                JAL_ISKODU: begin
                    yazmac_obegi[rd] = ps_r + 4;
                    ps_r = ps_r + anlik;
                end

                JALR_ISKODU: begin
                    yazmac_obegi[rd] = ps_r + 4;
                    ps_r = (op1 + anlik) & ~1;
                end

                BEQ_ISKODU: begin
                    if (op1 == op2) 
                        ps_r = ps_r + anlik;
                    else
                        ps_r = ps_r + 4;
                end
            endcase
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        ps_r <= `BELLEK_ADRES;
        simdiki_asama_r <= GETIR;
        bellek_yaz_r <= 1'b0;
    end
    else if (ilerle_cmb_r) begin
        simdiki_asama_r <= simdiki_asama_ns;

        //bellege yazma durumunu kontrol etmeye calistim
        if (simdiki_asama_r == YURUTGERIYAZ) begin
            if (iskodu == STORE_ISKODU) begin
                bellek_yaz_r <= 1'b1;  
            end
            
            if (iskodu != JAL_ISKODU && iskodu != JALR_ISKODU && iskodu != BEQ_ISKODU) begin
                ps_r <= ps_r + 4;
                bellek_yaz_r <= 1'b0;
            end
        end else begin
            bellek_yaz_r <= 1'b0; 
        end

    end
end

assign ilerle_cmb = ilerle_cmb_r;
assign bellek_yaz_veri = bellek_yaz_veri_r;
assign bellek_yaz = bellek_yaz_r;
assign bellek_adres = ps_r;

endmodule