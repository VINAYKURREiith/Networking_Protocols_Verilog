`timescale 1ns/1ps

module tb_apb_gpio_slave;

    reg pclk;
    reg preset_n;
    reg psel;
    reg penable;
    reg pwrite;
    reg [7:0] paddr;
    reg [31:0] pwdata;

    wire [31:0] prdata;
    wire [31:0] gpio_out;
    wire pready;
    wire pslverr;

    integer errors;
    integer passed;

    always #5 pclk = ~pclk;

    apb_gpio_slave dut (
        pclk,
        preset_n,
        psel,
        penable,
        pwrite,
        paddr,
        pwdata,
        prdata,
        pready,
        pslverr,
        gpio_out
    );

    // APB write transaction
    task apb_write;
        input [7:0] address;
        input [31:0] data;
        input expected_error;

        begin
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b1;
            paddr   = address;
            pwdata  = data;

            // Access phase
            @(negedge pclk);
            penable = 1'b1;

            // Allow the slave to respond
            @(posedge pclk);
            #1;

            if (pslverr !== expected_error) begin
                $display(
                    "[FAIL] WRITE addr=%02h PSLVERR=%b expected=%b",
                    address, pslverr, expected_error
                );
                errors = errors + 1;
            end else if (!expected_error && gpio_out !== data) begin
                $display(
                    "[FAIL] WRITE addr=%02h GPIO=%08h expected=%08h",
                    address, gpio_out, data
                );
                errors = errors + 1;
            end else begin
                $display(
                    "[PASS] WRITE addr=%02h data=%08h error=%b",
                    address, data, pslverr
                );
                passed = passed + 1;
            end

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
        end
    endtask

    // APB read transaction
    task apb_read;
        input [7:0] address;
        input [31:0] expected_data;
        input expected_error;

        begin
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = address;

            // Access phase
            @(negedge pclk);
            penable = 1'b1;

            @(posedge pclk);
            #1;

            if (pslverr !== expected_error) begin
                $display(
                    "[FAIL] READ addr=%02h PSLVERR=%b expected=%b",
                    address, pslverr, expected_error
                );
                errors = errors + 1;
            end else if (!expected_error && prdata !== expected_data) begin
                $display(
                    "[FAIL] READ addr=%02h data=%08h expected=%08h",
                    address, prdata, expected_data
                );
                errors = errors + 1;
            end else begin
                $display(
                    "[PASS] READ addr=%02h data=%08h error=%b",
                    address, prdata, pslverr
                );
                passed = passed + 1;
            end

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
        end
    endtask

    initial begin
        pclk     = 1'b0;
        preset_n = 1'b0;
        psel     = 1'b0;
        penable  = 1'b0;
        pwrite   = 1'b0;
        paddr    = 8'h00;
        pwdata   = 32'h00000000;
        errors   = 0;
        passed   = 0;

        $dumpfile("apb.vcd");
        $dumpvars(0, tb_apb_gpio_slave);

        $display("======================================");
        $display(" APB GPIO SLAVE VERIFICATION");
        $display("======================================");

        repeat (2) @(negedge pclk);
        preset_n = 1'b1;

        // Test 1: Write zero
        apb_write(8'h00, 32'h00000000, 1'b0);

        // Test 2: Write a mixed-bit pattern
        apb_write(8'h00, 32'h12345678, 1'b0);

        // Test 3: Read back the written GPIO register
        apb_read(8'h00, 32'h12345678, 1'b0);

        // Test 4: Write all ones
        apb_write(8'h00, 32'hFFFFFFFF, 1'b0);

        // Test 5: Read back all ones
        apb_read(8'h00, 32'hFFFFFFFF, 1'b0);

        // Test 6: Write alternating bits
        apb_write(8'h00, 32'hAAAAAAAA, 1'b0);

        // Test 7: Read back alternating bits
        apb_read(8'h00, 32'hAAAAAAAA, 1'b0);

        // Test 8: Check reset value
        @(negedge pclk);
        preset_n = 1'b0;

        repeat (2) @(negedge pclk);

        if (gpio_out !== 32'h00000000) begin
            $display(
                "[FAIL] RESET GPIO=%08h expected=00000000",
                gpio_out
            );
            errors = errors + 1;
        end else begin
            $display("[PASS] RESET GPIO=00000000");
            passed = passed + 1;
        end

        @(negedge pclk);
        preset_n = 1'b1;

        $display("--------------------------------------");
        $display("Tests passed: %0d", passed);
        $display("Tests failed: %0d", errors);

        if (errors == 0)
            $display("APB GPIO TEST PASSED");
        else
            $display("APB GPIO TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Simulation timeout");
        $finish;
    end

endmodule
