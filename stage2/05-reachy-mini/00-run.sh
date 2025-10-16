#!/bin/bash

# Install required packages
apt-get install -y \
    libportaudio2 \
    libportaudiocpp0 \
    portaudio19-dev \
    alsa-base \
    alsa-utils \
    python3-dbus \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    bluez \
    libcairo2-dev \
    libgirepository1.0-dev \
    pkg-config \
    python3-dev \
    libgstreamer-plugins-bad1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer1.0-dev \
    libglib2.0-dev \
    libssl-dev \    
    gstreamer1.0-libcamera \
    librpicam-app1 \
    libnice10 \
    gstreamer1.0-plugins-good \
    gstreamer1.0-alsa \
    gstreamer1.0-plugins-bad



# Unblock Bluetooth and WiFi
echo "Unblocking Bluetooth and WiFi..."
rfkill unblock bluetooth
rfkill unblock wifi

# Create /venvs directory and set permissions
mkdir -p /venvs
chown -R 1000:1000 /venvs

# Install the daemon (replace with your actual install command)
pip3 install --upgrade --force-reinstall --no-cache-dir \
    "git+https://github.com/pollen-robotics/reachy_mini.git@283-prepare-wireless-version#egg=reachy_mini[wireless-version]"

# Setup services
bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/bluetooth/install_service_bluetooth.sh
bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/wireless/install_service.sh

# Set up restore state
rm -rf /restore/mini_daemon
cp -r /venvs/mini_daemon/ /restore/mini_daemon

tar -xzf files/gst-plugins-rs-rpi.tar.gz -C /opt
chown -R 1000:1000 /opt/gst-plugins-rs
# Set environment variable for GStreamer plugins
echo 'export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/' >> ~/.bashrc