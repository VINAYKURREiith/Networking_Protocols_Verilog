`timescale 1ns/1ps

module tb_async_fifo;

    reg wr_clk, rd_clk, rst_n;
    reg wr_en, rd_en;
    reg [7:0] wr_data;

    wire [7:0] rd_data;
    wire full, empty;

    integer errors, passed;
    integer i, timeout_count;

    reg [7:0] expected_mem [0:3];

    always #5 wr_clk = ~wr_clk;
    always #7 rd_clk = ~rd_clk;

    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(3)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty)
    );

    // Write one byte.
    task fifo_write;
        input [7:0] data;
        begin
            @(negedge wr_clk);

            if (full !== 1'b0) begin
                $display("[FAIL] FIFO full before writing %02h", data);
                errors = errors + 1;
            end else begin
                wr_en = 1'b1;
                wr_data = data;

                // Write is accepted at the next rising wr_clk edge.
                @(negedge wr_clk);
                wr_en = 1'b0;

                $display("[PASS] Write accepted: %02h", data);
                passed = passed + 1;
            end
        end
    endtask

    // Read one byte and check registered output after the read edge.
    task fifo_read;
        input [7:0] expected;
        begin
            timeout_count = 0;

            // Wait for synchronized write pointer to reach read domain.
            while ((empty !== 1'b0) && (timeout_count < 100)) begin
                @(negedge rd_clk);
                timeout_count = timeout_count + 1;
            end

            if (empty !== 1'b0) begin
                $display("[FAIL] Timeout waiting for FIFO data");
                errors = errors + 1;
            end else begin
                // Assert read enable before the active read edge.
                @(negedge rd_clk);
                rd_en = 1'b1;

                // FIFO registers rd_data on this rising edge.
                @(posedge rd_clk);
                #1;

                if (rd_data !== expected) begin
                    $display(
                        "[FAIL] Expected=%02h Received=%02h",
                        expected, rd_data
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "[PASS] Read=%02h Expected=%02h",
                        rd_data, expected
                    );
                    passed = passed + 1;
                end

                // Deassert read enable before the next rising edge.
                @(negedge rd_clk);
                rd_en = 1'b0;
            end
        end
    endtask

    initial begin
        wr_clk = 0;
        rd_clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        errors = 0;
        passed = 0;
        timeout_count = 0;

        expected_mem[0] = 8'h20;
        expected_mem[1] = 8'h21;
        expected_mem[2] = 8'h22;
        expected_mem[3] = 8'h23;

        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        $display("======================================");
        $display(" ASYNCHRONOUS FIFO VERIFICATION");
        $display(" Write clock: 10 ns");
        $display(" Read clock : 14 ns");
        $display(" FIFO depth : 8 entries");
        $display("======================================");

        // Reset
        repeat (4) @(negedge wr_clk);
        rst_n = 1'b1;

        repeat (5) @(negedge rd_clk);

        if (empty !== 1'b1) begin
            $display("[FAIL] FIFO not empty after reset");
            errors = errors + 1;
        end else begin
            $display("[PASS] FIFO empty after reset");
            passed = passed + 1;
        end

        // Write four bytes.
        for (i = 0; i < 4; i = i + 1)
            fifo_write(expected_mem[i]);

        // Allow the write pointer to synchronize to the read domain.
        repeat (5) @(negedge rd_clk);

        // Read and check all four bytes in FIFO order.
        for (i = 0; i < 4; i = i + 1)
            fifo_read(expected_mem[i]);

        // Allow read-pointer synchronization to settle.
        repeat (5) @(negedge rd_clk);

        if (empty !== 1'b1) begin
            $display("[FAIL] FIFO not empty after all reads");
            errors = errors + 1;
        end else begin
            $display("[PASS] FIFO empty after all reads");
            passed = passed + 1;
        end

        $display("--------------------------------------");
        $display("Checks passed: %0d", passed);
        $display("Checks failed: %0d", errors);

        if (errors == 0)
            $display("ASYNC FIFO TEST PASSED");
        else
            $display("ASYNC FIFO TEST FAILED");

        $finish;
    end

    initial begin
        #100000;
        $display("[FATAL] Global simulation timeout");
        $finish;
    end

endmodule
