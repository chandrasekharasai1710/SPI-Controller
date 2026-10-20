`timescale 1ns/1ps

module tb_spi_master;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [7:0]  tx_data;
    wire [7:0]  rx_data;
    wire        done;
    wire        sclk;
    wire        mosi;
    reg         miso;
    wire        cs_n;

    reg  [7:0]  slave_shift;
    reg  [7:0]  slave_tx_byte;

    integer errors = 0;
    integer tests  = 0;

    spi_master #(.CLK_DIV(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .tx_data(tx_data),
        .rx_data(rx_data), .done(done),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    always #5 clk = ~clk;

    // MISO always reflects the slave's current top bit, so it is valid
    // *before* the DUT samples it on each SCLK falling edge.
    always @(*) miso = slave_shift[7];

    // Slave shifts in MOSI only after each falling edge.
    always @(negedge sclk or posedge cs_n) begin
        if (!cs_n)
            slave_shift <= {slave_shift[6:0], mosi};
    end

    task run_transfer(input [7:0] master_byte, input [7:0] slave_byte);
        begin
            slave_shift   = slave_byte;
            slave_tx_byte = slave_byte;
            tx_data = master_byte;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            wait (done == 1'b1);
            tests = tests + 1;
            if (rx_data !== slave_tx_byte) begin
                $display("FAIL: tx=%h expected_rx=%h got_rx=%h", master_byte, slave_tx_byte, rx_data);
                errors = errors + 1;
            end else begin
                $display("PASS: tx=%h rx=%h", master_byte, rx_data);
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk     = 0;
        rst_n   = 0;
        start   = 0;
        tx_data = 8'h00;
        miso    = 0;
        slave_shift = 8'h00;

        repeat (4) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        run_transfer(8'hA5, 8'h3C);
        run_transfer(8'h00, 8'hFF);
        run_transfer(8'hFF, 8'h00);
        run_transfer(8'h55, 8'hAA);
        run_transfer(8'h81, 8'h7E);

        $display("--------------------------------------");
        $display("Tests run: %0d  Errors: %0d", tests, errors);
        if (errors == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", errors);

        $finish;
    end

    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule
