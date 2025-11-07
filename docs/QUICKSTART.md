# Quick Start Guide - Xilinx Portable Build System

## TL;DR

**WSL2 (Windows Vivado):**
```bash
make TARGET=xilinx
```

**Native Linux:**
```bash
make TARGET=xilinx
```

The build system auto-detects your environment and Vivado installation.

## Custom Vivado Path

**One-time:**
```bash
VIVADO_PATH=/mnt/c/Xilinx/2025.1 make TARGET=xilinx  # WSL2
VIVADO_PATH=/opt/Xilinx/2025.1 make TARGET=xilinx     # Linux
```

**Persistent (add to ~/.bashrc):**
```bash
export VIVADO_PATH=/mnt/c/Xilinx/2025.1  # WSL2
# OR
export VIVADO_PATH=/opt/Xilinx/2025.1     # Linux
```

## What's New

The build system now supports:

- **Auto-detection** of WSL2 vs native Linux
- **Auto-discovery** of Vivado installations (2025.1, 2024.2, 2024.1, 2023.2)
- **Configurable paths** via `VIVADO_PATH` environment variable
- **Unified script** (`build_xilinx.sh`) for both environments
- **Same Makefile** works on both WSL2 and native Linux

## Key Features

### WSL2 Mode
- Detects Windows Vivado at `/mnt/c/Xilinx/*`
- Uses temporary `C:\Temp` directory to avoid UNC path issues
- Invokes Vivado via `cmd.exe`
- Automatically cleans up temp files

### Native Linux Mode
- Detects Linux Vivado at `/opt/Xilinx/*`, `/tools/Xilinx/*`
- Builds directly in project directory
- Invokes Vivado directly

## Output Files

```
build/xilinx/
├── i2c_slave.bit           # FPGA bitstream
├── i2c_slave_synth.dcp     # Synthesis checkpoint
├── i2c_slave_route.dcp     # Routing checkpoint
├── utilization.rpt         # Resource utilization
└── timing_summary.rpt      # Timing analysis
```

## Troubleshooting

**"Vivado not found" error:**
```bash
export VIVADO_PATH=/path/to/vivado/version
make TARGET=xilinx
```

**Permission error:**
```bash
chmod +x scripts/build_xilinx.sh
```

**Clean build:**
```bash
make TARGET=xilinx clean
make TARGET=xilinx
```

## More Information

See [BUILD_SETUP.md](BUILD_SETUP.md) for detailed documentation.
