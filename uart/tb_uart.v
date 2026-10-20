`timescale 1ns/1ps

module tb_uart;

    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] tx_data;

    wire tx;
    wire busy;
    wire done;

    wire [7:0] rx_data;
    wire valid;
    wire framing_error;

    integer errors;
    integer passed;
    integer timeout_count;
    integer total_bits;

    reg [7:0] expected_data;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // UART transmitter
    uart_tx #(
        .CLKS_PER_BIT(16)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(tx_data),
        .tx(tx),
        .busy(busy),
        .done(done)
    );

    // UART receiver
    uart_rx #(
        .CLKS_PER_BIT(16)
    ) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(tx),
        .data_out(rx_data),
        .valid(valid),
        .framing_error(framing_error)
    );

    // Count transmitted UART frame edges.
    // A UART 8N1 frame has one start bit, eight data bits,
    // and one stop bit.
    always @(negedge tx) begin
        if (rst_n && !busy)
            total_bits = total_bits;
    end

    task send_byte;
        input [7:0] value;
        begin
            // Wait until transmitter is idle.
            @(negedge clk);

            timeout_count = 0;
            while (busy !== 1'b0 && timeout_count < 200) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (busy !== 1'b0) begin
                $display("[FAIL] TX remained busy before sending %02h", value);
                errors = errors + 1;
            end else begin
                expected_data = value;

                // Start transmission.
                tx_data = value;
                start = 1'b1;

                @(negedge clk);
                start = 1'b0;

                // Wait for receiver result.
                timeout_count = 0;

                while (valid !== 1'b1 &&
                       framing_error !== 1'b1 &&
                       timeout_count < 250) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (timeout_count >= 250) begin
                    $display("[FAIL] Timeout waiting for byte %02h", value);
                    errors = errors + 1;
                end else if (framing_error !== 1'b0) begin
                    $display("[FAIL] Framing error for byte %02h", value);
                    errors = errors + 1;
                end else if (rx_data !== expected_data) begin
                    $display(
                        "[FAIL] Expected=%02h Received=%02h",
                        expected_data, rx_data
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "[PASS] TX=%02h RX=%02h FramingError=%b",
                        value, rx_data, framing_error
                    );
                    passed = passed + 1;
                end

                // Wait for transmitter completion.
                timeout_count = 0;

                while (done !== 1'b1 &&
                       busy !== 1'b0 &&
                       timeout_count < 200) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (busy !== 1'b0) begin
                    $display("[FAIL] TX did not return to idle");
                    errors = errors + 1;
                end

                if (tx !== 1'b1) begin
                    $display("[FAIL] TX line is not idle HIGH");
                    errors = errors + 1;
                end

                // Allow receiver valid to clear before next byte.
                repeat (3) @(negedge clk);
            end
        end
    endtask

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        tx_data = 8'h00;
        errors = 0;
        passed = 0;
        timeout_count = 0;
        total_bits = 0;
        expected_data = 8'h00;

        $dumpfile("uart.vcd");
        $dumpvars(0, tb_uart);

        $display("======================================");
        $display(" UART TX/RX EXTENDED VERIFICATION");
        $display(" 8 data bits | No parity | 1 stop bit");
        $display("======================================");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        send_byte(8'h00);
        send_byte(8'hA5);
        send_byte(8'h3C);
        send_byte(8'hFF);
        send_byte(8'h81);

        $display("--------------------------------------");
        $display("Successful bytes: %0d / 5", passed);
        $display("Total errors: %0d", errors);

        if (passed == 5 && errors == 0)
            $display("UART EXTENDED TEST PASSED");
        else
            $display("UART EXTENDED TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Global simulation timeout");
        $finish;
    end

endmodule
