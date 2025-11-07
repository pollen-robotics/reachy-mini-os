#!/bin/bash

echo "--- System Information ---"
echo "Date: $(date)"
echo "Kernel version: $(uname -r)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Disk usage (root):"
df -h /
echo "Memory usage:"
free -h
echo "--------------------------"

# List of required directories
REQUIRED_DIRS=(
	"/restore/venvs/src"
	"/restore/venvs/mini_daemon"
	"/venvs/src"
	"/venvs/mini_daemon"
	"/bluetooth"
    "/opt/xvf_host_rpi_64bit"
    "/opt/gst-plugins-rs"
    "/opt/uv"
)

EXIT_CODE=0

for dir in "${REQUIRED_DIRS[@]}"; do
	if [ ! -d "$dir" ]; then
	echo -e "ERROR: Directory $dir does not exist. \e[31m✘\e[0m"
		EXIT_CODE=1
	elif [ -z "$(ls -A "$dir")" ]; then
	echo -e "ERROR: Directory $dir is empty. \e[31m✘\e[0m"
		EXIT_CODE=1
	else
		echo -e "OK: Directory $dir exists and is not empty. \e[32m✔\e[0m"
	fi
done

# Check for GStreamer plugins
for plugin in webrtcsrc webrtcsink; do
	if gst-inspect-1.0 "$plugin" > /dev/null 2>&1; then
	echo -e "OK: GStreamer plugin '$plugin' is present. \e[32m✔\e[0m"
	else
	echo -e "ERROR: GStreamer plugin '$plugin' is missing. \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
done

# Get ReSpeaker version
if command -v xvf_host > /dev/null 2>&1; then
	VERSION_OUTPUT=$(xvf_host VERSION 2>&1)
	VERSION_LINE=$(echo "$VERSION_OUTPUT" | grep '^VERSION')
	if [ -n "$VERSION_LINE" ]; then
		echo -e "OK: ReSpeaker VERSION: $VERSION_LINE \e[32m✔\e[0m"
	else
	echo -e "ERROR: Could not determine ReSpeaker version from xvf_host output. \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: xvf_host command not found. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Test ReSpeaker audio output
echo "Testing ReSpeaker audio output..."
CARD_NUM=$(aplay -l | awk '/reSpeaker XVF3800 4-Mic Array/ {for(i=1;i<=NF;i++) if ($i=="card") {val=$(i+1); sub(":$", "", val); print val}}' | head -n1)
if [ -n "$CARD_NUM" ]; then
	echo -e "OK: Found ReSpeaker audio card number: $CARD_NUM \e[32m✔\e[0m"
	# Set volume to 100% before testing
	if amixer -c $CARD_NUM sset 'PCM' 100% > /dev/null 2>&1 && amixer -c $CARD_NUM sset 'PCM,1' 100% > /dev/null 2>&1; then
		echo -e "OK: Set volume to 100% for card $CARD_NUM (PCM and PCM,1) \e[32m✔\e[0m"
	else
		echo -e "ERROR: Failed to set volume for card $CARD_NUM \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
	echo "Playing test sound..."
	timeout 2s speaker-test -Dplughw:$CARD_NUM > /tmp/speaker_test.txt 2>&1
else
	echo -e "ERROR: ReSpeaker audio card not found. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Test ReSpeaker audio recording
echo "Testing ReSpeaker audio recording with arecord..."
WAV_PATH="/tmp/test.wav"
rm -f "$WAV_PATH"
if [ -n "$CARD_NUM" ]; then
	arecord -Dplughw:$CARD_NUM -d 2 -f cd -t wav -r 16000 -c 1 "$WAV_PATH" > /dev/null 2>&1
	if [ -f "$WAV_PATH" ]; then
		echo -e "OK: Audio recording succeeded, $WAV_PATH exists. \e[32m✔\e[0m"
	else
		echo -e "ERROR: Audio recording failed, $WAV_PATH does not exist. \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: ReSpeaker audio card not found for recording. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check for imx708_wide camera
if command -v rpicam-vid > /dev/null 2>&1; then
	CAM_LIST=$(rpicam-vid --list-cam 2>&1)
	if echo "$CAM_LIST" | grep -q "imx708_wide"; then
	echo -e "OK: Camera 'imx708_wide' is connected. \e[32m✔\e[0m"
	else
	echo -e "ERROR: Camera 'imx708_wide' is not detected by rpicam-vid. \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: rpicam-vid command not found. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Test camera by taking a picture
echo "Testing camera capture with rpicam-jpeg..."
PIC_PATH="/tmp/test.jpg"
rm -f "$PIC_PATH"
rpicam-jpeg --output "$PIC_PATH" --timeout 200 --width 640 --height 480 > /dev/null 2>&1
if [ -f "$PIC_PATH" ]; then
	echo -e "OK: Camera capture succeeded, $PIC_PATH exists. \e[32m✔\e[0m"
else
	echo -e "ERROR: Camera capture failed, $PIC_PATH does not exist. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check that /venvs/src/reachy_mini git working directory is clean
REACHY_MINI_DIR="/venvs/src/reachy_mini"
if [ -d "$REACHY_MINI_DIR/.git" ]; then
	GIT_STATUS=$(git -C "$REACHY_MINI_DIR" status --porcelain)
	if [ -z "$GIT_STATUS" ]; then
	echo -e "OK: $REACHY_MINI_DIR git working directory is clean. \e[32m✔\e[0m"
	else
	echo -e "ERROR: $REACHY_MINI_DIR git working directory is not clean. \e[31m✘\e[0m" >&2
		git -C "$REACHY_MINI_DIR" status
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: $REACHY_MINI_DIR is not a git repository. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check that /restore/venvs/src/reachy_mini git working directory is clean
REACHY_MINI_DIR="/restore/venvs/src/reachy_mini"
if [ -d "$REACHY_MINI_DIR/.git" ]; then
	GIT_STATUS=$(git -c safe.directory="$REACHY_MINI_DIR" -C "$REACHY_MINI_DIR" status --porcelain)
	if [ -z "$GIT_STATUS" ]; then
	echo -e "OK: $REACHY_MINI_DIR git working directory is clean. \e[32m✔\e[0m"
	else
	echo -e "ERROR: $REACHY_MINI_DIR git working directory is not clean. \e[31m✘\e[0m" >&2
		git -c safe.directory="$REACHY_MINI_DIR" -C "$REACHY_MINI_DIR" status
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: $REACHY_MINI_DIR is not a git repository. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check reachy-mini-bluetooth.service status
if command -v systemctl > /dev/null 2>&1; then
	SERVICE_STATUS=$(systemctl is-active reachy-mini-bluetooth.service)
	if [ "$SERVICE_STATUS" = "active" ]; then
	echo -e "OK: reachy-mini-bluetooth.service is active. \e[32m✔\e[0m"
	else
	echo -e "ERROR: reachy-mini-bluetooth.service is not active (status: $SERVICE_STATUS). \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: systemctl command not found. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check reachy-mini-daemon.service status
if command -v systemctl > /dev/null 2>&1; then
	SERVICE_STATUS=$(systemctl is-active reachy-mini-daemon.service)
	if [ "$SERVICE_STATUS" = "active" ]; then
	echo -e "OK: reachy-mini-daemon.service is active. \e[32m✔\e[0m"
	else
	echo -e "ERROR: reachy-mini-daemon.service is not active (status: $SERVICE_STATUS). \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
else
	echo -e "ERROR: systemctl command not found. \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check for specific i2c kernel modules
I2C_MODULES=(i2c_dev i2c_mux_pinctrl i2c_brcmstb i2c_mux i2c_bcm2835)
echo "Checking for i2c kernel modules..."
FOUND_MODULE=0
for mod in "${I2C_MODULES[@]}"; do
	if lsmod | grep -q "^$mod"; then
	echo -e "OK: $mod kernel module is loaded. \e[32m✔\e[0m"
		FOUND_MODULE=1
		break
	fi
done
if [ $FOUND_MODULE -eq 0 ]; then
	echo -e "ERROR: None of the expected i2c kernel modules are loaded: ${I2C_MODULES[*]} \e[31m✘\e[0m"
	EXIT_CODE=1
fi

## Check daemon API status
DAEMON_API_URL="http://127.0.0.1:8000/api/daemon/status"
API_RESPONSE=$(curl -s -X 'GET' "$DAEMON_API_URL" -H 'accept: application/json')
WIRELESS_VERSION=$(echo "$API_RESPONSE" | grep -o '"wireless_version":true')
ERROR_NULL=$(echo "$API_RESPONSE" | grep -o '"error":null')
if [ -n "$WIRELESS_VERSION" ] && [ -n "$ERROR_NULL" ]; then
	echo -e "OK: Daemon API wireless_version is true and error is null. \e[32m✔\e[0m"
else
	echo -e "ERROR: Daemon API check failed. Response: $API_RESPONSE \e[31m✘\e[0m"
	EXIT_CODE=1
fi

# Check Xl330 devices with rustypot
echo "Testing Xl330 devices with rustypot..."
source /venvs/mini_daemon/bin/activate
PYTHON_SCRIPT="/tmp/xl330_ping_test.py"
cat << 'EOF' > $PYTHON_SCRIPT
from rustypot import Xl330PyController
import sys

controller = Xl330PyController('/dev/ttyAMA3', 1000000, 0.5)
ids = [10, 11, 12, 13, 14, 15, 16, 17, 18]
success = True
for id in ids:
	result = controller.ping(id)
	print(f'ID {id}: {result}')
	if not result:
		success = False
sys.exit(0 if success else 1)
EOF

if python3 $PYTHON_SCRIPT > /tmp/xl330_ping_result.txt 2>&1; then
	echo -e "OK: All Xl330 devices responded to ping. \e[32m✔\e[0m"
else
	echo -e "ERROR: One or more Xl330 devices did not respond to ping. See /tmp/xl330_ping_result.txt \e[31m✘\e[0m"
	cat /tmp/xl330_ping_result.txt
	EXIT_CODE=1
fi
rm -f $PYTHON_SCRIPT

# Check IMU
echo "Testing IMU..."
# Check we find 0x18 and 0x69 on i2c bus 4
IMU_I2C_ADDRESSES=("18" "69")
FOUND_ALL=1
for addr in "${IMU_I2C_ADDRESSES[@]}"; do
	if i2cdetect -y 4 | grep -q "$addr"; then
	echo -e "OK: IMU device found at address $addr on i2c bus 4. \e[32m✔\e[0m"
	else
	echo -e "ERROR: IMU device not found at address $addr on i2c bus 4. \e[31m✘\e[0m"
		FOUND_ALL=0
		EXIT_CODE=1
	fi
done
if [ $FOUND_ALL -eq 1 ]; then
	source /venvs/mini_daemon/bin/activate
	PYTHON_SCRIPT="/tmp/imu_test.py"

	cat << 'EOF' > $PYTHON_SCRIPT
from bmi088 import BMI088

imu = BMI088(4)
print("Accelerometer data:", imu.read_accelerometer())
print("Gyroscope data:", imu.read_gyroscope())
print("Temperature data:", imu.read_temperature())
EOF

	if python3 $PYTHON_SCRIPT > /tmp/imu_result.txt 2>&1; then
		echo -e "OK: IMU tests passed. \e[32m✔\e[0m"
	else
		echo -e "ERROR: IMU tests failed. See /tmp/imu_result.txt \e[31m✘\e[0m"
		cat /tmp/imu_result.txt
		EXIT_CODE=1
	fi
	rm -f $PYTHON_SCRIPT
fi

# Print final result
if [ $EXIT_CODE -eq 0 ]; then
	echo -e "Image validation PASSED. \e[32m✔\e[0m"
else
	echo -e "Image validation FAILED. \e[31m✘\e[0m"
fi

exit $EXIT_CODE
