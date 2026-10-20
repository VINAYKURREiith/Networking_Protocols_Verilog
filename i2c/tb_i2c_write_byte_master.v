`timescale 1ns/1ps

module tb_i2c_write_byte_master;

    reg clk;
    reg rst_n;
    reg start;
    reg [6:0] slave_addr;
    reg [7:0] data_in;
    wire sda_in;

    wire sda_drive_low;
    wire scl_drive_low;
    wire busy;
    wire done;
    wire ack_error;

    integer errors;
    integer passed;
    integer timeout_count;

    // Simplified ACK responder for this controller's ACK states.
    // A realistic bus-level test should use a separate slave model.
    assign sda_in =
        (dut.state == 3'd3 || dut.state == 3'd5) ? 1'b0 : 1'b1;

    always #5 clk = ~clk;

    i2c_write_byte_master #(
        .DIVIDER(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .data_in(data_in),
        .sda_in(sda_in),
        .sda_drive_low(sda_drive_low),
        .scl_drive_low(scl_drive_low),
        .busy(busy),
        .done(done),
        .ack_error(ack_error)
    );

    task send_byte;
        input [6:0] address;
        input [7:0] value;

        begin
            $display("--------------------------------------");
            $display(
                "[INFO] Starting write: address=%02h data=%02h",
                address, value
            );

            // Wait for an idle controller.
            @(negedge clk);

            timeout_count = 0;

            while (busy !== 1'b0 && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (busy !== 1'b0) begin
                $display("[FAIL] Controller did not become idle");
                errors = errors + 1;
            end else begin
                slave_addr = address;
                data_in = value;
                start = 1'b1;

                @(negedge clk);
                start = 1'b0;

                // Wait for transaction completion.
                timeout_count = 0;

                while (done !== 1'b1 && timeout_count < 1000) begin
                    @(negedge clk);
                    timeout_count = timeout_count + 1;
                end

                if (done !== 1'b1) begin
                    $display("[FAIL] Transaction timeout");
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Transaction completed");
                    passed = passed + 1;

                    if (ack_error !== 1'b0) begin
                        $display(
                            "[FAIL] ACK error=%b expected=0",
                            ack_error
                        );
                        errors = errors + 1;
                    end else begin
                        $display("[PASS] Address/data ACK received");
                        passed = passed + 1;
                    end
                end

                if (busy !== 1'b0) begin
                    $display("[FAIL] BUSY did not clear");
                    errors = errors + 1;
                end else begin
                    $display("[PASS] BUSY cleared");
                    passed = passed + 1;
                end

                // Allow the controller to return to IDLE.
                repeat (3) @(negedge clk);
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        slave_addr = 7'h29;
        data_in = 8'hA6;
        errors = 0;
        passed = 0;
        timeout_count = 0;

        $dumpfile("i2c.vcd");
        $dumpvars(0, tb_i2c_write_byte_master);

        $display("======================================");
        $display(" I2C WRITE MASTER VERIFICATION");
        $display(" 7-bit address | 8-bit data");
        $display("======================================");

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        send_byte(7'h29, 8'hA6);
        send_byte(7'h50, 8'h3C);
        send_byte(7'h12, 8'hFF);

        $display("======================================");
        $display("Checks passed: %0d", passed);
        $display("Checks failed: %0d", errors);

        if (errors == 0)
            $display("I2C BASIC TEST PASSED");
        else
            $display("I2C BASIC TEST FAILED");

        $finish;
    end

    initial begin
        #200000;
        $display("[FATAL] Global simulation timeout");
        $finish;
    end

endmodule
