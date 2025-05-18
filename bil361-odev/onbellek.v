`timescale 1ns / 1ps

module onbellek (
    input               clk_i,
    input               rst_i,

    output  reg [31:0]  anabellek_istek_adres_o,
    output  reg [127:0] anabellek_istek_veri_o,
    output  reg         anabellek_istek_gecerli_o,
    output  reg         anabellek_istek_yaz_gecerli_o,
    input               anabellek_istek_hazir_i,

    input   [127:0]     anabellek_cevap_veri_i,
    input               anabellek_cevap_gecerli_i,
    output  reg         anabellek_cevap_hazir_o,

    input   [31:0]      islemci_istek_adres_i,
    input   [31:0]      islemci_istek_veri_i,
    input               islemci_istek_gecerli_i,
    input               islemci_istek_yaz_i,
    output              islemci_istek_hazir_o,

    output  reg [31:0]  islemci_cevap_veri_o,
    output  reg         islemci_cevap_gecerli_o,
    input               islemci_cevap_hazir_i,

    output              onbellek_istek_gecerli_o,
    output              onbellek_istek_yaz_o,
    output  [127:0]     onbellek_istek_veri_o,
    output  [6:0]       onbellek_istek_adres_o,
    input   [127:0]     onbellek_cevap_veri_i
);

localparam GIRDI_SAYISI = 128;
localparam BLOK_BOYUTU = 128;
localparam ETIKET_GENISLIGI = 18;

reg [BLOK_BOYUTU-1:0] veri_obegi [0:GIRDI_SAYISI-1];
reg [ETIKET_GENISLIGI-1:0] etiket [0:GIRDI_SAYISI-1];
reg gecerlilik [0:GIRDI_SAYISI-1];

reg [2:0] durum;
localparam BEKLE = 0, KONTROL = 1, BELLEK_ISTEK = 2, YANIT_BEKLE = 3, VERI_YOLLA = 4;

reg [31:0] adres_reg, veri_reg;
reg        yazma_flag;
reg [6:0]  satir_indeks;
reg [3:0]  blok_offset;
reg [ETIKET_GENISLIGI-1:0] guncel_etiket;
reg [127:0] obek_okunan, obek_yeni;
reg [31:0] veri_oku;
reg yazma_aktif;

assign islemci_istek_hazir_o = (durum == BEKLE);
assign onbellek_istek_gecerli_o = yazma_aktif;
assign onbellek_istek_yaz_o     = yazma_aktif;
assign onbellek_istek_veri_o    = obek_yeni;
assign onbellek_istek_adres_o   = satir_indeks;

function [31:0] kelime_cek;
    input [127:0] obek;
    input [3:0] offset;
    begin
        kelime_cek = 0;
        kelime_cek[7:0]   = obek[(offset + 0)*8 +: 8];
        kelime_cek[15:8]  = obek[(offset + 1)*8 +: 8];
        kelime_cek[23:16] = obek[(offset + 2)*8 +: 8];
        kelime_cek[31:24] = obek[(offset + 3)*8 +: 8];
    end
endfunction

function [127:0] kelime_yaz;
    input [127:0] obek;
    input [3:0] offset;
    input [31:0] kelime;
    begin
        kelime_yaz = obek;
        kelime_yaz[(offset + 0)*8 +: 8] = kelime[7:0];
        kelime_yaz[(offset + 1)*8 +: 8] = kelime[15:8];
        kelime_yaz[(offset + 2)*8 +: 8] = kelime[23:16];
        kelime_yaz[(offset + 3)*8 +: 8] = kelime[31:24];
    end
endfunction

integer j;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        durum <= BEKLE;
        islemci_cevap_veri_o <= 0;
        islemci_cevap_gecerli_o <= 0;
        anabellek_istek_gecerli_o <= 0;
        anabellek_istek_yaz_gecerli_o <= 0;
        anabellek_cevap_hazir_o <= 0;
        yazma_aktif <= 0;
        for (j = 0; j < GIRDI_SAYISI; j = j + 1) begin
            gecerlilik[j] <= 0;
            veri_obegi[j] <= 0;
            etiket[j] <= 0;
        end
    end else begin
        case (durum)
            BEKLE: begin
                if (islemci_istek_gecerli_i) begin
                    adres_reg <= islemci_istek_adres_i;
                    veri_reg <= islemci_istek_veri_i;
                    yazma_flag <= islemci_istek_yaz_i;
                    satir_indeks <= islemci_istek_adres_i[10:4];
                    blok_offset <= islemci_istek_adres_i[3:0] & 4'b1100;
                    guncel_etiket <= islemci_istek_adres_i[31:11];
                    durum <= KONTROL;
                end
            end
            KONTROL: begin
                if (gecerlilik[satir_indeks] && etiket[satir_indeks] == guncel_etiket) begin
                    obek_okunan <= veri_obegi[satir_indeks];
                    durum <= VERI_YOLLA;
                end else begin
                    anabellek_istek_adres_o <= {guncel_etiket, satir_indeks, 4'b0000};
                    anabellek_istek_veri_o <= 0;
                    anabellek_istek_gecerli_o <= 1;
                    anabellek_istek_yaz_gecerli_o <= 0;
                    durum <= YANIT_BEKLE;
                end
            end
            YANIT_BEKLE: begin
                anabellek_istek_gecerli_o <= 0;
                if (anabellek_cevap_gecerli_i) begin
                    obek_okunan <= anabellek_cevap_veri_i;
                    veri_obegi[satir_indeks] <= anabellek_cevap_veri_i;
                    etiket[satir_indeks] <= guncel_etiket;
                    gecerlilik[satir_indeks] <= 1;
                    durum <= VERI_YOLLA;
                end
            end
            VERI_YOLLA: begin
                if (!islemci_cevap_gecerli_o) begin
                    if (yazma_flag) begin
                        obek_yeni <= kelime_yaz(obek_okunan, blok_offset, veri_reg);
                        veri_obegi[satir_indeks] <= obek_yeni;
                        yazma_aktif <= 1;
                        veri_oku <= veri_reg;
                    end else begin
                        veri_oku <= kelime_cek(obek_okunan, blok_offset);
                        obek_yeni <= obek_okunan;
                        yazma_aktif <= 0;
                    end
                    islemci_cevap_veri_o <= veri_oku;
                    islemci_cevap_gecerli_o <= 1;
                end else if (islemci_cevap_gecerli_o && islemci_cevap_hazir_i) begin
                    islemci_cevap_gecerli_o <= 0;
                    yazma_aktif <= 0;
                    durum <= BEKLE;
                end
            end
            default: durum <= BEKLE;
        endcase
    end
end

endmodule