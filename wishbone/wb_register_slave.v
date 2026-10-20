`timescale 1ns/1ps
module wb_register_slave(
    input wire clk, input wire rst_n,
    input wire cyc, input wire stb, input wire we,
    input wire [3:0] adr, input wire [31:0] dat_i,
    output reg [31:0] dat_o, output reg ack, output reg err
);
    reg [31:0] regs[0:3];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dat_o<=0; ack<=0; err<=0;
            for(i=0;i<4;i=i+1) regs[i]<=0;
        end else begin
            ack<=0; err<=0;
            if(cyc && stb && !ack) begin
                if(adr[3:2] < 4) begin
                    if(we) regs[adr[3:2]]<=dat_i;
                    else dat_o<=regs[adr[3:2]];
                    ack<=1;
                end else begin err<=1; ack<=1; end
            end
        end
    end
endmodule
