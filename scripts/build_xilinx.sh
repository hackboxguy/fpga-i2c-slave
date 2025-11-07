#!/bin/bash
# Unified Xilinx build script for both WSL2 (Windows Vivado) and native Linux
# Usage: ./build_xilinx.sh <build_dir> <top_module> <part> [vivado_path]

BUILD_DIR=$1
TOP_MODULE=$2
PART=$3
VIVADO_PATH=${4:-""}  # Optional Vivado path override

PROJECT_ROOT=$(pwd)

# Create build directory
mkdir -p "$BUILD_DIR"

echo "=========================================="
echo "Xilinx Unified Build Script"
echo "Project Root: $PROJECT_ROOT"
echo "Build Directory: $BUILD_DIR"
echo "Top Module: $TOP_MODULE"
echo "Part: $PART"
echo "=========================================="

# ============================================================================
# Environment Detection
# ============================================================================

# Detect if we're running on WSL
IS_WSL="no"
if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
    IS_WSL="yes"
    echo "Detected: WSL2 environment"
else
    echo "Detected: Native Linux environment"
fi

# ============================================================================
# Vivado Path Detection
# ============================================================================

VIVADO_BIN=""

if [ -n "$VIVADO_PATH" ]; then
    # User provided explicit path
    echo "Using user-specified Vivado path: $VIVADO_PATH"
    if [ "$IS_WSL" = "yes" ] && [[ "$VIVADO_PATH" == /mnt/c/* ]]; then
        # WSL with Windows Vivado path
        VIVADO_BIN="${VIVADO_PATH}/Vivado/bin/vivado.bat"
    else
        # Native Linux or WSL with Linux Vivado
        VIVADO_BIN="${VIVADO_PATH}/Vivado/bin/vivado"
    fi
else
    # Auto-detect Vivado installation
    echo "Auto-detecting Vivado installation..."

    if [ "$IS_WSL" = "yes" ]; then
        # Try Windows Vivado first on WSL
        for VERSION in 2025.1 2024.2 2024.1 2023.2; do
            if [ -f "/mnt/c/Xilinx/${VERSION}/Vivado/bin/vivado.bat" ]; then
                VIVADO_PATH="/mnt/c/Xilinx/${VERSION}"
                VIVADO_BIN="${VIVADO_PATH}/Vivado/bin/vivado.bat"
                echo "Found Windows Vivado ${VERSION} via WSL"
                break
            fi
        done

        # Fall back to Linux Vivado on WSL if Windows version not found
        if [ -z "$VIVADO_BIN" ]; then
            for VERSION in 2025.1 2024.2 2024.1 2023.2; do
                if [ -f "/opt/Xilinx/${VERSION}/Vivado/bin/vivado" ]; then
                    VIVADO_PATH="/opt/Xilinx/${VERSION}"
                    VIVADO_BIN="${VIVADO_PATH}/Vivado/bin/vivado"
                    echo "Found Linux Vivado ${VERSION} on WSL"
                    break
                fi
            done
        fi
    else
        # Native Linux - check standard installation paths
        for VERSION in 2025.1 2024.2 2024.1 2023.2; do
            for BASE in /opt/Xilinx /tools/Xilinx /usr/local/Xilinx; do
                if [ -f "${BASE}/${VERSION}/Vivado/bin/vivado" ]; then
                    VIVADO_PATH="${BASE}/${VERSION}"
                    VIVADO_BIN="${VIVADO_PATH}/Vivado/bin/vivado"
                    echo "Found Vivado ${VERSION} at ${BASE}"
                    break 2
                fi
            done
        done
    fi
fi

# Verify Vivado was found
if [ -z "$VIVADO_BIN" ] || [ ! -f "$VIVADO_BIN" ]; then
    echo "=========================================="
    echo "ERROR: Vivado not found!"
    echo "Searched paths:"
    if [ "$IS_WSL" = "yes" ]; then
        echo "  - /mnt/c/Xilinx/*/Vivado/bin/vivado.bat"
        echo "  - /opt/Xilinx/*/Vivado/bin/vivado"
    else
        echo "  - /opt/Xilinx/*/Vivado/bin/vivado"
        echo "  - /tools/Xilinx/*/Vivado/bin/vivado"
        echo "  - /usr/local/Xilinx/*/Vivado/bin/vivado"
    fi
    echo ""
    echo "Please specify VIVADO_PATH environment variable"
    echo "Example: export VIVADO_PATH=/mnt/c/Xilinx/2025.1"
    echo "=========================================="
    exit 1
fi

echo "Using Vivado: $VIVADO_BIN"

# ============================================================================
# Build Strategy Selection
# ============================================================================

USE_TEMP_DIR="no"

if [ "$IS_WSL" = "yes" ] && [[ "$VIVADO_BIN" == *".bat" ]]; then
    # WSL with Windows Vivado - use temp directory to avoid UNC path issues
    USE_TEMP_DIR="yes"
    echo "Build strategy: Windows Vivado via WSL (using C:\\Temp)"

    # Convert Windows path for cmd.exe
    WIN_VIVADO_BIN=$(echo "$VIVADO_BIN" | sed 's|/mnt/\([a-z]\)/|\U\1:/|' | sed 's|/|\\|g')

    BUILD_PID=$$
    WIN_BUILD_DIR="C:\\Temp\\fpga_i2c_build_${BUILD_PID}"
    WSL_WIN_BUILD_DIR="/mnt/c/Temp/fpga_i2c_build_${BUILD_PID}"
else
    # Native Linux or WSL with Linux Vivado - can use project directory directly
    echo "Build strategy: Native Linux Vivado (in-place build)"
    USE_TEMP_DIR="no"
fi

# ============================================================================
# Build Execution: Windows Vivado via WSL
# ============================================================================

if [ "$USE_TEMP_DIR" = "yes" ]; then
    echo "Creating temporary Windows build directory..."
    mkdir -p "$WSL_WIN_BUILD_DIR"

    # Copy source files to Windows temp directory
    echo "Copying source files..."
    cp -r rtl "$WSL_WIN_BUILD_DIR/"
    cp -r include "$WSL_WIN_BUILD_DIR/"
    cp -r constraints "$WSL_WIN_BUILD_DIR/"
    mkdir -p "$WSL_WIN_BUILD_DIR/output"

    # Create TCL build script in Windows temp directory
    cat > "$WSL_WIN_BUILD_DIR/build.tcl" <<EOFTCL
# Vivado TCL Build Script for I2C Slave (WSL version)
# Auto-generated by build_xilinx.sh

set work_dir "C:/Temp/fpga_i2c_build_${BUILD_PID}"
set output_dir "\$work_dir/output"
set top_module "$TOP_MODULE"
set part "$PART"

puts "=========================================="
puts "Vivado Build Script for I2C Slave"
puts "Work Directory: \$work_dir"
puts "Output Directory: \$output_dir"
puts "Top Module: \$top_module"
puts "Part: \$part"
puts "=========================================="

# Create project in memory (non-project mode for scripting)
set project_name "i2c_slave"
create_project -in_memory -part \$part

# Add source files
cd \$work_dir
read_verilog -sv rtl/i2c_slave_top_diffclk.v
read_verilog -sv rtl/version_storage.v
read_verilog -sv rtl/version_i2c_slave.v
read_xdc constraints/xilinx/xc7s50.xdc

# Set include directories
set_property include_dirs [list "\$work_dir/include"] [current_fileset]

# Set top module
set_property top \$top_module [current_fileset]

# Run synthesis
puts "Running synthesis..."
synth_design -top \$top_module -part \$part -flatten_hierarchy rebuilt

# Write checkpoint
write_checkpoint -force "\$output_dir/\${project_name}_synth.dcp"

# Run implementation
puts "Running optimization..."
opt_design

puts "Running placement..."
place_design

puts "Running routing..."
route_design

# Write checkpoint
write_checkpoint -force "\$output_dir/\${project_name}_route.dcp"

# Generate reports
report_utilization -file "\$output_dir/utilization.rpt"
report_timing_summary -file "\$output_dir/timing_summary.rpt"

# Generate bitstream
puts "Generating bitstream..."
write_bitstream -force "\$output_dir/\${project_name}.bit"

puts "Build complete: \$output_dir/\${project_name}.bit"
puts "=========================================="
EOFTCL

    # Run Vivado from Windows temp directory
    echo "Launching Vivado..."
    cd "$WSL_WIN_BUILD_DIR"
    cmd.exe /c "cd $WIN_BUILD_DIR && $WIN_VIVADO_BIN -mode batch -source build.tcl"

    EXIT_CODE=$?

    # Copy results back to WSL
    if [ $EXIT_CODE -eq 0 ]; then
        echo "=========================================="
        echo "Build completed successfully!"
        echo "Copying results back to project..."
        cp -r "$WSL_WIN_BUILD_DIR/output/"* "$PROJECT_ROOT/$BUILD_DIR/"
        echo "Bitstream: $BUILD_DIR/i2c_slave.bit"
        echo "=========================================="

        # Cleanup
        echo "Cleaning up temporary files..."
        rm -rf "$WSL_WIN_BUILD_DIR"
    else
        echo "=========================================="
        echo "Build failed with exit code: $EXIT_CODE"
        echo "Temporary build directory preserved at: $WSL_WIN_BUILD_DIR"
        echo "=========================================="
        exit $EXIT_CODE
    fi

# ============================================================================
# Build Execution: Native Linux Vivado
# ============================================================================

else
    # Create output directory in build dir
    mkdir -p "$BUILD_DIR"

    # Create TCL build script
    cat > "$BUILD_DIR/build.tcl" <<EOFTCL
# Vivado TCL Build Script for I2C Slave (Native Linux)
# Auto-generated by build_xilinx.sh

set project_root "$PROJECT_ROOT"
set output_dir "$PROJECT_ROOT/$BUILD_DIR"
set top_module "$TOP_MODULE"
set part "$PART"

puts "=========================================="
puts "Vivado Build Script for I2C Slave"
puts "Project Root: \$project_root"
puts "Output Directory: \$output_dir"
puts "Top Module: \$top_module"
puts "Part: \$part"
puts "=========================================="

# Create project in memory (non-project mode for scripting)
set project_name "i2c_slave"
create_project -in_memory -part \$part

# Add source files
cd \$project_root
read_verilog -sv rtl/i2c_slave_top_diffclk.v
read_verilog -sv rtl/version_storage.v
read_verilog -sv rtl/version_i2c_slave.v
read_xdc constraints/xilinx/xc7s50.xdc

# Set include directories
set_property include_dirs [list "\$project_root/include"] [current_fileset]

# Set top module
set_property top \$top_module [current_fileset]

# Run synthesis
puts "Running synthesis..."
synth_design -top \$top_module -part \$part -flatten_hierarchy rebuilt

# Write checkpoint
write_checkpoint -force "\$output_dir/\${project_name}_synth.dcp"

# Run implementation
puts "Running optimization..."
opt_design

puts "Running placement..."
place_design

puts "Running routing..."
route_design

# Write checkpoint
write_checkpoint -force "\$output_dir/\${project_name}_route.dcp"

# Generate reports
report_utilization -file "\$output_dir/utilization.rpt"
report_timing_summary -file "\$output_dir/timing_summary.rpt"

# Generate bitstream
puts "Generating bitstream..."
write_bitstream -force "\$output_dir/\${project_name}.bit"

puts "Build complete: \$output_dir/\${project_name}.bit"
puts "=========================================="
EOFTCL

    # Run Vivado
    echo "Launching Vivado..."
    "$VIVADO_BIN" -mode batch -source "$BUILD_DIR/build.tcl"

    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "=========================================="
        echo "Build completed successfully!"
        echo "Bitstream: $BUILD_DIR/i2c_slave.bit"
        echo "=========================================="
    else
        echo "=========================================="
        echo "Build failed with exit code: $EXIT_CODE"
        echo "Build directory: $BUILD_DIR"
        echo "=========================================="
        exit $EXIT_CODE
    fi
fi
