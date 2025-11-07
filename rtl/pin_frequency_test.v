// pin_frequency_test.v - Test version to verify pin assignments
// LED: 1Hz, SCL: 10Hz, SDA: 100Hz
// Use oscilloscope to measure frequencies and verify pins

module i2c_slave_top (
    input clk_p,        // 50MHz differential clock positive (C12)
    input clk_n,        // 50MHz differential clock negative (C11)
    output scl,         // OUTPUT for frequency test (R14)
    inout sda,          // Will be OUTPUT in this test (T14)
    output led          // LED output (M18)
);

    // Differential clock buffer
    wire clk_single_ended;

    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("FALSE")
    ) ibufds_clk (
        .O(clk_single_ended),
        .I(clk_p),
        .IB(clk_n)
    );

    // Counter for generating different frequencies
    reg [25:0] counter;

    always @(posedge clk_single_ended) begin
        counter <= counter + 1;
    end

    // LED: 1Hz (toggle every 25M cycles = 0.5s at 50MHz)
    // Period = 1 second
    reg led_out;
    always @(posedge clk_single_ended) begin
        if (counter[24:0] == 25'd25_000_000) begin
            led_out <= ~led_out;
        end
    end
    assign led = led_out;

    // SCL: 10Hz (toggle every 2.5M cycles = 0.05s at 50MHz)
    // Period = 0.1 second = 10Hz
    reg scl_out;
    always @(posedge clk_single_ended) begin
        if (counter[21:0] == 22'd2_500_000) begin
            scl_out <= ~scl_out;
        end
    end
    // Drive SCL as output (normally input, but test mode)
    assign scl = scl_out;

    // SDA: 100Hz (toggle every 250k cycles = 0.005s at 50MHz)
    // Period = 0.01 second = 100Hz
    reg sda_out;
    always @(posedge clk_single_ended) begin
        if (counter[17:0] == 18'd250_000) begin
            sda_out <= ~sda_out;
        end
    end
    // Drive SDA as output (normally bidirectional, but test mode)
    assign sda = sda_out;

endmodule
