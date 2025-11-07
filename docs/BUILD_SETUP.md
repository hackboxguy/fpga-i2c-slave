# Xilinx Build Setup Guide

This document explains how to build the I2C slave for Xilinx Spartan-7 on different platforms.

## Supported Environments

The build system supports:

1. **WSL2** (Windows Subsystem for Linux) with Windows Vivado installed
2. **Native Linux** with Linux Vivado installed

The build system automatically detects your environment and uses the appropriate build strategy.

## Vivado Installation Paths

### Auto-Detection (Recommended)

The Makefile automatically searches for Vivado in common locations:

**WSL2 (Windows Vivado):**
- `/mnt/c/Xilinx/2025.1/`
- `/mnt/c/Xilinx/2024.2/`
- `/opt/Xilinx/2025.1/` (Linux Vivado on WSL2)

**Native Linux:**
- `/opt/Xilinx/2025.1/`
- `/tools/Xilinx/2025.1/`
- `/usr/local/Xilinx/2025.1/`

### Manual Configuration

If Vivado is installed in a non-standard location, set the `VIVADO_PATH` environment variable:

**For WSL2 with Windows Vivado:**
```bash
export VIVADO_PATH=/mnt/c/Xilinx/2025.1
make TARGET=xilinx
```

**For Native Linux:**
```bash
export VIVADO_PATH=/opt/Xilinx/2025.1
make TARGET=xilinx
```

**Persistent Configuration (.bashrc or .zshrc):**
```bash
# Add to ~/.bashrc or ~/.zshrc
export VIVADO_PATH=/mnt/c/Xilinx/2025.1  # WSL2
# OR
export VIVADO_PATH=/opt/Xilinx/2025.1     # Linux
```

## Build Commands

### Basic Build
```bash
make TARGET=xilinx
```

### Clean Build
```bash
make TARGET=xilinx clean
make TARGET=xilinx
```

### One-time Vivado Path Override
```bash
VIVADO_PATH=/custom/path/to/vivado make TARGET=xilinx
```

## How It Works

### WSL2 with Windows Vivado

When building on WSL2 with Windows Vivado:

1. Script detects WSL2 environment
2. Creates temporary build directory at `C:\Temp\fpga_i2c_build_<PID>`
3. Copies source files to avoid UNC path issues
4. Generates TCL script with Windows-style paths
5. Invokes Vivado via `cmd.exe`
6. Copies bitstream back to project directory
7. Cleans up temporary files

### Native Linux with Linux Vivado

When building on native Linux:

1. Script detects native Linux environment
2. Builds directly in project directory
3. Generates TCL script with Linux paths
4. Invokes Vivado directly
5. Outputs bitstream to build directory

## Troubleshooting

### Vivado Not Found

**Error:**
```
Vivado not found. Please set VIVADO_PATH environment variable
```

**Solution:**
```bash
# Check where Vivado is installed
ls /mnt/c/Xilinx/    # WSL2
ls /opt/Xilinx/      # Linux

# Set VIVADO_PATH to the version directory
export VIVADO_PATH=/mnt/c/Xilinx/2025.1
```

### Build Fails on WSL2

If the build fails on WSL2, check:

1. Vivado path is correct
2. Windows Vivado is accessible from WSL
3. `C:\Temp` directory exists and is writable

**Manual test:**
```bash
# Test Vivado access
cmd.exe /c "C:\\Xilinx\\2025.1\\Vivado\\bin\\vivado.bat -version"
```

### Permission Issues

If you get permission errors:

```bash
# Make build script executable
chmod +x scripts/build_xilinx.sh
```

## Build Output

Successful build creates:
- `build/xilinx/i2c_slave.bit` - FPGA bitstream
- `build/xilinx/i2c_slave_synth.dcp` - Synthesis checkpoint
- `build/xilinx/i2c_slave_route.dcp` - Routing checkpoint
- `build/xilinx/utilization.rpt` - Resource utilization report
- `build/xilinx/timing_summary.rpt` - Timing analysis report

## Examples

### WSL2 Example
```bash
# Terminal on WSL2 Ubuntu
cd /home/username/fpga-i2c-slave

# Auto-detect Vivado
make TARGET=xilinx

# Or specify path
export VIVADO_PATH=/mnt/c/Xilinx/2025.1
make TARGET=xilinx
```

### Native Linux Example
```bash
# Terminal on Ubuntu/Debian
cd ~/fpga-i2c-slave

# Auto-detect Vivado
make TARGET=xilinx

# Or specify path
export VIVADO_PATH=/opt/Xilinx/2025.1
make TARGET=xilinx
```

### Switching Between Environments

The same Makefile and scripts work on both WSL2 and native Linux:

```bash
# Clone repo on both systems
git clone <repo-url> fpga-i2c-slave

# On WSL2 laptop
cd fpga-i2c-slave
make TARGET=xilinx  # Uses Windows Vivado

# On Linux workstation
cd fpga-i2c-slave
make TARGET=xilinx  # Uses Linux Vivado
```

## Advanced Usage

### Custom Vivado Version

```bash
# Use specific version
export VIVADO_PATH=/mnt/c/Xilinx/2024.2
make TARGET=xilinx
```

### Build with Different Part

Edit `Makefile` line 52:
```makefile
PART = xc7s50csga324-1  # Change to your part number
```

### Verbose Build Output

```bash
make TARGET=xilinx 2>&1 | tee build.log
```

## Migration Notes

### From Old build_xilinx_wsl.sh

The new unified script (`build_xilinx.sh`) replaces `build_xilinx_wsl.sh` and adds:

- Native Linux support
- Auto-detection of environment
- Configurable Vivado paths
- Multi-version Vivado support

Old script is preserved for reference but no longer used.
