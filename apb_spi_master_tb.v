

module tb_spi;

  // -----------------------------
  // APB Signals
  // -----------------------------
  reg         HCLK;
  reg         HRESETn;
  reg         PSEL;
  reg         PENABLE;
  reg         PWRITE;
  reg  [11:0] PADDR;
  reg  [31:0] PWDATA;
  wire [31:0] PRDATA;
  wire        PREADY;
  wire        PSLVERR;

  // -----------------------------
  // SPI Signals
  // -----------------------------
  wire spi_clk;
  wire spi_csn0;
  wire [1:0] spi_mode;
  wire spi_sdo0;
  wire spi_sdi0;

  // -----------------------------
  // DUT
  // -----------------------------
  apb_spi_master DUT (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .PWRITE(PWRITE),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR),

    .events_o(),

    .spi_clk(spi_clk),
    .spi_csn0(spi_csn0),
    .spi_csn1(),
    .spi_csn2(),
    .spi_csn3(),
    .spi_mode(spi_mode),
    .spi_sdo0(spi_sdo0),
    .spi_sdo1(),
    .spi_sdo2(),
    .spi_sdo3(),
    .spi_sdi0(spi_sdi0),
    .spi_sdi1(1'b0),
    .spi_sdi2(1'b0),
    .spi_sdi3(1'b0)
  );

  // -----------------------------
  // LOOPBACK
  // -----------------------------
 

assign #5 spi_sdi0 = spi_sdo0; 

  // -----------------------------
  // CLOCK
  // -----------------------------
  initial begin
    HCLK = 0;
    forever #5 HCLK = ~HCLK;   // 100 MHz
  end

  // -----------------------------
  // APB WRITE
  // -----------------------------
  task apb_write(input [11:0] addr, input [31:0] data);
  begin
    @(posedge HCLK);
    PSEL    <= 1;
    PENABLE <= 0;
    PWRITE  <= 1;
    PADDR   <= addr;
    PWDATA  <= data;

    @(posedge HCLK);
    PENABLE <= 1;
    
     @(posedge HCLK);

    @(posedge HCLK);
    PSEL    <= 0;
    PENABLE <= 0;
    PWRITE  <= 0;
  end
  endtask

  // -----------------------------
  // APB READ
  // -----------------------------
  task apb_read(input [11:0] addr, output [31:0] data);
  begin
    @(posedge HCLK);
    PSEL    <= 1;
    PENABLE <= 0;
    PWRITE  <= 0;
    PADDR   <= addr;

    @(posedge HCLK);
    PENABLE <= 1;

   
    @(posedge HCLK);
    #5;
    data  = PRDATA;
    PSEL    <= 0;
    PENABLE <= 0;
  end
  endtask

  // -----------------------------
  // TEST
  // -----------------------------
  reg [31:0] rx_data;

  // -----------------------------
  // TEST
  // -----------------------------
  reg [31:0] rx_data;

  initial begin
    // Init signals
    PSEL=0; PENABLE=0; PWRITE=0;
    PADDR=0; PWDATA=0;

    // 1. HARD RESET
    HRESETn = 0;
    #100;
    HRESETn = 1;
    #100;

    // 2. CONFIGURATION
    // Clock Div
    apb_write(12'h004, 32'd10);
    
    // Set Data Length to 32 bits (Register 0x10)
    // PWDATA[23:16] = 8'h20 (32 bits)
    apb_write(12'h010, 32'h0020_0000); 

    
    // 3. FILL TX FIFO
    // Data jo hum loopback ke zariye wapas chahte hain
    apb_write(12'h018, 32'hA5A5_B1B1); 
    #50;

    // 4. TRIGGER (The Critical Step)
    // 0x103 bhejte waqt state machine ko signal milta hai TX+RX ka.
    // Agar state 5 ke baad 6 nahi aa rahi, toh hum manual read trigger karenge.
    $display("--- Triggering Combined TX and RX ---");
    apb_write(12'h000, 32'h0000_0102); 

    // 5. WAIT FOR STATE CHANGE & COMPLETION
    // Wait for state to enter DATA_TX (5) then eventually end
    wait(DUT.u_spictrl.state == 5);
    $display("T=%0t | Entered DATA_TX (State 5)", $time);
  
    wait(DUT.u_spictrl.eot == 1);
    #200; // Small buffer for sync

    // 6. CHECK RX FIFO POINTER
    if (DUT.u_rxfifo.pointer_in == 0) begin
        $display("Warning: RX FIFO empty after 0x103. Forcing separate Read...");
        apb_write(12'h000, 32'h0000_0101); // Trigger ONLY Read (Bit 0)
        wait(DUT.u_spictrl.eot == 1);
    end

    // 7. FINAL READ
    #500;
    $display("--- Reading from RX FIFO ---");
    apb_read(12'h020, rx_data); 

    $display("FINAL RX_DATA: %h", rx_data);
    
    #1000;
    $finish;
  end
 
  initial begin
    $monitor("T=%0t | CLK=%b CS=%b MOSI=%b MISO=%b,PWDATA=%h,PRDATA = %h,pointer_in = %h,pointer_out = %h,valid_i = %b,full = %d,state = %d",
              $time, spi_clk, spi_csn0, spi_sdo0, spi_sdi0,PWDATA,PRDATA,DUT.u_rxfifo.pointer_in,DUT.u_rxfifo.pointer_out,DUT.u_rxfifo.valid_i,DUT.u_rxfifo.full
             , DUT.u_spictrl.state);
              
  end

endmodule
