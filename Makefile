# Multi-Target I2C Slave FPGA Build System
# Supports: Lattice ECP5, Xilinx Spartan-7, Gowin FPGAs
# Usage: make TARGET=<lattice|xilinx|gowin> [all|clean|program]

# ============================================================================
# Target Configuration
# ============================================================================
TARGET ?= lattice
PROJECT = i2c_slave
TOP_MODULE = i2c_slave_top

# Source files (shared across all targets)
RTL_DIR = rtl
INCLUDE_DIR = include
VERILOG_FILES = $(RTL_DIR)/i2c_slave_top.v $(RTL_DIR)/version_storage.v $(RTL_DIR)/version_i2c_slave.v
VERSION_CONFIG = $(INCLUDE_DIR)/version_config.vh

# Build directories
BUILD_DIR = build/$(TARGET)

# Timestamp variables for version tracking
TIMESTAMP_HEX := $(shell printf "0x%08X" $$(date +%s))
TIMESTAMP_HI := $(shell echo $(TIMESTAMP_HEX) | cut -c3-6)
TIMESTAMP_LO := $(shell echo $(TIMESTAMP_HEX) | cut -c7-10)
BUILD_DATE := $(shell date '+%Y-%m-%d %H:%M:%S %Z')

# ============================================================================
# Lattice ECP5 Configuration
# ============================================================================
ifeq ($(TARGET),lattice)
    DEVICE = um-45k
    PACKAGE = CABGA381
    CONSTRAINT_FILE = constraints/lattice/um45k.lpf
    OUTPUT_FILE = $(BUILD_DIR)/$(PROJECT).bit

    SYNTH_CMD = yosys -q -p "verilog_defaults -add -I$(INCLUDE_DIR); read_verilog $(VERILOG_FILES); synth_ecp5 -top $(TOP_MODULE) -json $(BUILD_DIR)/$(PROJECT).json"
    PNR_CMD = nextpnr-ecp5 --quiet --$(DEVICE) --package $(PACKAGE) \
              --json $(BUILD_DIR)/$(PROJECT).json \
              --lpf $(CONSTRAINT_FILE) \
              --textcfg $(BUILD_DIR)/$(PROJECT).config
    PACK_CMD = ecppack --compress $(BUILD_DIR)/$(PROJECT).config $(OUTPUT_FILE)

    # Programming command (update with your specific programmer)
    PROG_CMD = sudo openFPGALoader -c libgpiod --pins=21:20:16:26 $(OUTPUT_FILE)
endif

# ============================================================================
# Xilinx Spartan-7 Configuration (Vivado with WSL2/Native Linux support)
# ============================================================================
ifeq ($(TARGET),xilinx)
    DEVICE = xc7s50csga324-1
    PART = xc7s50csga324-1
    CONSTRAINT_FILE = constraints/xilinx/xc7s50.xdc
    OUTPUT_FILE = $(BUILD_DIR)/$(PROJECT).bit

    # Auto-detect Vivado installation
    # VIVADO_PATH can be set via environment variable or auto-detected
    # Examples:
    #   WSL2: export VIVADO_PATH=/mnt/c/Xilinx/2025.1
    #   Linux: export VIVADO_PATH=/opt/Xilinx/2025.1

    VIVADO_PATH ?= $(shell \
        if [ -d /mnt/c/Xilinx/2025.1 ]; then echo "/mnt/c/Xilinx/2025.1"; \
        elif [ -d /opt/Xilinx/2025.1 ]; then echo "/opt/Xilinx/2025.1"; \
        elif [ -d /tools/Xilinx/2025.1 ]; then echo "/tools/Xilinx/2025.1"; \
        elif [ -d /mnt/c/Xilinx/2024.2 ]; then echo "/mnt/c/Xilinx/2024.2"; \
        elif [ -d /opt/Xilinx/2024.2 ]; then echo "/opt/Xilinx/2024.2"; \
        else echo ""; fi)

    # Detect environment type
    IS_WSL := $(shell grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null && echo "yes" || echo "no")

    # Check if we found Vivado
    ifneq ($(VIVADO_PATH),)
        ifeq ($(IS_WSL),yes)
            $(warning Detected WSL2 environment)
        else
            $(warning Detected native Linux environment)
        endif
        $(warning Using Vivado at: $(VIVADO_PATH))

        # Use unified build script that handles both WSL and native Linux
        SYNTH_CMD = ./scripts/build_xilinx.sh $(BUILD_DIR) $(TOP_MODULE) $(PART) $(VIVADO_PATH)
        PNR_CMD = @echo "PNR included in Vivado flow"
        PACK_CMD = @echo "Bitstream generation included in Vivado flow"
    else
        $(error Vivado not found. Please set VIVADO_PATH environment variable)
        $(error Example: export VIVADO_PATH=/mnt/c/Xilinx/2025.1  # For WSL2)
        $(error Example: export VIVADO_PATH=/opt/Xilinx/2025.1    # For Linux)
    endif

    # Programming command (using openFPGALoader or xc3sprog)
    PROG_CMD = openFPGALoader -c ft2232 $(OUTPUT_FILE)
endif

# ============================================================================
# Gowin Configuration (Placeholder)
# ============================================================================
ifeq ($(TARGET),gowin)
    DEVICE = GW1NR-9
    CONSTRAINT_FILE = constraints/gowin/placeholder.cst
    OUTPUT_FILE = $(BUILD_DIR)/$(PROJECT).fs

    # Gowin toolchain (requires Gowin EDA installed)
    SYNTH_CMD = @echo "Gowin synthesis not yet implemented"
    PNR_CMD = @echo "Gowin P&R not yet implemented"
    PACK_CMD = @echo "Gowin bitstream generation not yet implemented"
    PROG_CMD = @echo "Gowin programming not yet implemented"

    $(warning Gowin target is a placeholder - implementation pending)
endif

# ============================================================================
# Build Targets
# ============================================================================

.PHONY: all clean program help update-timestamp show-config

all: show-config update-timestamp $(OUTPUT_FILE)

show-config:
	@echo "=============================================="
	@echo "Building I2C Slave for: $(TARGET)"
	@echo "Device: $(DEVICE)"
	@echo "Top Module: $(TOP_MODULE)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Timestamp: $(TIMESTAMP_HEX) ($(BUILD_DATE))"
	@echo "=============================================="

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Update version configuration with current timestamp
update-timestamp:
	@echo "Updating build timestamp: $(TIMESTAMP_HEX)"
	@cp $(VERSION_CONFIG) $(VERSION_CONFIG).backup
	@sed -i 's/BUILD_TIMESTAMP_HI.*16'\''h[0-9A-Fa-f]*/BUILD_TIMESTAMP_HI  16'\''h$(TIMESTAMP_HI)/' $(VERSION_CONFIG)
	@sed -i 's/BUILD_TIMESTAMP_LO.*16'\''h[0-9A-Fa-f]*/BUILD_TIMESTAMP_LO  16'\''h$(TIMESTAMP_LO)/' $(VERSION_CONFIG)

# Synthesis
$(BUILD_DIR)/$(PROJECT).json: $(VERILOG_FILES) $(VERSION_CONFIG) | $(BUILD_DIR)
	@echo "Running synthesis for $(TARGET)..."
	$(SYNTH_CMD)

# Place and Route
$(BUILD_DIR)/$(PROJECT).config: $(BUILD_DIR)/$(PROJECT).json $(CONSTRAINT_FILE)
	@echo "Running place and route for $(TARGET)..."
	$(PNR_CMD)

# Bitstream Generation
$(OUTPUT_FILE): $(BUILD_DIR)/$(PROJECT).config
	@echo "Generating bitstream for $(TARGET)..."
	$(PACK_CMD)
	@echo "Build complete: $(OUTPUT_FILE)"

# Programming target
program: $(OUTPUT_FILE)
	@echo "Programming $(TARGET) device..."
	$(PROG_CMD)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts for $(TARGET)..."
	rm -rf $(BUILD_DIR)

clean-all:
	@echo "Cleaning all build artifacts..."
	rm -rf build/

# Help target
help:
	@echo "Multi-Target I2C Slave FPGA Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make TARGET=<target> [options]"
	@echo ""
	@echo "Targets:"
	@echo "  lattice  - Lattice ECP5 UM-45K (default)"
	@echo "  xilinx   - Xilinx Spartan-7 XC7S50"
	@echo "  gowin    - Gowin FPGA (placeholder)"
	@echo ""
	@echo "Options:"
	@echo "  all              - Build bitstream (default)"
	@echo "  clean            - Clean current target build"
	@echo "  clean-all        - Clean all target builds"
	@echo "  program          - Program FPGA device"
	@echo "  update-timestamp - Update build timestamp"
	@echo "  show-config      - Display build configuration"
	@echo ""
	@echo "Examples:"
	@echo "  make TARGET=lattice"
	@echo "  make TARGET=xilinx clean all"
	@echo "  make TARGET=xilinx program"
