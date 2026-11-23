#!/bin/bash -e

# Raspberry Pi OS Lite packages a Wireless doesn't use (#117). Purged here
# rather than edited out of pi-gen's lists, so upstream syncs stay conflict-free.
apt-get purge -y --autoremove \
	rpi-connect-lite rpi-update \
	gdb p7zip-full mkvtoolnix lua5.1 luajit cifs-utils \
	man-db apt-listchanges fbset rpi-keyboard-config rpi-keyboard-fw-update

# Fail if one comes back through another package (cloud-init is skipped in
# 04-cloud-init, PipeWire and the OpenCV dev stack are no longer installed).
for p in cloud-init rpi-connect-lite rpi-update pipewire libopencv-core410 linux-image-6.18.50+rpt-rpi-2712; do
	if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed"; then
		echo "ERROR: $p is installed" >&2
		exit 1
	fi
done
