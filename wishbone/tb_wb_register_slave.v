`timescale 1ns/1ps

module tb_wb_register_slave;

    reg clk = 0;
    reg rst_n = 0;
    reg cyc = 0;
    reg stb = 0;
    reg we = 0;

    reg [3:0] adr = 0;
    reg [31:0] dat_i = 0;

    wire [31:0] dat_o;
    wire ack, err;

    integer errors = 0;

    always #5 clk = ~clk;

    wb_register_slave dut (
        clk, rst_n, cyc, stb, we, adr, dat_i,
        dat_o, ack, err
    );

    // Wishbone write transaction
    task wb_write;
        input [3:0] address;
        input [31:0] write_data;
        integer timeout;
        begin
            @(negedge clk);
            cyc   = 1;
            stb   = 1;
            we    = 1;
            adr   = address;
            dat_i = write_data;

            timeout = 0;
            while (ack !== 1'b1 && timeout < 20) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end

            if (timeout >= 20) begin
                $display("[FAIL] WRITE timeout at address %h", address);
                errors = errors + 1;
            end else if (err !== 1'b0) begin
                $display("[FAIL] WRITE error at address %h", address);
                errors = errors + 1;
            end else begin
                $display("[PASS] WRITE address=%h data=%h",
                         address, write_data);
            end

            @(negedge clk);
            cyc = 0;
            stb = 0;
            we  = 0;

            // Allow ACK to return inactive before the next transaction.
            repeat (2) @(negedge clk);
        end
    endtask

    // Wishbone read transaction
    task wb_read_check;
        input [3:0] address;
        input [31:0] expected_data;
        integer timeout;
        reg [31:0] read_data;
        begin
            @(negedge clk);
            cyc = 1;
            stb = 1;
            we  = 0;
            adr = address;

            timeout = 0;
            while (ack !== 1'b1 && timeout < 20) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end

            if (timeout >= 20) begin
                $display("[FAIL] READ timeout at address %h", address);
                errors = errors + 1;
            end else if (err !== 1'b0) begin
                $display("[FAIL] READ error at address %h", address);
                errors = errors + 1;
            end else begin
                read_data = dat_o;

                if (read_data !== expected_data) begin
                    $display("[FAIL] READ address=%h expected=%h received=%h",
                             address, expected_data, read_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] READ address=%h data=%h",
                             address, read_data);
                end
            end

            @(negedge clk);
            cyc = 0;
            stb = 0;

            repeat (2) @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("wishbone.vcd");
        $dumpvars(0, tb_wb_register_slave);

        $display("====================================");
        $display(" WISHBONE REGISTER SLAVE TEST");
        $display("====================================");

        repeat (2) @(negedge clk);
        rst_n = 1;

        // Write and read back register address 0.
        wb_write(4'h0, 32'h00001234);
        wb_read_check(4'h0, 32'h00001234);

        // Write and read back a second value.
        wb_write(4'h0, 32'hA5A55A5A);
        wb_read_check(4'h0, 32'hA5A55A5A);

        $display("------------------------------------");
        if (errors == 0)
            $display("WISHBONE TEST PASSED");
        else
            $display("WISHBONE TEST FAILED: %0d error(s)", errors);
        $display("------------------------------------");

        $finish;
    end

endmodule
