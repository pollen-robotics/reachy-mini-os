#!/bin/bash

echo "Installing GStreamer plugins..."
tar -xzf files/gst-plugins-rs-rpi.tar.gz -C ${ROOTFS_DIR}/
# Set environment variable for GStreamer plugins
echo 'export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo "GStreamer plugins installed."
