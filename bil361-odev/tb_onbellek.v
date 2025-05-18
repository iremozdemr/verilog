`timescale 1ns / 1ps

module tb_onbellek();

    reg                 clk_i;
    reg                 rst_i;

    wire    [31:0]      anabellek_istek_adres_o;
    wire    [127:0]     anabellek_istek_veri_o;
    wire                anabellek_istek_gecerli_o;
    wire                anabellek_istek_yaz_gecerli_o;
    wire                anabellek_istek_hazir_i;
    wire    [127:0]     anabellek_cevap_veri_i;
    wire                anabellek_cevap_gecerli_i;
    wire                anabellek_cevap_hazir_o;

    anabellek ab (
        .clk_i                  ( clk_i ),
        .rst_i                  ( rst_i ),
        .istek_adres_i          ( anabellek_istek_adres_o ),
        .istek_veri_i           ( anabellek_istek_veri_o ),
        .istek_gecerli_i        ( anabellek_istek_gecerli_o ),
        .istek_yaz_gecerli_i    ( anabellek_istek_yaz_gecerli_o ),
        .istek_hazir_o          ( anabellek_istek_hazir_i ),
        .yanit_veri_o           ( anabellek_cevap_veri_i ),
        .yanit_gecerli_o        ( anabellek_cevap_gecerli_i ),
        .yanit_hazir_i          ( anabellek_cevap_hazir_o )
    );

    reg     [31:0]      istek_adres_i;
    reg     [31:0]      istek_veri_i;
    reg                 istek_gecerli_i;
    reg                 istek_yaz_gecerli_i;
    wire                istek_hazir_o;
    wire    [31:0]      cevap_veri_o;
    wire                cevap_gecerli_o;
    reg                 cevap_hazir_i;

    wire            onbellek_istek_gecerli_o;
    wire            onbellek_istek_yaz_o;
    wire    [127:0] onbellek_istek_veri_o;
    wire    [6:0]   onbellek_istek_adres_o;
    wire    [127:0] onbellek_cevap_veri_i;

    onbellek ob (
        .clk_i                          ( clk_i ),
        .rst_i                          ( rst_i ),
        .anabellek_istek_adres_o        ( anabellek_istek_adres_o ),
        .anabellek_istek_veri_o         ( anabellek_istek_veri_o ),
        .anabellek_istek_gecerli_o      ( anabellek_istek_gecerli_o ),
        .anabellek_istek_yaz_gecerli_o  ( anabellek_istek_yaz_gecerli_o ),
        .anabellek_istek_hazir_i        ( anabellek_istek_hazir_i ),
        .anabellek_cevap_veri_i         ( anabellek_cevap_veri_i ),
        .anabellek_cevap_gecerli_i      ( anabellek_cevap_gecerli_i ),
        .anabellek_cevap_hazir_o        ( anabellek_cevap_hazir_o ),
        .islemci_istek_adres_i          ( istek_adres_i ),
        .islemci_istek_veri_i           ( istek_veri_i ),
        .islemci_istek_gecerli_i        ( istek_gecerli_i ),
        .islemci_istek_yaz_i            ( istek_yaz_gecerli_i ),
        .islemci_istek_hazir_o          ( istek_hazir_o ),
        .islemci_cevap_veri_o           ( cevap_veri_o ),
        .islemci_cevap_gecerli_o        ( cevap_gecerli_o ),
        .islemci_cevap_hazir_i          ( cevap_hazir_i ),
        .onbellek_istek_gecerli_o       ( onbellek_istek_gecerli_o ),
        .onbellek_istek_yaz_o           ( onbellek_istek_yaz_o ),
        .onbellek_istek_veri_o          ( onbellek_istek_veri_o ),
        .onbellek_istek_adres_o         ( onbellek_istek_adres_o ),
        .onbellek_cevap_veri_i          ( onbellek_cevap_veri_i )
    );

    bram_model #(
        .DATA_WIDTH(128),
        .BRAM_DEPTH(128)
    ) bram (
        .clk_i      ( clk_i ),
        .data_i     ( onbellek_istek_veri_o ),
        .addr_i     ( onbellek_istek_adres_o ),
        .wr_en_i    ( onbellek_istek_yaz_o ),
        .cmd_en_i   ( onbellek_istek_gecerli_o ),
        .data_o     ( onbellek_cevap_veri_i )
    );

    always begin
        clk_i = 0;
        #5;
        clk_i = 1;
        #5;
    end

    localparam TEST_LEN = 16384;

    integer i;
    integer flag;
    initial begin
        istek_adres_i = 0;
        istek_veri_i = 0;
        istek_gecerli_i = 0;
        istek_yaz_gecerli_i = 0;
        cevap_hazir_i = 1;
        flag = 1;

        rst_i = 1;
        repeat(10) @(posedge clk_i) #2;
        rst_i = 0;

        for (i = 0; i < TEST_LEN; i = i + 1) begin
            istek_adres_i = i;
            istek_veri_i = (32'hABCD_0000 + i) & 32'hFFFF_FFFC;
            istek_gecerli_i = 1;
            istek_yaz_gecerli_i = 1;
            wait(istek_hazir_o && clk_i);
            @(posedge clk_i) #2;
        end

        for (i = 0; i < TEST_LEN; i = i + 1) begin
            istek_adres_i = i;
            istek_gecerli_i = 1;
            istek_yaz_gecerli_i = 0;
            wait(istek_hazir_o && clk_i);
            @(posedge clk_i) #2;
            wait(cevap_gecerli_o && clk_i);
            @(posedge clk_i) #2;
            if (cevap_veri_o != ((32'hABCD_0000 + i) & 32'hFFFF_FFFC)) begin
                $display("[SIM] Okuma hatası, i = %0d.", i);
                flag = 0;
            end
        end

        if (flag) begin
            $display("[SIM] Test başarılı.");
        end
        $finish;
    end

endmodule