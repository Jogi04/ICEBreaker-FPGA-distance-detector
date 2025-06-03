module i2s_dac(
	input wire clk_i,
	input wire reset_ni,
	output wire i2s_dac_mclk_o,
	output wire i2s_dac_sclk_o,
	output wire i2s_dac_lrclk_o,
	output wire i2s_dac_sdin_o,
	input wire signed [23:0] sample_r_i,
	input wire signed [23:0] sample_l_i,
	input wire sample_ready_i
);

localparam SCLK_TO_LRCLK = 'd64;//SCLK to LRCLK = 64 (as in datasheet)
localparam MCLK_TO_SCLK = 'd6; 
parameter LEFT_CHANNEL = 1'b0;
parameter RIGHT_CHANNEL = 1'b1;

reg sclk_q, sclk_d;
reg sclk_trigger_q, sclk_trigger_d;
reg lrclk_q, lrclk_d;
reg shift_register_load_q, shift_register_load_d;
reg serial_out_d, serial_out_q;
reg [5:0] lrclk_counter_q, lrclk_counter_d;
reg [2:0] sclk_counter_q, sclk_counter_d;
reg [63:0] shift_register_q, shift_register_d;
reg [23:0] sample_r_buffered_q, sample_r_buffered_d;
reg [23:0] sample_l_buffered_q, sample_l_buffered_d;

assign i2s_dac_mclk_o = clk_i; //the mclk is choosen to be the MCLK with 36.75MHz clk
assign i2s_dac_sclk_o = sclk_q;
assign i2s_dac_lrclk_o = lrclk_q;
assign i2s_dac_sdin_o = serial_out_q;

//note:
//the device is operated in external serial mode
//LRCLK changes on falling sclk, LRCLK = 96kHz => MCLK/384
//sdin MSB is read at second rinsing edge of SCLK after LRCLK change

//buffer input sample when it is ready
always @ (posedge clk_i, negedge reset_ni)
begin
	if(!reset_ni) begin	
		sample_r_buffered_q <= 'b0;
		sample_l_buffered_q <= 'b0;
	end else begin
		sample_r_buffered_q <= sample_r_buffered_d;
		sample_l_buffered_q <= sample_l_buffered_d;
	
	end
end

always @ (*)
begin
	sample_r_buffered_d = sample_r_buffered_q;
	sample_l_buffered_d = sample_l_buffered_q;
	if (sample_ready_i) begin
		sample_r_buffered_d = sample_r_i;
		sample_l_buffered_d = sample_l_i;			 
	end
end

//generate sclk
always @ (posedge clk_i, negedge reset_ni)
begin
	if(!reset_ni) begin
		sclk_q <= 1'b0;
		sclk_counter_q <= 'b0;
		sclk_trigger_q <= 1'b0;
	end else begin	
		sclk_q <= sclk_d;
		sclk_counter_q <= sclk_counter_d;
		sclk_trigger_q <= sclk_trigger_d;
	end
end

always @ (*) 
begin
	sclk_d = sclk_q;
	sclk_counter_d = sclk_counter_q + 1;
	sclk_trigger_d = 1'b0;
	if (sclk_counter_q == (MCLK_TO_SCLK/2) -1) begin
		sclk_d = 1'b0;
	end else if (sclk_counter_q >= MCLK_TO_SCLK - 1) begin
		sclk_counter_d = 'b0;
		sclk_d = 1'b1;
	end	else if (sclk_counter_q == (MCLK_TO_SCLK/2) -2) begin //one clk cycle before set trigger
		sclk_trigger_d = 1'b1;
	end
end

//generate lrclk
always @ (posedge clk_i, negedge reset_ni)
begin
	if(!reset_ni) begin
		lrclk_q <= LEFT_CHANNEL;
		lrclk_counter_q <= 'b0;
	end else begin
		lrclk_q <= lrclk_d;
		lrclk_counter_q <= lrclk_counter_d;
	end
end
	
always @ (*)
begin	
	lrclk_d = lrclk_q;
	lrclk_counter_d = lrclk_counter_q;
	if (sclk_trigger_q == 1'b1) begin
		if (lrclk_counter_q < (SCLK_TO_LRCLK) - 1) begin
			lrclk_counter_d = lrclk_counter_q + 1;
		end else begin
			lrclk_counter_d = 'b0;
		end
	
		if (lrclk_counter_q == (SCLK_TO_LRCLK/2) - 1) begin
			lrclk_d = RIGHT_CHANNEL;
		end else if (lrclk_counter_q == (SCLK_TO_LRCLK) - 1) begin
			lrclk_d = LEFT_CHANNEL;
		end
	end
end

//generate the shift register load signal
always @ (posedge clk_i, negedge reset_ni)
begin
	if(!reset_ni) begin
		shift_register_load_q <= 'b0;
	end else begin
		shift_register_load_q <= shift_register_load_d;
	end
end
	
always @ (*)
begin	
	shift_register_load_d = 'b0;
	if ((lrclk_counter_q == (SCLK_TO_LRCLK) - 1) & (sclk_counter_q == (MCLK_TO_SCLK/2) -2)) begin 
		shift_register_load_d = 1'b1;
	end
end

//shift register to transfer 2x 24 bit parallel to one serial stream for the DAC. As we have on the bus 2x32 bit fill the rest with 0's
always @ (posedge clk_i, negedge reset_ni)
begin
	if(!reset_ni) begin
		shift_register_q <= 'b0;
		serial_out_q <= 'b0;
	end else begin
		shift_register_q <= shift_register_d;
		serial_out_q <= serial_out_d;
	end
end

always @ (*)
begin
	shift_register_d = shift_register_q;
	serial_out_d = serial_out_q;
	if (sclk_trigger_q == 1'b1) begin
		if (shift_register_load_q == 1'b1) begin
			shift_register_d = {sample_l_buffered_q, 7'b0, 1'b0, sample_r_buffered_q, 7'b0, 1'b0}; //assemble shift register
			serial_out_d = 'b0;
		end else begin //do the shifting
			shift_register_d = shift_register_q << 1; //shift one left
			serial_out_d = shift_register_q[63];
		end
	end
end

endmodule