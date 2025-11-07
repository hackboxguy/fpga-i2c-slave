// version_i2c_slave.v - High-speed optimized I2C slave with multi-page support
`include "version_config.vh"

module version_i2c_slave (
    input wire clk,
    inout wire sda,
    input wire scl,

    // Version data interface
    output reg [2:0] version_addr,
    input wire [15:0] version_data,

    // Status output
    output reg led,
    
    // Configuration outputs
    output reg [7:0] brightness_value,
    output reg [7:0] contrast_value
);

    // Power-on reset generation
    reg [5:0] reset_counter = 6'b000000;
    wire rst_n;

    always @(posedge clk) begin
        if (reset_counter != 6'b111111)
            reset_counter <= reset_counter + 1'b1;
    end

    assign rst_n = (reset_counter == 6'b111111);

    // I2C slave address (7-bit)
    parameter SLAVE_ADDR = `I2C_SLAVE_ADDRESS;

    // High-speed optimizations:
    // 1. Reduced synchronizer stages for lower latency
    // 2. Separate sync for SCL and SDA since SCL is more critical
    reg [1:0] scl_sync;
    reg [1:0] sda_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
        end else begin
            scl_sync <= {scl_sync[0], scl};
            sda_sync <= {sda_sync[0], sda};
        end
    end

    wire scl_clean = scl_sync[1];
    wire sda_clean = sda_sync[1];

    // Edge detection with glitch filtering
    reg scl_prev, sda_prev;
    reg scl_prev2, sda_prev2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_prev <= 1'b1;
            sda_prev <= 1'b1;
            scl_prev2 <= 1'b1;
            sda_prev2 <= 1'b1;
        end else begin
            scl_prev <= scl_clean;
            sda_prev <= sda_clean;
            scl_prev2 <= scl_prev;
            sda_prev2 <= sda_prev;
        end
    end

    // Stable edge detection - requires two consecutive samples
    wire scl_posedge = scl_clean & scl_prev & ~scl_prev2;
    wire scl_negedge = ~scl_clean & ~scl_prev & scl_prev2;
    wire sda_negedge = ~sda_clean & sda_prev & scl_clean & scl_prev;  // SDA falls while SCL high
    wire sda_posedge = sda_clean & ~sda_prev & scl_clean & scl_prev;  // SDA rises while SCL high

    // I2C condition detection
    wire start_condition = sda_negedge & scl_clean & scl_prev;
    wire stop_condition = sda_posedge & scl_clean & scl_prev;

    // Extended timeout for high-speed operation
    reg [19:0] scl_timeout;
    wire timeout = (scl_timeout == 20'hFFFFF);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_timeout <= 20'd0;
        end else if (scl_posedge || scl_negedge || start_condition || stop_condition) begin
            scl_timeout <= 20'd0;
        end else if (state != IDLE && state != WAIT_IDLE) begin
            scl_timeout <= scl_timeout + 1'b1;
        end
    end

    // State machine with additional states for robustness
    parameter IDLE = 4'd0;
    parameter START_DETECTED = 4'd1;
    parameter ADDRESS = 4'd2;
    parameter ADDR_ACK = 4'd3;
    parameter WRITE_DATA = 4'd4;
    parameter WRITE_ACK = 4'd5;
    parameter READ_DATA = 4'd6;
    parameter READ_ACK = 4'd7;
    parameter WAIT_IDLE = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] bit_counter;
    reg [7:0] address_byte;
    reg [7:0] data_byte;
    reg [7:0] register_addr;
    reg [7:0] page_addr;
    reg [2:0] write_byte_count;
    reg is_read;
    reg address_phase;
    reg data_write_phase;

    // SDA control with registered output for better timing
    reg sda_out;
    reg sda_drive;
    reg sda_out_reg;
    reg sda_drive_reg;
    
    // Pipeline SDA control for high-speed operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_out_reg <= 1'b1;
            sda_drive_reg <= 1'b0;
        end else begin
            sda_out_reg <= sda_out;
            sda_drive_reg <= sda_drive;
        end
    end
    
    assign sda = sda_drive_reg ? sda_out_reg : 1'bz;

    // Configuration registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brightness_value <= 8'h80;  // Default brightness
            contrast_value <= 8'h40;    // Default contrast
        end else if (data_write_phase && state == WRITE_ACK && scl_negedge && !address_phase) begin
            // Write to configuration registers
            if (page_addr == 8'h01) begin
                case (register_addr)
                    8'h00: brightness_value <= data_byte;
                    8'h01: contrast_value <= data_byte;
                    default: ; // Ignore writes to other addresses
                endcase
            end
        end
    end

    // Data selection with page support
    reg [7:0] current_read_data;

    always @(*) begin
        // Default values
        version_addr = 3'd0;
        current_read_data = 8'hFF;
        
        case (page_addr)
            8'h00: begin
                // Page 0: Version information (read-only)
                // Handle wrap-around by masking to 4 bits
                case (register_addr[3:0])
                    4'h0: begin version_addr = 3'd0; current_read_data = version_data[15:8]; end
                    4'h1: begin version_addr = 3'd0; current_read_data = version_data[7:0]; end
                    4'h2: begin version_addr = 3'd1; current_read_data = version_data[15:8]; end
                    4'h3: begin version_addr = 3'd1; current_read_data = version_data[7:0]; end
                    4'h4: begin version_addr = 3'd2; current_read_data = version_data[15:8]; end
                    4'h5: begin version_addr = 3'd2; current_read_data = version_data[7:0]; end
                    4'h6: begin version_addr = 3'd3; current_read_data = version_data[15:8]; end
                    4'h7: begin version_addr = 3'd3; current_read_data = version_data[7:0]; end
                    4'h8: begin version_addr = 3'd4; current_read_data = version_data[15:8]; end
                    4'h9: begin version_addr = 3'd4; current_read_data = version_data[7:0]; end
                    4'hA: begin version_addr = 3'd5; current_read_data = version_data[15:8]; end
                    4'hB: begin version_addr = 3'd5; current_read_data = version_data[7:0]; end
                    4'hC: begin version_addr = 3'd6; current_read_data = version_data[15:8]; end
                    4'hD: begin version_addr = 3'd6; current_read_data = version_data[7:0]; end
                    4'hE: begin version_addr = 3'd7; current_read_data = version_data[15:8]; end
                    4'hF: begin version_addr = 3'd7; current_read_data = version_data[7:0]; end
                endcase
            end
            
            8'h01: begin
                // Page 1: Configuration registers (read/write)
                case (register_addr)
                    8'h00: current_read_data = brightness_value;
                    8'h01: current_read_data = contrast_value;
                    default: current_read_data = 8'hFF;
                endcase
            end
            
            default: begin
                // All other pages return 0xFF
                current_read_data = 8'hFF;
            end
        endcase
    end

    // High-speed optimized state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_counter <= 4'd0;
            address_byte <= 8'd0;
            data_byte <= 8'd0;
            register_addr <= 8'h00;
            page_addr <= 8'h00;
            write_byte_count <= 3'd0;
            is_read <= 1'b0;
            address_phase <= 1'b1;
            data_write_phase <= 1'b0;
            sda_out <= 1'b1;
            sda_drive <= 1'b0;
            led <= 1'b0;
        end else if (timeout) begin
            state <= WAIT_IDLE;
            bit_counter <= 4'd0;
            sda_drive <= 1'b0;
            led <= 1'b0;
            address_phase <= 1'b1;
            data_write_phase <= 1'b0;
        end else if (stop_condition) begin
            // Global stop condition handler
            state <= WAIT_IDLE;
            bit_counter <= 4'd0;
            sda_drive <= 1'b0;
            led <= 1'b0;
            write_byte_count <= 3'd0;
            address_phase <= 1'b1;
            data_write_phase <= 1'b0;
        end else if (start_condition) begin
            // Global start condition handler
            if (state == IDLE || state == WAIT_IDLE) begin
                state <= START_DETECTED;
                write_byte_count <= 3'd0;
                address_phase <= 1'b1;
                data_write_phase <= 1'b0;
            end else begin
                // Repeated start
                state <= START_DETECTED;
                // Preserve write_byte_count and addresses
                address_phase <= (write_byte_count < 3'd2) ? 1'b1 : 1'b0;
                data_write_phase <= (write_byte_count >= 3'd2) ? 1'b1 : 1'b0;
            end
            address_byte <= 8'd0;
            bit_counter <= 4'd0;
            sda_drive <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    sda_drive <= 1'b0;
                    led <= 1'b0;
                    bit_counter <= 4'd0;
                    data_write_phase <= 1'b0;
                end

                WAIT_IDLE: begin
                    // Wait state to ensure clean transitions
                    sda_drive <= 1'b0;
                    if (!start_condition && !stop_condition) begin
                        state <= IDLE;
                    end
                end

                START_DETECTED: begin
                    // Brief pause after start detection for stability
                    state <= ADDRESS;
                    sda_drive <= 1'b0;
                end

                ADDRESS: begin
                    sda_drive <= 1'b0;
                    if (scl_posedge) begin
                        address_byte <= {address_byte[6:0], sda_clean};
                        bit_counter <= bit_counter + 1'b1;
                        
                        if (bit_counter == 4'd7) begin
                            // Pre-calculate next state for faster response
                            next_state <= ADDR_ACK;
                        end
                    end
                    
                    if (bit_counter == 4'd8 && scl_negedge) begin
                        state <= ADDR_ACK;
                        bit_counter <= 4'd0;
                    end
                end

                ADDR_ACK: begin
                    if (address_byte[7:1] == SLAVE_ADDR) begin
                        sda_drive <= 1'b1;
                        sda_out <= 1'b0;  // ACK
                        led <= 1'b1;
                        is_read <= address_byte[0];
                        
                        if (scl_negedge) begin
                            bit_counter <= 4'd0;
                            if (address_byte[0]) begin
                                // Read operation
                                state <= READ_DATA;
                                data_byte <= current_read_data;
                                address_phase <= 1'b0;
                                data_write_phase <= 1'b0;
                            end else begin
                                // Write operation
                                state <= WRITE_DATA;
                                data_byte <= 8'h00;
                                // Set phase based on byte count
                                if (write_byte_count < 3'd2) begin
                                    address_phase <= 1'b1;
                                    data_write_phase <= 1'b0;
                                end else begin
                                    address_phase <= 1'b0;
                                    data_write_phase <= 1'b1;
                                end
                            end
                        end
                    end else begin
                        // NACK - wrong address
                        sda_drive <= 1'b0;
                        if (scl_negedge) begin
                            state <= WAIT_IDLE;
                        end
                    end
                end

                WRITE_DATA: begin
                    sda_drive <= 1'b0;
                    if (scl_posedge) begin
                        data_byte <= {data_byte[6:0], sda_clean};
                        bit_counter <= bit_counter + 1'b1;
                        
                        if (bit_counter == 4'd7) begin
                            // Pre-calculate for faster ACK
                            next_state <= WRITE_ACK;
                        end
                    end
                    
                    if (bit_counter == 4'd8 && scl_negedge) begin
                        state <= WRITE_ACK;
                        bit_counter <= 4'd0;
                    end
                end

                WRITE_ACK: begin
                    sda_drive <= 1'b1;
                    sda_out <= 1'b0;  // Always ACK
                    
                    if (scl_negedge) begin
                        // Process the received byte
                        if (address_phase && write_byte_count == 3'd0) begin
                            // First address byte
                            register_addr <= data_byte;
                            page_addr <= 8'h00;  // Default to page 0 for single-byte
                            write_byte_count <= 3'd1;
                        end else if (address_phase && write_byte_count == 3'd1) begin
                            // Second address byte (two-byte addressing)
                            page_addr <= register_addr;  // First byte becomes page
                            register_addr <= data_byte;   // Second byte becomes register
                            write_byte_count <= 3'd2;
                            address_phase <= 1'b0;
                            data_write_phase <= 1'b1;
                        end else if (data_write_phase && !address_phase) begin
                            // Data write phase - auto-increment after write
                            register_addr <= register_addr + 1'b1;
                            write_byte_count <= write_byte_count + 1'b1;
                        end
                        
                        // Continue to receive more bytes
                        state <= WRITE_DATA;
                        bit_counter <= 4'd0;
                        data_byte <= 8'h00;
                    end
                end

                READ_DATA: begin
                    sda_drive <= 1'b1;

                    if (bit_counter == 4'd0) begin
                        // Load fresh data at start of byte
                        data_byte <= current_read_data;
                        sda_out <= current_read_data[7];
                    end else if (scl_negedge && bit_counter < 4'd8) begin
                        // Shift out next bit
                        sda_out <= data_byte[7-bit_counter];
                    end

                    if (scl_posedge && bit_counter < 4'd8) begin
                        bit_counter <= bit_counter + 1'b1;
                        
                        if (bit_counter == 4'd7) begin
                            // Prepare for ACK phase
                            next_state <= READ_ACK;
                        end
                    end

                    if (bit_counter == 4'd8 && scl_negedge) begin
                        sda_drive <= 1'b0;  // Release for ACK
                        state <= READ_ACK;
                        bit_counter <= 4'd0;
                    end
                end

                READ_ACK: begin
                    sda_drive <= 1'b0;
                    
                    if (scl_posedge) begin
                        // Sample ACK/NACK on positive edge
                        if (sda_clean == 1'b0) begin
                            // ACK - prepare next byte
                            next_state <= READ_DATA;
                        end else begin
                            // NACK - prepare to stop
                            next_state <= WAIT_IDLE;
                        end
                    end
                    
                    if (scl_negedge) begin
                        if (next_state == READ_DATA) begin
                            // Master ACK - continue reading
                            if (page_addr == 8'h00) begin
                                // Page 0: wrap at 16 bytes
                                if (register_addr == 8'h0F) begin
                                    register_addr <= 8'h00;
                                end else begin
                                    register_addr <= register_addr + 1'b1;
                                end
                            end else begin
                                // Other pages: simple increment
                                register_addr <= register_addr + 1'b1;
                            end
                            state <= READ_DATA;
                            bit_counter <= 4'd0;
                        end else begin
                            // Master NACK - stop reading
                            state <= WAIT_IDLE;
                        end
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
