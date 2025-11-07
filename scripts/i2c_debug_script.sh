#!/bin/bash

echo "=== I2C Debug Script ==="
echo

# Test 1: Debug single-byte addressing
echo "1. Testing single-byte addressing behavior:"
echo "   Reading addresses 0x00 through 0x0F with single-byte addressing:"
for i in {0..15}; do
    ADDR=$(printf "0x%02x" $i)
    RESULT=$(sudo i2ctransfer -y 1 w1@0x50 $ADDR r1 2>&1)
    echo "   Address $ADDR: $RESULT"
done

echo
echo "2. Testing page behavior with single-byte addressing:"
echo "   Does single-byte addressing always use page 0?"
# Set page 1 registers to known values
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x11 >/dev/null 2>&1
sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 0x22 >/dev/null 2>&1

# Try to read them with single-byte addressing
echo "   Single-byte read addr 0x00: $(sudo i2ctransfer -y 1 w1@0x50 0x00 r1)"
echo "   Single-byte read addr 0x01: $(sudo i2ctransfer -y 1 w1@0x50 0x01 r1)"
echo "   Dual-byte read page 1, reg 0: $(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1)"
echo "   Dual-byte read page 1, reg 1: $(sudo i2ctransfer -y 1 w2@0x50 0x01 0x01 r1)"

echo
echo "3. Testing sequential write behavior:"
echo "   Setting brightness=0x33, contrast=0x44"
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x33 >/dev/null 2>&1
sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 0x44 >/dev/null 2>&1
echo "   Verify: $(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r2)"

echo
echo "   Attempting w4 command (write 0x55 to brightness, 0x66 to contrast):"
sudo i2ctransfer -y 1 w4@0x50 0x01 0x00 0x55 0x66
echo "   Result: $(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r2)"

echo
echo "   Breaking it down - what does w4 actually send?"
echo "   - Byte 1: 0x01 (page)"
echo "   - Byte 2: 0x00 (register)" 
echo "   - Byte 3: 0x55 (data for register 0x00)"
echo "   - Byte 4: 0x66 (data for register 0x01?)"

echo
echo "4. Testing the problematic dual-byte read:"
echo "   Attempting: w2@0x50 0x00 0x02 r2"
RESULT=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x02 r2 2>&1)
echo "   Result: $RESULT"

echo
echo "5. Testing wrap-around more carefully:"
echo "   Page 0, starting at register 0x0E (last 2 bytes):"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x0E r2)"
echo "   Page 0, starting at register 0x0F (last byte):"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x0F r1)"
echo "   Page 0, starting at register 0x0F, read 2 bytes (should wrap):"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x0F r2)"

echo
echo "6. Address increment test:"
echo "   Reading 4 bytes starting from page 0, register 0:"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x00 r4)"
echo "   Reading 4 bytes starting from page 0, register 4:"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x04 r4)"
echo "   Reading 4 bytes starting from page 0, register 12:"
echo "   $(sudo i2ctransfer -y 1 w2@0x50 0x00 0x0C r4)"

echo
echo "Debug complete!"
