`timescale 1ns / 1ps

module tb_islemci ();

   localparam BELLEK_ADRES = 32'h8000_0000;
   localparam ADRES_BIT = 32;
   localparam VERI_BIT = 32;

   reg clk_r;
   reg rst_r;

   wire [ADRES_BIT-1:0] islemci_bellek_adres;
   wire [VERI_BIT-1:0] islemci_bellek_oku_veri;
   wire [VERI_BIT-1:0] islemci_bellek_yaz_veri;
   wire islemci_bellek_yaz;

   anabellek anabellek (
       .clk(clk_r),
       .adres(islemci_bellek_adres),
       .oku_veri(islemci_bellek_oku_veri),
       .yaz_veri(islemci_bellek_yaz_veri),
       .yaz_gecerli(islemci_bellek_yaz)
   );

   islemci islemci (
       .clk(clk_r),
       .rst(rst_r),
       .bellek_adres(islemci_bellek_adres),
       .bellek_oku_veri(islemci_bellek_oku_veri),
       .bellek_yaz_veri(islemci_bellek_yaz_veri),
       .bellek_yaz(islemci_bellek_yaz)
   );

   always begin
      clk_r = 1'b0;
      #5;
      clk_r = 1'b1;
      #5;
   end

   localparam MAX_CYCLES = 100;
   integer stall_ctr;
   initial begin
      stall_ctr = 0;
      rst_r = 1'b1;
      // Race condition engellemek icin sistem 1 cevrim calistirilir
      @(posedge clk_r);  // reset sinyali aktif oldugu icin degisiklik olusmaz
      // https://luplab.gitlab.io/rvcodecjs/ <- assembly binary donusumu icin kullanabiliriniz
      // BUYRUKLAR 
      bellek_yaz('h8000_0000, 32'h00500093);  // addi x1, x0, 5
      bellek_yaz('h8000_0004, 32'h00a00113);  // addi x2, x0, 10
      bellek_yaz('h8000_0008, 32'h002081b3);  // add  x3, x1, x2
      bellek_yaz('h8000_000c, 32'h80000237);  // lui  x4, 0x80000
      bellek_yaz('h8000_0010, 32'h40022283);  // lw   x5, 0x400(x4)
      bellek_yaz('h8000_0014, 32'h003282b3);  // add  x5, x5, x3
      bellek_yaz('h8000_0018, 32'h40522223);  // sw   x5, 0x404(x4)

      // PROGRAM VERISI
      bellek_yaz('h8000_0400, 32'hdeadbee0);
      bellek_yaz('h8000_0404, 32'h55555555);

      // BUYRUKLAR - ALTERNATIF YONTEM (zaten 8000_0000'in 0. index oldugunu biliyoruz)
      // anabellek.bellek[0] = 32'h00500093; 
      // anabellek.bellek[1] = 32'h00a00113; 

      repeat (10) @(posedge clk_r);
      #2;  // 10 cevrim reset
      rst_r = 1'b0;

      buyruk_kontrol(3);  // 3 buyruk yurut
      if (yazmac_oku(1) !== 5) begin
         $display("[ERR] x1 DEGER HATASI expected: 5 actual: %0d", yazmac_oku(1));
      end
      if (yazmac_oku(2) !== 10) begin
         $display("[ERR] x2 DEGER HATASI expected: 10 actual: %0d", yazmac_oku(2));
      end
      if (yazmac_oku(3) !== 15) begin
         $display("[ERR] x3 DEGER HATASI expected: 15 actual: %0d", yazmac_oku(3));
      end
      if (islemci.ps_r !== 'h8000_000c) begin
         $display("[ERR] program sayaci 4. buyrugu gostermeli.");
      end

      buyruk_kontrol(4);  // 4 buyruk yurut
      if (bellek_oku('h8000_0400) !== 32'hdeadbee0) begin
         $display("[ERR] adres 0x80000400 DEGER HATASI expected: 0xdeadbee0 actual: 0x%0x.",
                  bellek_oku('h8000_0400));
      end
      if (bellek_oku('h8000_0404) !== 32'hdeadbeef) begin
         $display("[ERR] adres 0x80000404 DEGER HATASI expected: 0xdeadbeef actual: 0x%0x.",
                  bellek_oku('h8000_0404));
      end
      $finish;
   end
   // Islemcide buyruk_sayisi kadar buyruk yurutulmesini izler ve asama sirasini kontrol eder.
   task buyruk_kontrol(input [31:0] buyruk_sayisi);
      integer counter;
      begin
         for (counter = 0; counter < buyruk_sayisi; counter = counter + 1) begin
            while (!islemci.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci.GETIR);
            @(posedge clk_r) #2;
            while (!islemci.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci.COZYAZMACOKU);
            @(posedge clk_r) #2;
            while (!islemci.ilerle_cmb) @(posedge clk_r) #2;
            asama_kontrol(islemci.YURUTGERIYAZ);
            @(posedge clk_r) #2;
         end
      end
   endtask

   task asama_kontrol(input [1:0] beklenen);
      begin
         if (islemci.simdiki_asama_r !== beklenen) begin
            $display("[ERR] YANLIS ASAMA expected: %0x actual: %0x", beklenen,
                     islemci.simdiki_asama_r);
         end
      end
   endtask

   task bellek_yaz(input [ADRES_BIT-1:0] adres, input [VERI_BIT-1:0] veri);
      begin
         anabellek.bellek[adres_satir_idx(adres)] = veri;
      end
   endtask

   function [VERI_BIT-1:0] bellek_oku(input [ADRES_BIT-1:0] adres);
      begin
         bellek_oku = anabellek.bellek[adres_satir_idx(adres)];
      end
   endfunction

   function [VERI_BIT-1:0] yazmac_oku(input integer yazmac_idx);
      begin
         yazmac_oku = islemci.yazmac_obegi[yazmac_idx];
      end
   endfunction

   // Verilen adresi bellek satir indisine donusturur.
   function integer adres_satir_idx(input [ADRES_BIT-1:0] adres);
      begin
         adres_satir_idx = (adres - BELLEK_ADRES) >> $clog2(VERI_BIT / 8);
      end
   endfunction

endmodule
