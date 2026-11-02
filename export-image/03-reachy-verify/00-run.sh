#!/bin/bash -e

# Runs after 02-set-sources' dist-upgrade, so it sees the image as shipped.

# GST_REGISTRY on the chroot's tmpfs /tmp, so the plugin cache doesn't ship.
on_chroot <<- EOF2
	GST_REGISTRY=/tmp/gst-registry.bin /usr/local/bin/reachyminios_build_check
EOF2

# dist-upgrade replaced this overlay once without any error, before the
# apt-mark hold in stage2. cmp follows the .so.0 symlink.
FILES_DIR="${BASE_DIR}/stage2/05-reachy-mini/files"
source "${FILES_DIR}/gstreamer-v4l2.pin"
V4L2_TARBALL="${FILES_DIR}/gstvideo4linux2_custom.tar.gz"
# Absent when stage2 was skipped on a cached rootfs.
if [ ! -f "${V4L2_TARBALL}" ]; then
	curl -fL --retry 3 -o "${V4L2_TARBALL}" "${GSTREAMER_V4L2_URL}"
fi
echo "${GSTREAMER_V4L2_SHA256}  ${V4L2_TARBALL}" | sha256sum -c -
LIB_DIR="${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu"
tar -xzOf "${V4L2_TARBALL}" libgstvideo4linux2.so | cmp - "${LIB_DIR}/gstreamer-1.0/libgstvideo4linux2.so"
tar -xzOf "${V4L2_TARBALL}" libgstpbutils-1.0.so.0.2602.0 | cmp - "${LIB_DIR}/libgstpbutils-1.0.so.0"
echo "GStreamer v4l2 overlay intact."
