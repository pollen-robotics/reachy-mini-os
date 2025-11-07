#!/bin/bash

echo "Installing GStreamer plugins..."
tar -xzf files/gst-plugins-rs-rpi.tar.gz -C ${ROOTFS_DIR}/
# Set environment variable for GStreamer plugins
echo 'export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
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