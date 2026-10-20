`timescale 1ns/1ps
// Minimal I2C single-byte WRITE master.
// Connect sda_drive_low/scl_drive_low to open-drain drivers and pull-ups.
// This teaching implementation does not implement clock stretching/arbitration.
module i2c_write_byte_master #(
    parameter integer DIVIDER = 4
)(
    input wire clk, input wire rst_n, input wire start,
    input wire [6:0] slave_addr, input wire [7:0] data_in,
    input wire sda_in,
    output reg sda_drive_low, output reg scl_drive_low,
    output reg busy, output reg done, output reg ack_error
);
    localparam IDLE=0, START=1, ADDR=2, ACK1=3, DATA=4, ACK2=5, STOP=6;
    reg [2:0] state;
    reg [7:0] shift;
    reg [3:0] bit_idx;
    integer divcnt;
    reg [1:0] phase;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE; sda_drive_low<=0; scl_drive_low<=0; busy<=0; done<=0;
            ack_error<=0; shift<=0; bit_idx<=0; divcnt<=0; phase<=0;
        end else begin
            done<=0;
            if(state==IDLE) begin
                busy<=0; sda_drive_low<=0; scl_drive_low<=0; divcnt<=0; phase<=0;
                if(start) begin shift<={slave_addr,1'b0}; bit_idx<=7; state<=START; busy<=1; ack_error<=0; end
            end else if(divcnt==DIVIDER-1) begin
                divcnt<=0;
                case(state)
                    START: begin
                        // START: SDA falls while SCL is released high
                        scl_drive_low<=0; sda_drive_low<=1; shift<={slave_addr,1'b0}; bit_idx<=7; state<=ADDR; phase<=0;
                    end
                    ADDR,DATA: begin
                        case(phase)
                            0: begin scl_drive_low<=1; sda_drive_low<=~shift[bit_idx]; phase<=1; end
                            1: begin scl_drive_low<=0; phase<=2; end
                            2: begin scl_drive_low<=0; phase<=3; end
                            3: begin
                                scl_drive_low<=1; phase<=0;
                                if(bit_idx==0) begin
                                    if(state==ADDR) state<=ACK1; else state<=ACK2;
                                end else bit_idx<=bit_idx-1'b1;
                            end
                        endcase
                    end
                    ACK1,ACK2: begin
                        case(phase)
                            0: begin sda_drive_low<=0; scl_drive_low<=1; phase<=1; end
                            1: begin scl_drive_low<=0; phase<=2; end
                            2: begin ack_error<=sda_in; phase<=3; end
                            3: begin scl_drive_low<=1; phase<=0;
                                if(state==ACK1) begin shift<=data_in; bit_idx<=7; state<=DATA; end
                                else state<=STOP;
                            end
                        endcase
                    end
                    STOP: begin
                        scl_drive_low<=1; sda_drive_low<=1; phase<=1; state<=IDLE; done<=1; busy<=0;
                    end
                    default: state<=IDLE;
                endcase
            end else divcnt<=divcnt+1;
        end
    end
endmodule
