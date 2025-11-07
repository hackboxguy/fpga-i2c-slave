#!/bin/bash
# version_read.sh - Read and display FPGA version information with correct byte ordering

echo "=== FPGA Version Information ==="

# Read all 16 bytes
VERSION_DATA=$(sudo i2ctransfer -y 1 w1@0x50 0x00 r16)
IFS=' ' read -ra BYTES <<< "$VERSION_DATA"

# Convert hex strings to decimal
declare -a DEC_BYTES
for i in "${!BYTES[@]}"; do
    DEC_BYTES[$i]=$((${BYTES[$i]}))
done

# Parse version components with correct byte ordering
# Bytes 0-1: Magic Start (stored as big-endian in FPGA)
MAGIC_START=$(printf "%02X%02X" ${DEC_BYTES[0]} ${DEC_BYTES[1]})

# Bytes 2-3: Version Major.Minor
MAJOR=${DEC_BYTES[2]}
MINOR=${DEC_BYTES[3]}

# Bytes 4-5: Build Number (16-bit big-endian)
BUILD=$(( (${DEC_BYTES[4]} << 8) | ${DEC_BYTES[5]} ))

# Bytes 6-9: Git Hash (32-bit stored as two 16-bit values)
GIT_HASH=$(printf "%02X%02X%02X%02X" ${DEC_BYTES[6]} ${DEC_BYTES[7]} ${DEC_BYTES[8]} ${DEC_BYTES[9]})

# Bytes 10-13: Build Timestamp (32-bit stored as two 16-bit values)
TIMESTAMP=$(( (${DEC_BYTES[10]} << 24) | (${DEC_BYTES[11]} << 16) | (${DEC_BYTES[12]} << 8) | ${DEC_BYTES[13]} ))

# Bytes 14-15: Magic End
MAGIC_END=$(printf "%02X%02X" ${DEC_BYTES[14]} ${DEC_BYTES[15]})

echo "Magic Start: 0x$MAGIC_START"
echo "Version: $MAJOR.$MINOR"
echo "Build Number: $BUILD"
echo "Git Hash: 0x$GIT_HASH"
echo "Build Timestamp: 0x$(printf '%08X' $TIMESTAMP)"
echo "Magic End: 0x$MAGIC_END"

# Convert timestamp to human readable
if command -v date >/dev/null 2>&1; then
    if [ $TIMESTAMP -gt 0 ] && [ $TIMESTAMP -lt 2147483647 ]; then
        echo "Build Date: $(date -d @$TIMESTAMP 2>/dev/null || echo 'Invalid timestamp')"
    else
        echo "Build Date: Invalid timestamp (value: $TIMESTAMP)"
    fi
fi

# Debug: show raw bytes
echo -e "\nRaw bytes (hex):"
echo "$VERSION_DATA"
