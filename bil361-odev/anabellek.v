`timescale 1ns/1ps

module anabellek (
    // Saat ve reset
    input               clk_i,
    input               rst_i,

    // Module gelen istek sinyalleri
    input   [31:0]      istek_adres_i,
    input   [127:0]     istek_veri_i,
    input               istek_gecerli_i,
    input               istek_yaz_gecerli_i,
    output              istek_hazir_o,

    // Modulun yanit sinyalleri
    output  [127:0]     yanit_veri_o,
    output              yanit_gecerli_o,
    input               yanit_hazir_i
);

localparam GECIKTIRME_SURESI = 25;

reg [31:0] sayac_r;
reg [31:0] sayac_ns;

localparam DURUM_BOSTA  = 0;
localparam DURUM_BEKLE  = 1;
localparam DURUM_ISLE   = 2;
localparam DURUM_YANIT  = 3;

reg istek_hazir_r;
reg istek_hazir_ns;

reg [127:0] yanit_veri_r;

reg yanit_gecerli_r;
reg yanit_gecerli_ns;

reg [2:0] durum_r;
reg [2:0] durum_ns;

reg [31:0] arabellek_adres_r;
reg [31:0] arabellek_adres_ns;

reg [127:0] arabellek_veri_r;
reg [127:0] arabellek_veri_ns;

reg arabellek_yaz_r;
reg arabellek_yaz_ns;

localparam DEPTH = 16384;
reg [7:0] bellek_r [0:DEPTH - 1];

reg bellek_oku_cmb;
reg bellek_yaz_cmb;

wire [31:0] obek_adres_w = arabellek_adres_r & 32'hFFFF_FFF0;

integer i;
always @* begin
    istek_hazir_ns = 0;
    yanit_gecerli_ns = 0;
    sayac_ns = sayac_r;
    bellek_oku_cmb = 0;
    bellek_yaz_cmb = 0;
    durum_ns = durum_r;
    arabellek_veri_ns = arabellek_veri_r;

    case(durum_r)
    DURUM_BOSTA: begin
        istek_hazir_ns = 1;
        if (istek_hazir_o && istek_gecerli_i) begin
            istek_hazir_ns = 0;
            durum_ns = DURUM_BEKLE;
            arabellek_adres_ns = istek_adres_i;
            arabellek_veri_ns = istek_veri_i;
            arabellek_yaz_ns = istek_yaz_gecerli_i;
            sayac_ns = GECIKTIRME_SURESI;
        end
    end
    DURUM_BEKLE: begin
        sayac_ns = sayac_r - 1;
        if (sayac_r == 0) begin
            durum_ns = DURUM_ISLE;
        end
    end
    DURUM_ISLE: begin
        if (arabellek_yaz_r) begin
            bellek_yaz_cmb = 1;
            durum_ns = DURUM_BOSTA;
        end
        else begin
            bellek_oku_cmb = 1;
            yanit_gecerli_ns = 1;
            durum_ns = DURUM_YANIT;
        end
    end
    DURUM_YANIT: begin
        yanit_gecerli_ns = 1;
        if (yanit_hazir_i && yanit_gecerli_o) begin
            yanit_gecerli_ns = 0;
            durum_ns = DURUM_BOSTA;
        end
    end
    default: durum_ns = DURUM_BOSTA;
    endcase
end

initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
        bellek_r[i] <= 0;
    end
end

always @(posedge clk_i) begin
    if (rst_i) begin
        istek_hazir_r <= 0;
        yanit_veri_r <= 0;
        yanit_gecerli_r <= 0;
        durum_r <= 0;
        sayac_r <= 0;
    end
    else begin
        if (bellek_yaz_cmb) begin
            for (i = 0; i < 16; i = i + 1) begin
                bellek_r[obek_adres_w + i] <= arabellek_veri_r[i * 8 +: 8];
            end
        end
        if (bellek_oku_cmb) begin
            for (i = 0; i < 16; i = i + 1) begin
                yanit_veri_r[i * 8 +: 8] <= bellek_r[obek_adres_w + i];
            end
        end
        arabellek_adres_r <= arabellek_adres_ns;
        arabellek_veri_r <= arabellek_veri_ns;
        arabellek_yaz_r <= arabellek_yaz_ns;
        istek_hazir_r <= istek_hazir_ns;
        yanit_gecerli_r <= yanit_gecerli_ns;
        durum_r <= durum_ns;
        sayac_r <= sayac_ns;
    end
end

assign istek_hazir_o = istek_hazir_r;
assign yanit_veri_o = yanit_veri_r;
assign yanit_gecerli_o = yanit_gecerli_r;

endmodule
