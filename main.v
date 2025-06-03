module main (
    input clk,
    input pwm_i,
    input reset_ni,
    output led,
    // I2S DAC interface
    output wire i2s_dac_mclk_o,
    output wire i2s_dac_sclk_o,
    output wire i2s_dac_lrclk_o,
    output wire i2s_dac_sdin_o
);


// PLL
wire clk_w;
pll u_pll (
    .clock_in(clk),
    .clock_out(clk_w),
    .locked()
);



// I2S DAC interface
wire signed [23:0] sample;
wire sample_ready;

i2s_dac u_i2s_dac (
    .clk_i(clk_w),
    .reset_ni(reset_ni),
    .i2s_dac_mclk_o(i2s_dac_mclk_o),
    .i2s_dac_sclk_o(i2s_dac_sclk_o),
    .i2s_dac_lrclk_o(i2s_dac_lrclk_o),
    .i2s_dac_sdin_o(i2s_dac_sdin_o),
    .sample_r_i(sample),
    .sample_l_i(sample),
    .sample_ready_i(sample_ready)
);




// Tone Generation
wire signed [23:0] sample_tone;
wire sample_ready_tone;
reg tone_enable = 0;
assign sample = tone_enable ? sample_tone : 24'd0;
assign sample_ready = tone_enable ? sample_ready_tone : 1'b0;


reg [15:0] COUNT_LIMIT = 16'd0;

localparam COUNT_500HZ = 16'd36750;  // Half-period for 500Hz tone @ 36.75 MHz
localparam COUNT_1KHZ  = 16'd18375;  // Half-period for 1kHz tone @ 36.75 MHz


tone_gen u_tone_generator (
    .clk_i(clk_w),
    .reset_ni(reset_ni),
    .COUNT_LIMIT(COUNT_LIMIT),
    .sample_o(sample_tone),
    .sample_ready_o(sample_ready_tone)
);




// Counter for 36.750MHz / 3 = 12.25 MHz clock
reg [1:0] clk_counter = 0;
reg clk_12mhz = 0;

always @(posedge clk_w or negedge reset_ni) begin
    if (!reset_ni) begin
        clk_counter <= 0;
        clk_12mhz <= 0;
    end else begin
        if (clk_counter == 2) begin
            clk_counter <= 0;
            clk_12mhz <= ~clk_12mhz;
        end else begin
            clk_counter <= clk_counter + 1;
        end
    end
end




// ultrasonic distance sensor
wire [15:0] width;
wire ready;

localparam integer cycles_per_cm = 350;
localparam integer distance_cm_min = 15;
localparam integer distance_cm_max = 100;
localparam integer distance_cm_1 = 30;
localparam integer distance_cm_2 = 50;

ultrasonic_sensor s (
    .clk(clk_12mhz),
    .sig(pwm_i),
    .width(width),
    .ready(ready)
);

reg led_reg = 0;
assign led = led_reg;




// LED and tone control based on distance
always @(posedge clk_12mhz or negedge reset_ni) begin
    if (!reset_ni) begin
        led_reg <= 0;
        tone_enable <= 0;
        COUNT_LIMIT = 16'd0;
    end else if (ready) begin
        if (width < distance_cm_min * cycles_per_cm || width > distance_cm_max * cycles_per_cm) begin
            led_reg <= 0;
            tone_enable <= 0;
            COUNT_LIMIT = 16'd0;
        end else if (width > distance_cm_min * cycles_per_cm && width < distance_cm_1 * cycles_per_cm) begin
            led_reg <= 1;
            tone_enable <= 1;
            COUNT_LIMIT = COUNT_1KHZ;
        end else if (width >= distance_cm_1 * cycles_per_cm && width < distance_cm_2 * cycles_per_cm) begin
            led_reg <= 1;
            tone_enable <= 1;
            COUNT_LIMIT = COUNT_500HZ;
        end else begin
            led_reg <= 0;
            tone_enable <= 0;
            COUNT_LIMIT = 16'd0;
        end
    end
end



endmodule


