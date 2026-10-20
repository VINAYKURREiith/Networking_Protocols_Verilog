`timescale 1ns/1ps
module uart_tx #(
    parameter integer CLKS_PER_BIT = 16
)(
    input wire clk, input wire rst_n,
    input wire start, input wire [7:0] data_in,
    output reg tx, output reg busy, output reg done
);
    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0] state;
    reg [7:0] data_buf;
    reg [3:0] bit_idx;
    integer count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; tx<=1'b1; busy<=1'b0; done<=1'b0;
            data_buf<=0; bit_idx<=0; count<=0;
        end else begin
            done<=1'b0;
            case(state)
                IDLE: begin
                    tx<=1'b1; busy<=1'b0; count<=0; bit_idx<=0;
                    if(start) begin data_buf<=data_in; state<=START; busy<=1'b1; tx<=1'b0; end
                end
                START: begin
                    tx<=1'b0;
                    if(count==CLKS_PER_BIT-1) begin count<=0; state<=DATA; end
                    else count<=count+1;
                end
                DATA: begin
                    tx<=data_buf[bit_idx];
                    if(count==CLKS_PER_BIT-1) begin
                        count<=0;
                        if(bit_idx==7) state<=STOP;
                        else bit_idx<=bit_idx+1'b1;
                    end else count<=count+1;
                end
                STOP: begin
                    tx<=1'b1;
                    if(count==CLKS_PER_BIT-1) begin count<=0; state<=IDLE; busy<=1'b0; done<=1'b1; end
                    else count<=count+1;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
