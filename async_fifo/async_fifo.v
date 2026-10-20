`timescale 1ns/1ps
module async_fifo #(
    parameter DATA_WIDTH=8, parameter ADDR_WIDTH=3
)(
    input wire wr_clk, input wire rd_clk, input wire rst_n,
    input wire wr_en, input wire [DATA_WIDTH-1:0] wr_data, output wire full,
    input wire rd_en, output reg [DATA_WIDTH-1:0] rd_data, output wire empty
);
    localparam DEPTH=(1<<ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg [ADDR_WIDTH:0] wr_bin,rd_bin,wr_gray,rd_gray;
    reg [ADDR_WIDTH:0] rd_gray_w1,rd_gray_w2,wr_gray_r1,wr_gray_r2;
    wire [ADDR_WIDTH:0] wr_bin_next,rd_bin_next,wr_gray_next,rd_gray_next;
    assign wr_bin_next=wr_bin+(wr_en && !full);
    assign rd_bin_next=rd_bin+(rd_en && !empty);
    assign wr_gray_next=(wr_bin_next>>1)^wr_bin_next;
    assign rd_gray_next=(rd_bin_next>>1)^rd_bin_next;
    assign full=(wr_gray_next=={~rd_gray_w2[ADDR_WIDTH:ADDR_WIDTH-1],rd_gray_w2[ADDR_WIDTH-2:0]});
    assign empty=(rd_gray==wr_gray_r2);
    always @(posedge wr_clk or negedge rst_n) begin
        if(!rst_n) begin wr_bin<=0; wr_gray<=0; rd_gray_w1<=0; rd_gray_w2<=0; end
        else begin
            rd_gray_w1<=rd_gray; rd_gray_w2<=rd_gray_w1;
            if(wr_en && !full) mem[wr_bin[ADDR_WIDTH-1:0]]<=wr_data;
            wr_bin<=wr_bin_next; wr_gray<=wr_gray_next;
        end
    end
    always @(posedge rd_clk or negedge rst_n) begin
        if(!rst_n) begin rd_bin<=0; rd_gray<=0; wr_gray_r1<=0; wr_gray_r2<=0; rd_data<=0; end
        else begin
            wr_gray_r1<=wr_gray; wr_gray_r2<=wr_gray_r1;
            if(rd_en && !empty) begin rd_data<=mem[rd_bin[ADDR_WIDTH-1:0]]; rd_bin<=rd_bin_next; rd_gray<=rd_gray_next; end
        end
    end
endmodule
