#!/bin/bash

# Checks that need no hardware: run at the end of the image build (in the
# chroot) and by reachyminios_check on the robot.

# Same path as launcher.sh, which a chroot never sources.
export GST_PLUGIN_PATH="${GST_PLUGIN_PATH:-/opt/gst-plugins-rs/lib/aarch64-linux-gnu/}"

# List of required directories
REQUIRED_DIRS=(
	"/restore/venvs/mini_daemon"
	"/restore/venvs/apps_venv"
	"/venvs/mini_daemon"
	"/venvs/apps_venv"
	"/venvs/.app_metadata"
	"/home/pollen/.cache/huggingface/hub/datasets--pollen-robotics--reachy-mini-emotions-library"
	"/home/pollen/.cache/huggingface/hub/datasets--pollen-robotics--reachy-mini-dances-library"
	"/bluetooth"
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
# rtpgccbwe (gstrsrtp) is what webrtcsink uses for congestion control.
for plugin in webrtcsrc webrtcsink rtpgccbwe; do
	if gst-inspect-1.0 "$plugin" > /dev/null 2>&1; then
	echo -e "OK: GStreamer plugin '$plugin' is present. \e[32m✔\e[0m"
	else
	echo -e "ERROR: GStreamer plugin '$plugin' is missing. \e[31m✘\e[0m"
		EXIT_CODE=1
	fi
done

# libcamerasrc must expose `sensor-config` (libcamera >= 0.7.1) so the sensor
# mode can be forced, e.g. to keep the full field of view at a reduced output
# resolution.
if gst-inspect-1.0 libcamerasrc 2>/dev/null | grep -qE "^  sensor-config "; then
	echo -e "OK: libcamerasrc exposes the 'sensor-config' property. \e[32m✔\e[0m"
else
	echo -e "ERROR: libcamerasrc has no 'sensor-config' property (libcamera too old). \e[31m✘\e[0m"
	EXIT_CODE=1
fi

exit $EXIT_CODE
