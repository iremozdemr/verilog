`timescale 1ns/1ps

`define BELLEK_ADRES    32'h8000_0000
`define VERI_BIT        32
`define ADRES_BIT       32
`define YAZMAC_SAYISI   32

module islemci_yusf (
    input                       clk,
    input                       rst,
    output  [`ADRES_BIT-1:0]    bellek_adres,
    input   [`VERI_BIT-1:0]     bellek_oku_veri,
    output reg [`VERI_BIT-1:0]  bellek_yaz_veri,
    output reg                  bellek_yaz
);

localparam GETIR         = 3'd0;
localparam COZYAZMACOKU  = 3'd1;
localparam YURUTGERIYAZ  = 3'd2;  
localparam LIS = 7'b1110010;
localparam LLM = 7'b1110011;
localparam KS  = 7'b1110001;
reg [2:0] simdiki_asama_r;
reg [2:0] simdiki_asama_ns;
reg ilerle_cmb;
reg [`VERI_BIT-1:0] yazmac_obegi [0:`YAZMAC_SAYISI-1];
reg [`ADRES_BIT-1:0] ps_r;
reg [`VERI_BIT-1:0] temp_deger; 
reg [`VERI_BIT-1:0] buyruk;
reg [`VERI_BIT-1:0] gecici_deger;
reg [`ADRES_BIT-1:0] hedef_adres;
integer i;
integer j;
integer num;

reg [1:0] yurutme_cevrimi;  
//yurutme asamasinda kacinci cevrimde olundugunu gösterir

always @(*) begin
    ilerle_cmb = 0;
    simdiki_asama_ns = simdiki_asama_r;
    
    if (simdiki_asama_r == GETIR) begin
        buyruk = bellek_oku_veri;
        ilerle_cmb = 1;
        simdiki_asama_ns = COZYAZMACOKU;
    end
    
    else if (simdiki_asama_r == COZYAZMACOKU) begin
        simdiki_asama_ns = YURUTGERIYAZ;
        ilerle_cmb = 1;
    end

    else if (simdiki_asama_r == YURUTGERIYAZ) begin
        if (buyruk[6:0] == LIS) begin
            if (yurutme_cevrimi == 2'd0) begin
                hedef_adres = yazmac_obegi[buyruk[19:15]] + {{20{buyruk[31]}}, buyruk[31:20]};
                ilerle_cmb = 0;  
            end else if (yurutme_cevrimi == 2'd1) begin
                temp_deger = bellek_oku_veri + {{27{buyruk[24]}}, buyruk[24:20]};
                ilerle_cmb = 0;  
            end else begin
                bellek_yaz_veri = temp_deger;
                bellek_yaz = 1;
                ilerle_cmb = 1;
                simdiki_asama_ns = GETIR;
            end
        end

        else if (buyruk[6:0] == LLM) begin
            if (yurutme_cevrimi == 2'd0) begin
                temp_deger = bellek_oku_veri;
                ilerle_cmb = 0;
            end else if (yurutme_cevrimi == 2'd1) begin
                gecici_deger = bellek_oku_veri;
                ilerle_cmb = 0;
            end else begin
                yazmac_obegi[buyruk[11:7]] = temp_deger * gecici_deger;
                ilerle_cmb = 1;
                simdiki_asama_ns = GETIR;
            end
        end

        else if (buyruk[6:0] == KS) begin
            if (yurutme_cevrimi == 2'd0) begin
                i = 0;
                ilerle_cmb = 0;
            end else if (yurutme_cevrimi == 2'd1) begin
                if (i < buyruk[24:20] - 1) begin
                    num = i;
                    j = i + 1;
                    ilerle_cmb = 0;
                end else begin
                    simdiki_asama_ns = GETIR;
                    ilerle_cmb = 1;
                end
            end else if (yurutme_cevrimi == 2'd2) begin
                if (j < buyruk[24:20]) begin
                    if (yazmac_obegi[buyruk[19:15] + j] < yazmac_obegi[buyruk[19:15] + num]) begin
                        num = j;
                    end
                    j = j + 1;
                    ilerle_cmb = 0;
                end else begin
                    if (num != i) begin
                        temp_deger = yazmac_obegi[buyruk[19:15] + i];
                        yazmac_obegi[buyruk[19:15] + i] = yazmac_obegi[buyruk[19:15] + num];
                        yazmac_obegi[buyruk[19:15] + num] = temp_deger;
                    end
                    i = i + 1;
                    ilerle_cmb = 0;
                end
            end else begin
                simdiki_asama_ns = GETIR;
                ilerle_cmb = 1;
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        ps_r <= `BELLEK_ADRES;
        simdiki_asama_r <= GETIR;
        yurutme_cevrimi <= 0;
    end else if (ilerle_cmb) begin
        simdiki_asama_r <= simdiki_asama_ns;
        yurutme_cevrimi <= 0; 
    end else if (simdiki_asama_r == YURUTGERIYAZ) begin
        yurutme_cevrimi <= yurutme_cevrimi + 1; 
    end
end

assign bellek_adres = ps_r;

endmodule