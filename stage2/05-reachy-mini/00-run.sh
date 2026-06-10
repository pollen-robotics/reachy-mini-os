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
