// i2c_slave_top_diffclk.v - Version with differential clock input
// Uses IBUFDS to convert differential LVDS clock (C12/C11) to single-ended

`include "../include/version_config.vh"

module i2c_slave_top (
    input clk_p,        // 50MHz differential clock positive (C12)
    input clk_n,        // 50MHz differential clock negative (C11)
    input scl,          // I2C clock input
    inout sda,          // I2C data (bidirectional)
    output led          // LED output - heartbeat + I2C activity
);

    // Differential clock buffer to convert LVDS to single-ended
    wire clk_single_ended;

    IBUFDS #(
        .DIFF_TERM("FALSE"),    // Disable internal termination (external termination present)
        .IBUF_LOW_PWR("FALSE")  // Use high performance mode
    ) ibufds_clk (
        .O(clk_single_ended),   // Single-ended output clock
        .I(clk_p),              // Differential positive input (C12)
        .IB(clk_n)              // Differential negative input (C11)
    );

    // Heartbeat counter (blinks LED at ~1Hz to prove FPGA is alive)
    reg [25:0] heartbeat_counter;
    reg heartbeat_led;

    always @(posedge clk_single_ended) begin
        heartbeat_counter <= heartbeat_counter + 1;
        if (heartbeat_counter == 26'd50_000_000) begin  // 1 second at 50MHz
            heartbeat_counter <= 0;
            heartbeat_led <= ~heartbeat_led;
        end
    end

    // Version storage interface
    wire [2:0] version_addr;
    wire [16:0] version_data;

    version_storage ver_storage (
        .clk(clk_single_ended),
        .addr(version_addr),
        .data_out(version_data)
    );

    // I2C slave interface
    wire i2c_activity_led;

    version_i2c_slave i2c_if (
        .clk(clk_single_ended),
        .scl(scl),
        .sda(sda),
        .version_addr(version_addr),
        .version_data(version_data),
        .led(i2c_activity_led)
    );

    // LED = heartbeat OR I2C activity (will blink continuously, bright during I2C)
    assign led = heartbeat_led | i2c_activity_led;

endmodule
