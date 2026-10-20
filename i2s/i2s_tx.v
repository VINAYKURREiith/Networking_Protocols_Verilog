`timescale 1ns/1ps

module i2s_tx #(
    parameter WORD_BITS = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   sample_valid,
    input  wire [2*WORD_BITS-1:0] sample_stereo,

    output reg                    bclk,
    output reg                    lrclk,
    output reg                    sdata,
    output reg                    ready
);

    localparam FRAME_BITS = 2 * (WORD_BITS + 1);

    reg [2*WORD_BITS-1:0] frame_data;
    reg active;
    reg [31:0] slot_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk       <= 1'b0;
            lrclk      <= 1'b0;
            sdata      <= 1'b0;
            ready      <= 1'b1;
            frame_data <= 0;
            active     <= 1'b0;
            slot_count <= 0;
        end else begin
            bclk <= ~bclk;

            if (!active) begin
                ready <= 1'b1;

                if (sample_valid && ready) begin
                    frame_data <= sample_stereo;
                    active     <= 1'b1;
                    ready      <= 1'b0;
                    slot_count <= 0;
                    lrclk      <= 1'b0;
                    sdata      <= 1'b0;
                end
            end else if (bclk == 1'b1) begin
                // Data changes when BCLK falls.

                if (slot_count == 0) begin
                    // Left-channel delay bit
                    sdata <= 1'b0;
                    lrclk <= 1'b0;
                end else if (slot_count <= WORD_BITS) begin
                    // Left channel, MSB first
                    sdata <= frame_data[
                        2*WORD_BITS - slot_count
                    ];
                    lrclk <= 1'b0;
                end else if (slot_count == WORD_BITS + 1) begin
                    // Right-channel delay bit
                    sdata <= 1'b0;
                    lrclk <= 1'b1;
                end else begin
                    // Right channel, MSB first
                    sdata <= frame_data[
                        WORD_BITS - 1 -
                        (slot_count - WORD_BITS - 2)
                    ];
                    lrclk <= 1'b1;
                end

                if (slot_count == FRAME_BITS - 1) begin
                    active     <= 1'b0;
                    ready      <= 1'b1;
                    slot_count <= 0;
                end else begin
                    slot_count <= slot_count + 1'b1;
                end
            end
        end
    end

endmodule
