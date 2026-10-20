`timescale 1ns/1ps
module uart_rx #(
    parameter integer CLKS_PER_BIT = 16
)(
    input wire clk, input wire rst_n, input wire rx,
    output reg [7:0] data_out, output reg valid,
    output reg framing_error
);
    localparam IDLE=2'd0, START=2'd1, DATA=2'd2, STOP=2'd3;
    reg [1:0] state;
    reg [7:0] data_buf;
    reg [2:0] bit_idx;
    integer count;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE; data_out<=0; valid<=0; framing_error<=0;
            data_buf<=0; bit_idx<=0; count<=0;
        end else begin
            valid<=0; framing_error<=0;
            case(state)
                IDLE: if(!rx) begin state<=START; count<=0; end
                START: begin
                    if(count==(CLKS_PER_BIT/2)-1) begin
                        count<=0;
                        if(!rx) begin state<=DATA; bit_idx<=0; end
                        else state<=IDLE;
                    end else count<=count+1;
                end
                DATA: begin
                    if(count==CLKS_PER_BIT-1) begin
                        count<=0; data_buf[bit_idx]<=rx;
                        if(bit_idx==7) state<=STOP;
                        else bit_idx<=bit_idx+1'b1;
                    end else count<=count+1;
                end
                STOP: begin
                    if(count==CLKS_PER_BIT-1) begin
                        count<=0; state<=IDLE;
                        if(rx) begin data_out<=data_buf; valid<=1'b1; end
                        else framing_error<=1'b1;
                    end else count<=count+1;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
