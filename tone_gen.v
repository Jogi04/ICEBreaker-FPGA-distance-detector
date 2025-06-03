module tone_gen(
    input wire clk_i,
    input wire reset_ni,
    input wire [15:0] COUNT_LIMIT,
    output wire signed [23:0] sample_o,
    output wire sample_ready_o
);

localparam signed POS_MAX_SIGNED_24BIT = 24'sh7FFFFF;
localparam signed NEG_MAX_SIGNED_24BIT = 24'sh800000;
//localparam COUNT_LIMIT = 16'd36750;  // Half-period for 1kHz tone @ 36.75 MHz

// counter for toggling waveform
reg [15:0] counter_d, counter_q;
always @(posedge clk_i, negedge reset_ni) begin
    if (!reset_ni)
        counter_q <= 'b0;
    else
        counter_q <= counter_d;
end

always @(*) begin
    if (counter_q < COUNT_LIMIT)
        counter_d = counter_q + 1;
    else
        counter_d = 'b0;
end

// generate waveform
reg [23:0] sample_d, sample_q;
reg sample_ready_d, sample_ready_q;

always @(posedge clk_i, negedge reset_ni) begin
    if (!reset_ni) begin
        sample_q <= 'b0;
        sample_ready_q <= 1'b0;
    end else begin
        sample_q <= sample_d;
        sample_ready_q <= sample_ready_d;
    end
end

always @(*) begin
    sample_d = sample_q;
    sample_ready_d = 1'b0;
    
    if (counter_q == 0) begin
        sample_d = POS_MAX_SIGNED_24BIT;
        sample_ready_d = 1'b1;
    end else if (counter_q == COUNT_LIMIT / 2) begin
        sample_d = NEG_MAX_SIGNED_24BIT;
        sample_ready_d = 1'b1;
    end
end

assign sample_o = sample_q;
assign sample_ready_o = sample_ready_q;

endmodule
