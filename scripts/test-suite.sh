#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
PASS=0
FAIL=0

# Default values (can be overridden by command line)
GIT_HASH="0xDEADBEEF"
TIMESTAMP="0x68921AE5"
BUILD_NUM="42"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --githash=*)
            GIT_HASH="${arg#*=}"
            # Remove 0x prefix if present and convert to uppercase
            GIT_HASH=$(echo "${GIT_HASH#0x}" | tr '[:lower:]' '[:upper:]')
            ;;
        --timestamp=*)
            TIMESTAMP="${arg#*=}"
            # Remove 0x prefix if present and convert to uppercase
            TIMESTAMP=$(echo "${TIMESTAMP#0x}" | tr '[:lower:]' '[:upper:]')
            ;;
        --build=*)
            BUILD_NUM="${arg#*=}"
            ;;
        --help)
            echo "Usage: $0 [--githash=0xDEADBEEF] [--timestamp=0x68921AE5] [--build=42]"
            echo "  --githash    Git commit hash (32-bit hex value)"
            echo "  --timestamp  Build timestamp (32-bit hex value)"
            echo "  --build      Build number (decimal)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Convert values to expected byte format (lowercase for comparison)
# Extract bytes using cut instead of bash substring
GIT_B1=$(echo "$GIT_HASH" | cut -c1-2 | tr '[:upper:]' '[:lower:]')
GIT_B2=$(echo "$GIT_HASH" | cut -c3-4 | tr '[:upper:]' '[:lower:]')
GIT_B3=$(echo "$GIT_HASH" | cut -c5-6 | tr '[:upper:]' '[:lower:]')
GIT_B4=$(echo "$GIT_HASH" | cut -c7-8 | tr '[:upper:]' '[:lower:]')

TIME_B1=$(echo "$TIMESTAMP" | cut -c1-2 | tr '[:upper:]' '[:lower:]')
TIME_B2=$(echo "$TIMESTAMP" | cut -c3-4 | tr '[:upper:]' '[:lower:]')
TIME_B3=$(echo "$TIMESTAMP" | cut -c5-6 | tr '[:upper:]' '[:lower:]')
TIME_B4=$(echo "$TIMESTAMP" | cut -c7-8 | tr '[:upper:]' '[:lower:]')

BUILD_HI=$(printf "0x%02x" $((BUILD_NUM / 256)))
BUILD_LO=$(printf "0x%02x" $((BUILD_NUM % 256)))

echo "=== Comprehensive I2C Slave Test Suite ==="
echo "Testing I2C slave at address 0x50"
echo "Expected values:"
echo "  Git Hash:   0x$GIT_HASH"
echo "  Timestamp:  0x$TIMESTAMP"
echo "  Build:      $BUILD_NUM"
echo ""

# Function to check test result
check_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        printf "${GREEN}✓ %s: PASS${NC}\n" "$test_name"
        PASS=$((PASS + 1))
    else
        printf "${RED}✗ %s: FAIL${NC}\n" "$test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

# Save initial state
printf "${YELLOW}Saving initial state...${NC}\n"
INITIAL_BRIGHTNESS=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
INITIAL_CONTRAST=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x01 r1 2>/dev/null)

# Test 1: Single-byte addressing reads
printf "\n${YELLOW}Test 1: Single-byte addressing reads${NC}\n"

# Read version magic start
RESULT=$(sudo i2ctransfer -y 1 w1@0x50 0x00 r2 2>/dev/null)
check_result "Read magic start (addr 0x00)" "0xae 0x25" "$RESULT"

# Read from middle of version data (use actual git hash)
RESULT=$(sudo i2ctransfer -y 1 w1@0x50 0x08 r4 2>/dev/null)
EXPECTED_GIT="0x$GIT_B3 0x$GIT_B4 0x$TIME_B1 0x$TIME_B2"
check_result "Read git hash portion (addr 0x08)" "$EXPECTED_GIT" "$RESULT"

# Read with wrap-around
RESULT=$(sudo i2ctransfer -y 1 w1@0x50 0x0E r4 2>/dev/null)
check_result "Read with wrap-around (addr 0x0E)" "0xe0 0x25 0xae 0x25" "$RESULT"

# Read single bytes
MAJOR=$(sudo i2ctransfer -y 1 w1@0x50 0x02 r1 2>/dev/null)
check_result "Read major version" "0x01" "$MAJOR"

MINOR=$(sudo i2ctransfer -y 1 w1@0x50 0x03 r1 2>/dev/null)
check_result "Read minor version" "0x00" "$MINOR"

LAST_BYTE=$(sudo i2ctransfer -y 1 w1@0x50 0x0F r1 2>/dev/null)
check_result "Read last byte (addr 0x0F)" "0x25" "$LAST_BYTE"

# Test 2: Dual-byte addressing - Page 0
printf "\n${YELLOW}Test 2: Dual-byte addressing - Page 0 (Version Info)${NC}\n"

# Read full version info with actual values
FULL_VERSION=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x00 r16 2>/dev/null)
EXPECTED_FULL="0xae 0x25 0x01 0x00 $BUILD_HI $BUILD_LO 0x$GIT_B1 0x$GIT_B2 0x$GIT_B3 0x$GIT_B4 0x$TIME_B1 0x$TIME_B2 0x$TIME_B3 0x$TIME_B4 0xe0 0x25"
check_result "Read full version info" "$EXPECTED_FULL" "$FULL_VERSION"

# Read specific portions
VERSION=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x02 r2 2>/dev/null)
check_result "Read version major.minor" "0x01 0x00" "$VERSION"

BUILD=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x04 r2 2>/dev/null)
check_result "Read build number" "$BUILD_HI $BUILD_LO" "$BUILD"

GIT_HASH_READ=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x06 r4 2>/dev/null)
check_result "Read git hash" "0x$GIT_B1 0x$GIT_B2 0x$GIT_B3 0x$GIT_B4" "$GIT_HASH_READ"

# Test wrap-around with dual-byte
WRAP_DATA=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x0C r8 2>/dev/null)
EXPECTED_WRAP="0x$TIME_B3 0x$TIME_B4 0xe0 0x25 0xae 0x25 0x01 0x00"
check_result "Dual-byte wrap-around" "$EXPECTED_WRAP" "$WRAP_DATA"

# Test 3: Dual-byte addressing - Page 1
printf "\n${YELLOW}Test 3: Dual-byte addressing - Page 1 (Config Registers)${NC}\n"

# Reset to known values first (with delay to avoid I/O errors)
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x80 >/dev/null 2>&1
sleep 0.02
sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 0x40 >/dev/null 2>&1
sleep 0.02

# Read brightness
BRIGHTNESS=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "Read brightness register" "0x80" "$BRIGHTNESS"

# Read contrast
CONTRAST=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x01 r1 2>/dev/null)
check_result "Read contrast register" "0x40" "$CONTRAST"

# Test 4: Write operations
printf "\n${YELLOW}Test 4: Write operations - Page 1${NC}\n"

# Write brightness to maximum (with delay)
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0xFF >/dev/null 2>&1
sleep 0.02
RESULT=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "Write brightness to 0xFF" "0xff" "$RESULT"

# Write brightness to minimum (with delay)
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x00 >/dev/null 2>&1
sleep 0.02
RESULT=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "Write brightness to 0x00" "0x00" "$RESULT"

# Test 5: PWM Brightness Tests (Non-interactive)
printf "\n${YELLOW}Test 5: PWM Brightness Control Tests${NC}\n"

# Test default brightness behavior (0x80)
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x80 >/dev/null 2>&1
sleep 0.02
READBACK=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "Set brightness to 0x80 (default)" "0x80" "$READBACK"

# Test PWM values
for brightness_val in 0x00 0x40 0x7f 0xc0 0xff; do
    sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 $brightness_val >/dev/null 2>&1
    sleep 0.02
    READBACK=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
    check_result "PWM brightness register set to $brightness_val" "$brightness_val" "$READBACK"
done

# Test 6: PWM Persistence Test
printf "\n${YELLOW}Test 6: PWM Persistence Test${NC}\n"

# Set specific brightness
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x90 >/dev/null 2>&1
sleep 0.02

# Perform other operations
sudo i2ctransfer -y 1 w2@0x50 0x00 0x00 r16 >/dev/null 2>&1  # Read version
sleep 0.02
sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 0x33 >/dev/null 2>&1  # Write contrast
sleep 0.02

# Check brightness unchanged
PERSIST=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "PWM brightness persists after other ops" "0x90" "$PERSIST"

# Test 7: Rapid PWM changes (with delays to avoid I/O errors)
printf "\n${YELLOW}Test 7: Rapid PWM Changes${NC}\n"

RAPID_PASS=0
i=1
while [ $i -le 10 ]; do
    VALUE=$(printf "0x%02x" $((i * 25)))
    sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 $VALUE >/dev/null 2>&1
    sleep 0.01  # Small delay to avoid I/O errors
    READBACK=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
    if [ "$READBACK" = "$VALUE" ]; then
        RAPID_PASS=$((RAPID_PASS + 1))
    fi
    i=$((i + 1))
done
check_result "Rapid PWM changes (10 iterations)" "10" "$RAPID_PASS"

# Test 8: Auto-increment with PWM registers
printf "\n${YELLOW}Test 8: Auto-increment with Config Registers${NC}\n"

# Set known pattern (with delays)
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0x11 >/dev/null 2>&1
sleep 0.02
sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 0x22 >/dev/null 2>&1
sleep 0.02

# Read with auto-increment
AUTO_INC=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r8 2>/dev/null)
EXPECTED_INC="0x11 0x22 0xff 0xff 0xff 0xff 0xff 0xff"
check_result "Auto-increment read" "$EXPECTED_INC" "$AUTO_INC"

# Test 9: Write to read-only page
printf "\n${YELLOW}Test 9: Write Protection Test${NC}\n"

# Try to write to page 0
sudo i2ctransfer -y 1 w3@0x50 0x00 0x00 0xFF >/dev/null 2>&1
sleep 0.02
READONLY=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x00 r1 2>/dev/null)
check_result "Read-only page protection" "0xae" "$READONLY"

# Test 10: Page boundary test with PWM
printf "\n${YELLOW}Test 10: Page Boundary Test${NC}\n"

# Write to page 1, then read from page 0
sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 0xAB >/dev/null 2>&1
sleep 0.02
PAGE0=$(sudo i2ctransfer -y 1 w2@0x50 0x00 0x00 r1 2>/dev/null)
check_result "Page 0 unaffected by page 1 write" "0xae" "$PAGE0"

PAGE1=$(sudo i2ctransfer -y 1 w2@0x50 0x01 0x00 r1 2>/dev/null)
check_result "Page 1 contains written value" "0xab" "$PAGE1"

# Restore initial state
printf "\n${YELLOW}Restoring initial state...${NC}\n"
if [ -n "$INITIAL_BRIGHTNESS" ]; then
    sudo i2ctransfer -y 1 w3@0x50 0x01 0x00 "$INITIAL_BRIGHTNESS" >/dev/null 2>&1
fi
if [ -n "$INITIAL_CONTRAST" ]; then
    sudo i2ctransfer -y 1 w3@0x50 0x01 0x01 "$INITIAL_CONTRAST" >/dev/null 2>&1
fi

# Summary
printf "\n${YELLOW}=== Test Summary ===${NC}\n"
printf "Total tests: %d\n" $((PASS + FAIL))
printf "${GREEN}Passed: %d${NC}\n" $PASS
printf "${RED}Failed: %d${NC}\n" $FAIL

if [ $FAIL -eq 0 ]; then
    printf "\n${GREEN}All tests passed! ✓${NC}\n"
    exit 0
else
    printf "\n${RED}Some tests failed! ✗${NC}\n"
    exit 1
fi
