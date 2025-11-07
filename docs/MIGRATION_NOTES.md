# Migration Notes - Project Reorganization

## What Changed

This project has been reorganized from a single-target Lattice design to a **multi-target** structure supporting:
- ✅ Lattice ECP5 (existing, tested)
- ✅ Xilinx Spartan-7 (new, ready to build)
- 🚧 Gowin FPGAs (placeholder for future)

## File Structure Changes

### Old Structure
```
fpga-i2c-slave/
├── Makefile                  (Lattice-specific)
├── blink.v                   (top module)
├── version_i2c_slave.v
├── version_storage.v
├── version_config.vh
├── version.lpf              (Lattice constraints)
└── *.sh                     (test scripts)
```

### New Structure
```
fpga-i2c-slave/
├── Makefile                 (Unified, multi-target)
├── README.md                (Comprehensive docs)
├── QUICKSTART.md            (Quick reference)
├── rtl/                     (Verilog sources)
│   ├── i2c_slave_top.v     (renamed from blink.v)
│   ├── version_i2c_slave.v
│   └── version_storage.v
├── include/                 (Header files)
│   └── version_config.vh
├── constraints/             (Target-specific pins)
│   ├── lattice/
│   │   └── um45k.lpf
│   ├── xilinx/
│   │   └── xc7s50.xdc      (NEW)
│   └── gowin/
│       └── placeholder.cst  (NEW)
├── scripts/                 (Build & test scripts)
│   ├── build_vivado.tcl    (NEW - Vivado automation)
│   ├── test-suite.sh
│   ├── version_read.sh
│   └── i2c_debug_script.sh
└── build/                   (Build outputs, gitignored)
    ├── lattice/
    ├── xilinx/
    └── gowin/
```

## Key Changes

### 1. Top Module Renamed
- **Old:** `blink`
- **New:** `i2c_slave_top`
- **Why:** More descriptive for a reusable I2C slave IP

### 2. Unified Build System
**Old:**
```bash
make              # Always builds for Lattice
```

**New:**
```bash
make TARGET=lattice    # Build for Lattice (default)
make TARGET=xilinx     # Build for Xilinx
make TARGET=gowin      # Build for Gowin (placeholder)
```

### 3. Constraint Files
- **Lattice:** `constraints/lattice/um45k.lpf` (same content as before)
- **Xilinx:** `constraints/xilinx/xc7s50.xdc` (NEW)
  - SCL → R15 (as specified)
  - SDA → T14 (as specified)
  - Clock and LED pins need to be updated for your board

### 4. Build Outputs
All build artifacts now go to `build/<target>/` instead of the root directory.

## For Existing Users

### If You Were Using Lattice
Everything still works the same way:
```bash
make              # Still builds for Lattice by default
make program      # Still programs your board
```

### Xilinx Users - Required Setup

1. **Update Pin Constraints**
   Edit `constraints/xilinx/xc7s50.xdc` and replace placeholder pins:
   ```tcl
   # Find these lines and update:
   set_property -dict {PACKAGE_PIN XX ...} [get_ports clk]  # Your clock pin
   set_property -dict {PACKAGE_PIN XX ...} [get_ports led]  # Your LED pin
   ```

2. **Install Toolchain**
   - **Option A (Recommended):** Install Xilinx Vivado
     ```bash
     source /path/to/Vivado/settings64.sh
     ```
   - **Option B (Experimental):** Install Symbiflow/F4PGA
     - Note: Spartan-7 support is limited

3. **Build**
   ```bash
   make TARGET=xilinx
   ```

## Backward Compatibility

The old files (`blink.v`, `version.lpf`, etc.) are still in the root for reference but are **not used** by the new build system. You can safely delete them once you've verified the new structure works:

```bash
rm blink.v version.lpf version_config.vh version_i2c_slave.v version_storage.v
```

## Testing

All test scripts still work the same way:
```bash
./scripts/test-suite.sh
./scripts/version_read.sh
./scripts/i2c_debug_script.sh
```

## Advantages of New Structure

1. ✅ **Multi-vendor support** - Easy to target different FPGAs
2. ✅ **Clean organization** - Sources, constraints, scripts all separated
3. ✅ **Isolated builds** - Each target has its own build directory
4. ✅ **Better documentation** - README, QUICKSTART, and this migration guide
5. ✅ **Version control friendly** - .gitignore for build artifacts
6. ✅ **Scalable** - Easy to add new FPGA targets

## Questions?

- See [README.md](README.md) for full documentation
- See [QUICKSTART.md](QUICKSTART.md) for common commands
- Check `make help` for all available targets
