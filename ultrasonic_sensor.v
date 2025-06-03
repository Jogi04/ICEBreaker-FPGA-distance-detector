module ultrasonic_sensor (
    input clk,
    input sig,
    output reg [15:0] width,
    output reg ready
);


// pulse width counter
reg [15:0] counter = 0;
reg prev_sig = 0;

always @(posedge clk) begin
    prev_sig <= sig;

    if (sig && !prev_sig) begin
        counter <= 0;
        ready <= 0;
    end else if (sig) begin
        counter <= counter + 1;
    end else if (!sig && prev_sig) begin
        width <= counter;
        ready <= 1;
    end else begin
        ready <= 0;
    end
end

endmodule
