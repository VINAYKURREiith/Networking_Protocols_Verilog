`timescale 1ns/1ps

module tb_manchester_encoder;

    reg clk;
    reg rst_n;
    reg bit_valid;
    reg data_bit;

    wire encoded;
    wire busy;
    wire done;

    integer errors;
    integer passed;
    integer timeout_count;

    reg expected_first_half;
    reg expected_second_half;

    always #5 clk = ~clk;

    manchester_encoder dut (
        clk,
        rst_n,
        bit_valid,
        data_bit,
        encoded,
        busy,
        done
    );

    task send_and_check;
        input test_bit;

        begin
            $display("--------------------------------------");
            $display("[INFO] Manchester input bit = %b", test_bit);

            // Wait for idle.
            @(negedge clk);

            timeout_count = 0;

            while (busy !== 1'b0 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (busy !== 1'b0) begin
                $display("[FAIL] Encoder did not become idle");
                errors = errors + 1;
            end else begin
                data_bit = test_bit;
                bit_valid = 1'b1;

                @(negedge clk);
                bit_valid = 1'b0;

                // Wait for encoding to begin.
                timeout_count = 0;

                while (busy !== 1'b1 && timeout_count < 100) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (busy !== 1'b1) begin
                    $display("[FAIL] Encoder did not assert BUSY");
                    errors = errors + 1;
                end else begin
                    expected_first_half  = (test_bit == 1'b0);
                    expected_second_half = (test_bit == 1'b1);

                    // Allow the encoder's output register to update.
                    #1;

                    if (encoded !== expected_first_half) begin
                        $display(
                            "[FAIL] First half: got %b expected %b",
                            encoded, expected_first_half
                        );
                        errors = errors + 1;
                    end else begin
                        $display(
                            "[PASS] First half = %b",
                            encoded
                        );
                        passed = passed + 1;
                    end

                    // Wait for the second half of the Manchester bit.
                    @(negedge clk);
                    #1;

                    if (encoded !== expected_second_half) begin
                        $display(
                            "[FAIL] Second half: got %b expected %b",
                            encoded, expected_second_half
                        );
                        errors = errors + 1;
                    end else begin
                        $display(
                            "[PASS] Second half = %b",
                            encoded
                        );
                        passed = passed + 1;
                    end
                end

                // Wait for transaction completion.
                timeout_count = 0;

                while (done !== 1'b1 && timeout_count < 100) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (done !== 1'b1) begin
                    $display("[FAIL] DONE was not asserted");
                    errors = errors + 1;
                end else begin
                    $display("[PASS] DONE asserted");
                    passed = passed + 1;
                end

                // Wait for encoder to return to idle.
                timeout_count = 0;

                while (busy !== 1'b0 && timeout_count < 100) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (busy !== 1'b0) begin
                    $display("[FAIL] BUSY did not clear");
                    errors = errors + 1;
                end else begin
                    $display("[PASS] BUSY cleared");
                    passed = passed + 1;
                end
            end

            repeat (2) @(negedge clk);
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        bit_valid = 0;
        data_bit = 0;

        errors = 0;
        passed = 0;
        timeout_count = 0;

        expected_first_half = 0;
        expected_second_half = 0;

        $dumpfile("manchester.vcd");
        $dumpvars(0, tb_manchester_encoder);

        $display("======================================");
        $display(" MANCHESTER ENCODER VERIFICATION");
        $display(" Convention: 0 = HIGH-to-LOW");
        $display("             1 = LOW-to-HIGH");
        $display("======================================");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        send_and_check(1'b0);
        send_and_check(1'b1);
        send_and_check(1'b0);
        send_and_check(1'b1);

        $display("--------------------------------------");
        $display("Checks passed: %0d", passed);
        $display("Checks failed: %0d", errors);

        if (errors == 0)
            $display("MANCHESTER TEST PASSED");
        else
            $display("MANCHESTER TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Global simulation timeout");
        $finish;
    end

endmodule
