`timescale 1ns/1ps

module tb_i2s_tx;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg [31:0] sample_stereo;

    wire bclk;
    wire lrclk;
    wire sdata;
    wire ready;

    integer errors;
    integer slot;

    reg expected_data;
    reg expected_lrclk;

    always #5 clk = ~clk;

    i2s_tx #(
        .WORD_BITS(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .sample_stereo(sample_stereo),
        .bclk(bclk),
        .lrclk(lrclk),
        .sdata(sdata),
        .ready(ready)
    );

    initial begin
        clk           = 0;
        rst_n         = 0;
        sample_valid  = 0;
        sample_stereo = 32'hA55A_3CC3;
        errors        = 0;

        $dumpfile("i2s.vcd");
        $dumpvars(0, tb_i2s_tx);

        $display("==================================");
        $display(" I2S FRAME VERIFICATION");
        $display("==================================");

        repeat (3) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        sample_valid = 1;

        @(negedge clk);
        sample_valid = 0;

        wait (ready == 0);

        for (slot = 0; slot < 34; slot = slot + 1) begin
            @(negedge bclk);
            #1;

            expected_data  = 0;
            expected_lrclk = (slot >= 17);

            if (slot >= 1 && slot <= 16)
                expected_data = sample_stereo[32-slot];

            if (slot >= 18 && slot <= 33)
                expected_data = sample_stereo[33-slot];

            if ((sdata !== expected_data) ||
                (lrclk !== expected_lrclk)) begin

                $display(
                    "[FAIL] Slot=%0d SDATA=%b expected=%b LRCLK=%b expected=%b",
                    slot, sdata, expected_data,
                    lrclk, expected_lrclk
                );

                errors = errors + 1;
            end else begin
                $display(
                    "[PASS] Slot=%0d SDATA=%b LRCLK=%b",
                    slot, sdata, lrclk
                );
            end
        end

        wait (ready == 1);

        $display("----------------------------------");
        $display("Total slots checked: 34");
        $display("Errors: %0d", errors);

        if (errors == 0)
            $display("I2S FRAME TEST PASSED");
        else
            $display("I2S FRAME TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Simulation timeout");
        $finish;
    end

endmodule
