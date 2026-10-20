`timescale 1ns/1ps
module apb_gpio_slave(
    input wire pclk, input wire preset_n,
    input wire psel, input wire penable, input wire pwrite,
    input wire [7:0] paddr, input wire [31:0] pwdata,
    output reg [31:0] prdata, output wire pready, output reg pslverr,
    output reg [31:0] gpio_out
);
    reg [31:0] status;
    assign pready=1'b1;
    always @(posedge pclk or negedge preset_n) begin
        if(!preset_n) begin gpio_out<=0; status<=0; prdata<=0; pslverr<=0; end
        else begin
            pslverr<=0;
            if(psel && penable) begin
                if(paddr==8'h00) begin
                    if(pwrite) gpio_out<=pwdata; else prdata<=gpio_out;
                end else if(paddr==8'h04) begin
                    if(pwrite) status<=pwdata; else prdata<=status;
                end else begin pslverr<=1; prdata<=0; end
            end
        end
    end
endmodule
