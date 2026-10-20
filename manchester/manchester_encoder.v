`timescale 1ns/1ps
module manchester_encoder(
    input wire clk, input wire rst_n, input wire bit_valid, input wire data_bit,
    output reg encoded, output reg busy, output reg done
);
    reg second_half, saved_bit;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin encoded<=1; busy<=0; done<=0; second_half<=0; saved_bit<=0; end
        else begin
            done<=0;
            if(!busy && bit_valid) begin
                saved_bit<=data_bit; encoded<=data_bit ? 1'b0 : 1'b1;
                busy<=1; second_half<=0;
            end else if(busy) begin
                if(!second_half) begin encoded<=saved_bit ? 1'b1 : 1'b0; second_half<=1; end
                else begin busy<=0; done<=1; end
            end
        end
    end
endmodule
