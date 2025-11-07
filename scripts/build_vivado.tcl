# Vivado TCL Build Script for I2C Slave
# Automated synthesis, implementation, and bitstream generation

# Get arguments from command line
set build_dir [lindex $argv 0]
set top_module [lindex $argv 1]
set part [lindex $argv 2]

puts "=========================================="
puts "Vivado Build Script for I2C Slave"
puts "Build Directory: $build_dir"
puts "Top Module: $top_module"
puts "Part: $part"
puts "=========================================="

# Create project in memory (non-project mode for scripting)
set project_name "i2c_slave"
create_project -in_memory -part $part

# Add source files
set rtl_dir "../rtl"
set include_dir "../include"
set constraint_dir "../constraints/xilinx"

read_verilog -sv [glob $rtl_dir/*.v]
read_xdc $constraint_dir/xc7s50.xdc

# Set include directories
set_property include_dirs [list $include_dir] [current_fileset]

# Set top module
set_property top $top_module [current_fileset]

# Run synthesis
puts "Running synthesis..."
synth_design -top $top_module -part $part -flatten_hierarchy rebuilt

# Write checkpoint
write_checkpoint -force $build_dir/${project_name}_synth.dcp

# Run implementation
puts "Running optimization..."
opt_design

puts "Running placement..."
place_design

puts "Running routing..."
route_design

# Write checkpoint
write_checkpoint -force $build_dir/${project_name}_route.dcp

# Generate reports
report_utilization -file $build_dir/utilization.rpt
report_timing_summary -file $build_dir/timing_summary.rpt

# Generate bitstream
puts "Generating bitstream..."
write_bitstream -force $build_dir/${project_name}.bit

puts "Build complete: $build_dir/${project_name}.bit"
puts "=========================================="
