# Xilinx XC7S50 Setup Guide

## Pin Configuration (UPDATED)

Your Target Board pins have been configured:

| Signal | Pin  | Description |
|--------|------|-------------|
| clk    | C12  | 50MHz Clock (DDR_50M_CLKP) - using single-ended |
| led    | L13  | LED output |
| scl    | R15  | I2C Clock |
| sda    | T14  | I2C Data |

**Note:** The clock is differential (C12/C11), but we're using it as single-ended on C12. If you need differential, see comments in the XDC file.

## Installing Vivado (Required)

### Option 1: Download from Xilinx (Recommended)

1. **Download Vivado:**
   - Visit: https://www.xilinx.com/support/download.html
   - Select: "Vivado ML Edition - 2023.2" (or latest)
   - Choose: "Vivado ML Edition - Linux Self Extracting Web Installer"
   - Create free Xilinx account if needed

2. **Install:**
   ```bash
   chmod +x Xilinx_Unified_*_Lin64.bin
   sudo ./Xilinx_Unified_*_Lin64.bin
   ```

3. **Select Installation Options:**
   - Product: Vivado ML Edition
   - Edition: **Vivado ML Standard** (free, includes Spartan-7)
   - Devices: Check "Spartan-7"
   - Installation directory: `/tools/Xilinx` (recommended)

4. **Add to PATH:**
   Add to your `~/.bashrc`:
   ```bash
   # Xilinx Vivado
   source /tools/Xilinx/Vivado/2023.2/settings64.sh
   ```

   Then reload:
   ```bash
   source ~/.bashrc
   ```

5. **Verify Installation:**
   ```bash
   which vivado
   # Should output: /tools/Xilinx/Vivado/2023.2/bin/vivado
   ```

### Option 2: Use Docker (Alternative)

If you don't want to install Vivado directly:

```bash
# Pull Vivado Docker image (community-maintained)
docker pull ghcr.io/hdl/impl:vivado-2023.2

# Run build in Docker
docker run --rm -v $(pwd):/work ghcr.io/hdl/impl:vivado-2023.2 \
    vivado -mode batch -source scripts/build_vivado.tcl -tclargs build/xilinx i2c_slave_top xc7s50csga324-1
```

## Building for Xilinx

Once Vivado is installed:

```bash
# Clean any previous builds
make clean-all

# Build for Xilinx
make TARGET=xilinx

# Output will be at: build/xilinx/i2c_slave.bit
```

## Programming the FPGA

### Using Vivado Hardware Manager

1. **Open Vivado:**
   ```bash
   vivado
   ```

2. **In Vivado GUI:**
   - Click "Open Hardware Manager"
   - Click "Open Target" → "Auto Connect"
   - Right-click on your device → "Program Device"
   - Select `build/xilinx/i2c_slave.bit`
   - Click "Program"

### Using openFPGALoader (Command Line)

If you have openFPGALoader installed:

```bash
# Install openFPGALoader
sudo apt-get install libftdi1-dev libhidapi-dev
git clone https://github.com/trabucayre/openFPGALoader.git
cd openFPGALoader
mkdir build && cd build
cmake ..
make
sudo make install

# Program the FPGA
openFPGALoader -c ft2232 build/xilinx/i2c_slave.bit

# Or update the Makefile PROG_CMD and use:
make TARGET=xilinx program
```

## Testing

After programming:

```bash
# Detect I2C device at address 0x50
sudo i2cdetect -y 1

# Read version information
sudo i2ctransfer -y 1 w1@0x50 0x00 r16

# Test LED (should blink on I2C activity)
sudo i2ctransfer -y 1 w1@0x50 0x00 r1
```

## Troubleshooting

### "vivado: command not found"
- Make sure you sourced the settings64.sh file
- Check installation path is correct

### Clock Domain Warnings
- Your board has differential clock (C12/C11)
- Current design uses single-ended (C12 only)
- This is fine for 50MHz, but if you see issues, we can switch to differential

### Timing Failures
- Current design is optimized for 50MHz
- If timing fails, we can add IOB register packing
- Check timing reports in `build/xilinx/timing_summary.rpt`

### I2C Not Working
- Verify pull-up resistors on SCL/SDA (4.7kΩ typical)
- Check I2C bus number: `i2cdetect -l`
- Try slower speed: Add `-f` flag to i2ctransfer for 100kHz mode

## Build Output Files

After successful build, you'll find:

```
build/xilinx/
├── i2c_slave.bit          # Programming bitstream
├── i2c_slave_synth.dcp    # Post-synthesis checkpoint
├── i2c_slave_route.dcp    # Post-route checkpoint
├── utilization.rpt        # Resource utilization report
└── timing_summary.rpt     # Timing analysis report
```

## Next Steps

1. **Build the design:**
   ```bash
   make TARGET=xilinx
   ```

2. **Check reports** (if build succeeds):
   ```bash
   cat build/xilinx/utilization.rpt
   cat build/xilinx/timing_summary.rpt
   ```

3. **Program and test:**
   - Use Vivado Hardware Manager or openFPGALoader
   - Test with I2C commands

## Need Help?

- Check [README.md](README.md) for project overview
- Check [QUICKSTART.md](QUICKSTART.md) for common commands
- Vivado docs: https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0010-vivado-design-hub.html
