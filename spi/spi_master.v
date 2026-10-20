`timescale 1ns/1ps

module spi_master #(
    parameter integer CLK_DIV = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,

    output reg        sclk,
    output reg        cs_n,
    output reg        mosi,
    output reg        busy,
    output reg        done,
    output reg [7:0]  rx_data
);

    reg [7:0] tx_shift;
    reg [2:0] bit_count;
    reg [31:0] clk_count;
    reg [1:0] state;

    localparam IDLE = 2'd0;
    localparam TRANSFER = 2'd1;
    localparam FINISH = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk      <= 1'b0;
            cs_n      <= 1'b1;
            mosi      <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
            rx_data   <= 8'b0;
            tx_shift  <= 8'b0;
            bit_count <= 3'd0;
            clk_count <= 0;
            state     <= IDLE;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    sclk      <= 1'b0;
                    cs_n      <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 0;

                    if (start) begin
                        tx_shift  <= tx_data;
                        rx_data   <= 8'b0;
                        bit_count <= 3'd0;
                        mosi      <= tx_data[7];
                        cs_n      <= 1'b0;
                        busy      <= 1'b1;
                        state     <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (clk_count == CLK_DIV - 1) begin
                        clk_count <= 0;

                        if (sclk == 1'b0) begin
                            // Rising edge: sample MISO.
                            sclk <= 1'b1;
                            rx_data <= {rx_data[6:0], miso};
                        end else begin
                            // Falling edge: prepare next MOSI bit.
                            sclk <= 1'b0;

                            if (bit_count == 3'd7) begin
                                state <= FINISH;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                                tx_shift <= {tx_shift[6:0], 1'b0};
                                mosi <= tx_shift[6];
                            end
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                FINISH: begin
                    sclk  <= 1'b0;
                    cs_n  <= 1'b1;
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
