# Multi-Target I2C Slave for FPGA

A portable, high-performance I2C slave implementation supporting multiple FPGA vendors: **Lattice ECP5**, **Xilinx Spartan-7**, and **Gowin** (planned).

## Features

- **Multi-page I2C addressing** with automatic increment
- **High-speed operation** up to 400kHz I2C
- **Version information storage** with build metadata
- **Configuration registers** (brightness/contrast control)
- **Vendor-agnostic Verilog RTL** - portable across FPGA families
- **Unified build system** - single Makefile for all targets
- **Open-source toolchain support** - Yosys, NextPNR, Symbiflow

## Project Structure

```
fpga-i2c-slave/
├── rtl/                        # Verilog source files
│   ├── i2c_slave_top.v        # Top-level module
│   ├── version_i2c_slave.v    # I2C slave core
│   └── version_storage.v      # Version data storage
├── include/                    # Header files
│   └── version_config.vh      # Build configuration
├── constraints/                # Pin constraints per target
│   ├── lattice/               # Lattice ECP5 constraints (.lpf)
│   ├── xilinx/                # Xilinx constraints (.xdc)
│   └── gowin/                 # Gowin constraints (.cst)
├── scripts/                    # Build and test scripts
├── build/                      # Build outputs (auto-generated)
└── docs/                       # Documentation
```

## Supported Targets

| Target   | FPGA Device         | Toolchain               | Status |
|----------|---------------------|-------------------------|--------|
| lattice  | ECP5 UM-45K         | Yosys + NextPNR         | ✅ Tested |
| xilinx   | Spartan-7 XC7S50    | Symbiflow or Vivado     | ✅ Ready |
| gowin    | TBD                 | Gowin EDA               | 🚧 Planned |

## Requirements

### Lattice Target
```bash
sudo apt install -y yosys nextpnr-ecp5 fpga-trellis
```

### Xilinx Target (Open-Source)
```bash
# Symbiflow/F4PGA installation (experimental for Spartan-7)
# See: https://github.com/chipsalliance/f4pga
```

### Xilinx Target (Proprietary)
- Xilinx Vivado Design Suite (tested with 2023.2)

### Common Tools
```bash
sudo apt install -y build-essential git i2c-tools
```

## Documentation

For detailed setup and usage instructions, see the [docs/](docs/) directory:

- **[QUICKSTART.md](docs/QUICKSTART.md)** - Quick reference for common tasks
- **[BUILD_SETUP.md](docs/BUILD_SETUP.md)** - Detailed build system setup (WSL2/Linux)
- **[XILINX_SETUP.md](docs/XILINX_SETUP.md)** - Xilinx-specific configuration
- **[MIGRATION_NOTES.md](docs/MIGRATION_NOTES.md)** - Migration guide from original setup

## Quick Start

### Build for Lattice ECP5
```bash
make TARGET=lattice
```

### Build for Xilinx Spartan-7
```bash
make TARGET=xilinx
```

### Clean and Rebuild
```bash
make TARGET=xilinx clean all
```

### Program FPGA
```bash
make TARGET=lattice program
```

## I2C Slave Configuration

- **I2C Address:** 0x50 (7-bit)
- **Clock Frequency:** 50MHz system clock
- **I2C Speed:** Up to 400kHz

### Pin Assignments

#### Lattice ECP5 (UM-45K)
- Clock: U16 (50MHz)
- SCL: B15
- SDA: C15
- LED: A12

#### Xilinx Spartan-7 (XC7S50)
- Clock: *Update in constraints/xilinx/xc7s50.xdc*
- SCL: R15
- SDA: T14
- LED: *Update in constraints/xilinx/xc7s50.xdc*

**Note:** Update clock and LED pin locations in `constraints/xilinx/xc7s50.xdc` based on your board.

## I2C Memory Map

### Page 0: Version Information (Read-Only)
| Address | Description           |
|---------|-----------------------|
| 0x00    | Magic Start (High)    |
| 0x01    | Magic Start (Low)     |
| 0x02    | Version Major         |
| 0x03    | Version Minor         |
| 0x04    | Build Number (High)   |
| 0x05    | Build Number (Low)    |
| 0x06-0x09 | Git Commit Hash     |
| 0x0A-0x0D | Build Timestamp     |
| 0x0E    | Magic End (High)      |
| 0x0F    | Magic End (Low)       |

### Page 1: Configuration Registers (Read/Write)
| Address | Description           | Default |
|---------|-----------------------|---------|
| 0x00    | Brightness Value      | 0x80    |
| 0x01    | Contrast Value        | 0x40    |

## Usage Examples

### Reading Version Information
```bash
# Read first 16 bytes from page 0
sudo i2ctransfer -y 1 w1@0x50 0x00 r16
```

### Writing Configuration
```bash
# Write brightness (0xAA) and contrast (0xBB) to page 1
sudo i2ctransfer -y 1 w4@0x50 0x01 0x00 0xAA 0xBB
```

### Reading Configuration
```bash
# Read brightness and contrast from page 1
sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r2
```

## Testing

Run the comprehensive test suite:
```bash
./scripts/test-suite.sh
```

Read version information:
```bash
./scripts/version_read.sh
```

Debug I2C communication:
```bash
./scripts/i2c_debug_script.sh
```

## Build System Details

The unified Makefile automatically:
1. Updates build timestamp before synthesis
2. Selects appropriate toolchain based on TARGET
3. Creates target-specific build directories
4. Generates bitstream files

### Makefile Targets
```bash
make help                  # Display help information
make TARGET=lattice        # Build for Lattice (default)
make TARGET=xilinx         # Build for Xilinx
make TARGET=xilinx clean   # Clean Xilinx build
make clean-all             # Clean all targets
make show-config           # Display current configuration
```

## Customization

### Change I2C Address
Edit `include/version_config.vh`:
```verilog
`define I2C_SLAVE_ADDRESS 7'h50  // Change to your address
```

### Add More Configuration Registers
1. Add registers in `rtl/version_i2c_slave.v` (lines 139-153)
2. Update memory map in Page 1 section (lines 187-194)

### Port to New FPGA Board
1. Create constraint file in `constraints/<vendor>/`
2. Update pin locations for your board
3. Update Makefile if new device variant needed

## Known Limitations

### Xilinx Target
- **Symbiflow support** for Spartan-7 is experimental
- Some timing constraints may need adjustment for your board
- **Vivado** recommended for production use

### Gowin Target
- Not yet implemented - placeholder structure provided
- Community contributions welcome!

## Troubleshooting

### Lattice Build Fails
- Ensure NextPNR-ECP5 supports `um-45k` device
- Check that all toolchain versions are up-to-date

### Xilinx Clock Pin
- The XDC file has placeholder `XX` for clock and LED pins
- Update `constraints/xilinx/xc7s50.xdc` with your board's actual pins

### I2C Communication Issues
- Verify pull-up resistors on SCL/SDA (typically 4.7kΩ)
- Check I2C bus speed (400kHz maximum)
- Use `i2cdetect -y 1` to verify device responds at 0x50

## Contributing

Contributions welcome! Areas of interest:
- Gowin FPGA support
- Additional configuration registers
- Timing optimization
- Documentation improvements

## License

This project is open-source. Please check individual file headers for specific licensing terms.

## References

- [I2C Specification](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- [Lattice ECP5 Documentation](https://www.latticesemi.com/products/fpgaandcpld/ecp5)
- [Xilinx Spartan-7 Documentation](https://www.xilinx.com/products/silicon-devices/fpga/spartan-7.html)
- [Project X-Ray (Xilinx reverse engineering)](https://github.com/SymbiFlow/prjxray)

## Contact

For questions or issues, please open an issue on the project repository.
