`timescale 1ns/1ps

module tb_spi;

    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] tx_data;
    reg miso;

    wire sclk;
    wire cs_n;
    wire mosi;
    wire busy;
    wire done;
    wire [7:0] rx_data;

    reg [7:0] expected_tx;
    reg [7:0] expected_rx;
    reg [7:0] received_tx;

    integer errors;
    integer bit_index;
    integer timeout_count;

    reg transaction_started;
    reg previous_sclk;
    reg previous_cs_n;

    always #5 clk = ~clk;

    spi_master #(
        .CLK_DIV(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .miso(miso),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .busy(busy),
        .done(done),
        .rx_data(rx_data)
    );

    /*
     * Simple SPI Mode 0 slave.
     * The slave presents MISO data before each rising SCLK edge.
     */
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso = 1'b0;
        end else if (bit_index < 8) begin
            miso = expected_rx[7-bit_index];
        end
    end

    /*
     * Check transmitted MOSI bits at rising SCLK edges.
     * The master must transmit MSB first.
     */
    always @(posedge sclk) begin
        if (rst_n && !cs_n && bit_index < 8) begin
            if (mosi !== expected_tx[7-bit_index]) begin
                $display(
                    "[FAIL] MOSI bit %0d: got %b expected %b at %0t",
                    bit_index,
                    mosi,
                    expected_tx[7-bit_index],
                    $time
                );
                errors = errors + 1;
            end else begin
                $display(
                    "[PASS] MOSI bit %0d = %b",
                    bit_index,
                    mosi
                );
            end

            bit_index = bit_index + 1;
        end
    end

    initial begin
        clk                = 0;
        rst_n              = 0;
        start              = 0;
        tx_data            = 8'hA5;
        miso               = 0;
        expected_tx        = 8'hA5;
        expected_rx        = 8'h3C;
        received_tx        = 0;
        errors             = 0;
        bit_index          = 0;
        timeout_count      = 0;
        transaction_started = 0;
        previous_sclk      = 0;
        previous_cs_n      = 1;

        $dumpfile("spi.vcd");
        $dumpvars(0, tb_spi);

        $display("======================================");
        $display(" SPI MASTER EXTENDED VERIFICATION");
        $display(" Mode 0 | MSB first | 8-bit transfer");
        $display("======================================");

        repeat (3) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;

        // Wait for completion, with a bounded timeout.
        timeout_count = 0;

        while (done !== 1'b1 && timeout_count < 1000) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if (timeout_count >= 1000) begin
            $display("[FAIL] Transaction timed out");
            errors = errors + 1;
        end else begin
            $display("[PASS] Transaction completed");
        end

        #1;

        // Check received byte.
        if (rx_data !== expected_rx) begin
            $display(
                "[FAIL] RX data: got %02h expected %02h",
                rx_data,
                expected_rx
            );
            errors = errors + 1;
        end else begin
            $display("[PASS] RX data = %02h", rx_data);
        end

        // Check number of transmitted bits.
        if (bit_index != 8) begin
            $display(
                "[FAIL] MOSI bit count: got %0d expected 8",
                bit_index
            );
            errors = errors + 1;
        end else begin
            $display("[PASS] Exactly 8 MOSI bits transmitted");
        end

        // Check completion state.
        if (busy !== 1'b0) begin
            $display("[FAIL] BUSY did not clear");
            errors = errors + 1;
        end else begin
            $display("[PASS] BUSY cleared");
        end

        if (cs_n !== 1'b1) begin
            $display("[FAIL] CS_N did not return HIGH");
            errors = errors + 1;
        end else begin
            $display("[PASS] CS_N returned HIGH");
        end

        if (sclk !== 1'b0) begin
            $display("[FAIL] SCLK did not return LOW");
            errors = errors + 1;
        end else begin
            $display("[PASS] SCLK returned LOW");
        end

        $display("--------------------------------------");
        $display("Total errors: %0d", errors);

        if (errors == 0)
            $display("SPI EXTENDED TEST PASSED");
        else
            $display("SPI EXTENDED TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Global simulation timeout");
        $finish;
    end

endmodule
