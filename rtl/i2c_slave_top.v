// i2c_slave_top_debug.v - Debug version with LED heartbeat
// This version blinks LED to prove FPGA is running

`include "../include/version_config.vh"

module i2c_slave_top (
    input clk,          // 50MHz clock from board
    input scl,          // I2C clock input
    inout sda,          // I2C data (bidirectional)
    output led          // LED output - heartbeat + I2C activity
);

    // Heartbeat counter (blinks LED at ~1Hz to prove FPGA is alive)
    reg [25:0] heartbeat_counter;
    reg heartbeat_led;

    always @(posedge clk) begin
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
        .clk(clk),
        .addr(version_addr),
        .data_out(version_data)
    );

    // I2C slave interface
    wire i2c_activity_led;

    version_i2c_slave i2c_if (
        .clk(clk),
        .scl(scl),
        .sda(sda),
        .version_addr(version_addr),
        .version_data(version_data),
        .led(i2c_activity_led)
    );

    // LED = heartbeat OR I2C activity (will blink continuously, bright during I2C)
    assign led = heartbeat_led | i2c_activity_led;

endmodule
