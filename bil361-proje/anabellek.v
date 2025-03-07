`timescale 1ns/1ps

module anabellek #(
    parameter BASLANGIC_ADRES = 32'h8000_0000,
    parameter ADRES_BIT       = 32,
    parameter VERI_BIT        = 32,
    parameter BELLEK_SATIR    = 2048,
    parameter DEBUG           = "TRUE"
)(
    input                       clk,
    input   [ADRES_BIT-1:0]     adres,
    output  [VERI_BIT-1:0]      oku_veri,
    input   [VERI_BIT-1:0]      yaz_veri,
    input                       yaz_gecerli
);

localparam TANIMSIZ = DEBUG == "TRUE" ? {VERI_BIT{1'bZ}} : {VERI_BIT{1'b0}};

reg [VERI_BIT-1:0] bellek [0:BELLEK_SATIR-1];
reg [VERI_BIT-1:0] oku_veri_cmb;

wire bellek_istek_gecerli = (adres >= BASLANGIC_ADRES) && (adres < (BASLANGIC_ADRES + BELLEK_SATIR));
wire [ADRES_BIT-1:0] bellek_satir_idx = (adres - BASLANGIC_ADRES) >> $clog2(VERI_BIT / 8);

integer i;
initial begin
    for (i = 0; i < BELLEK_SATIR; i = i + 1) begin
        bellek[i] <= 0;
    end
end

always @* begin
    oku_veri_cmb = TANIMSIZ;
    if (bellek_istek_gecerli) begin
        oku_veri_cmb = bellek[bellek_satir_idx];
    end
end

always @(posedge clk) begin
    if (bellek_istek_gecerli && yaz_gecerli) begin
        bellek[bellek_satir_idx] <= yaz_veri;
    end
end

assign oku_veri = oku_veri_cmb;

endmodule