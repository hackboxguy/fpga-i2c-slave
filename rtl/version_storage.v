// version_storage.v - BRAM-based version information storage
`include "version_config.vh"

module version_storage (
    input wire clk,
    input wire [2:0] addr,      // Address for version data (0-7)
    output reg [15:0] data_out  // 16-bit data output
);

    // Version data using combinational logic (yosys-friendly)
    // This will be inferred as BRAM by the synthesis tool
    always @(posedge clk) begin
        case (addr)
            3'd0: data_out <= `VERSION_MAGIC_START;                // Magic start
            3'd1: data_out <= {`VERSION_MAJOR, `VERSION_MINOR};   // Major.Minor
            3'd2: data_out <= `BUILD_NUMBER;                      // Build number
            3'd3: data_out <= `GIT_COMMIT_HASH_HI;               // Git hash upper
            3'd4: data_out <= `GIT_COMMIT_HASH_LO;               // Git hash lower
            3'd5: data_out <= `BUILD_TIMESTAMP_HI;               // Timestamp upper
            3'd6: data_out <= `BUILD_TIMESTAMP_LO;               // Timestamp lower
            3'd7: data_out <= `VERSION_MAGIC_END;                // Magic end
            default: data_out <= 16'h0000;
        endcase
    end
    
endmodule
