#!/bin/bash

echo "Installing GStreamer plugins..."
tar -xzf files/gst-plugins-rs-rpi.tar.gz -C ${ROOTFS_DIR}/
# Set environment variable for GStreamer plugins

echo "Updating GStreamer libs..."
tar -xzf files/gstvideo4linux2_custom.tar.gz -C ${ROOTFS_DIR}/tmp
mv ${ROOTFS_DIR}/tmp/libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so.0.2602.0
mv ${ROOTFS_DIR}/tmp/libgstvideo4linux2.so ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvideo4linux2.so
ln -sf libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so
ln -sf libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so.0

echo "Installing custom libcamera"
tar -xzf files/libcamera_custom.tar.gz -C ${ROOTFS_DIR}/usr/local

echo 'export GST_PLUGIN_PATH=$GST_PLUGIN_PATH:/opt/gst-plugins-rs/lib/aarch64-linux-gnu/:/usr/local/lib/aarch64-linux-gnu/gstreamer-1.0/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/aarch64-linux-gnu/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LIBCAMERA_IPA_MODULE_PATH=/usr/local/lib/aarch64-linux-gnu/libcamera/ipa' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LIBCAMERA_IPA_CONFIG_PATH=/usr/local/share/libcamera/ipa' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo "GStreamer plugins installed."

echo "Setting up udev rules for respeaker mic array..."
cp files/99-respeaker.rules ${ROOTFS_DIR}/etc/udev/rules.d/

echo "Enabling Git LFS for uv system-wide (issue #56)..."
# Login shells, PAM sessions, and user-scope systemd.
grep -qxF 'UV_GIT_LFS=1' "${ROOTFS_DIR}/etc/environment" \
    || echo 'UV_GIT_LFS=1' >> "${ROOTFS_DIR}/etc/environment"
# System-scope systemd services (reachy-mini-daemon et al. run as User=pollen
# at the system level and do NOT inherit /etc/environment).
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system.conf.d"
cat > "${ROOTFS_DIR}/etc/systemd/system.conf.d/10-uv-git-lfs.conf" <<'EOF'
# reachy-mini-os#56: make uv respect Git LFS in system services that invoke it.
[Manager]
DefaultEnvironment="UV_GIT_LFS=1"
EOF

echo "Installing WirePlumber bluez monitor override (issue #55)..."
install -d -m 0755 "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d"
install -m 0644 files/40-force-monitor-bluez.conf \
    "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d/40-force-monitor-bluez.conf"

echo "Creating VERSION.txt file..."
rm ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "ReachyMiniOS: dev" > ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "Created on: $(date '+%Y-%m-%d')" >> ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "VERSION.txt created."

echo "Installing verification script..."
cp files/reachyminios_check.sh ${ROOTFS_DIR}/usr/local/bin/reachyminios_check
chmod +x ${ROOTFS_DIR}/usr/local/bin/reachyminios_check

echo "Installating password configuration script..."
cp files/config_passwd.sh ${ROOTFS_DIR}/usr/local/bin/config_passwd
chmod +x ${ROOTFS_DIR}/usr/local/bin/config_passwd
