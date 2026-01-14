#!/bin/bash

echo "Installing UV tool..."
rm -Rf /opt/uv
mkdir -p /opt/uv
chown -R pollen:pollen /opt/uv
runuser -u pollen -- curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/opt/uv" sh
echo 'export PATH=$PATH:/opt/uv' >> /home/pollen/.bashrc
source /opt/uv/env

echo "Creating Python virtual environment..."
rm -Rf /venvs
mkdir /venvs
chown -R pollen:pollen /venvs
cd /venvs
runuser -u pollen -- uv venv mini_daemon --python 3.12
source mini_daemon/bin/activate

echo "Installing Reachy Mini daemon..."
uv pip install "reachy-mini[wireless-version,gstreamer]==v1.2.11"
uv pip install rustypot

echo "Setting up Bluetooth, Wireless and GPIO shutdown services..."
mkdir -p /bluetooth
bash "/venvs/mini_daemon/lib/python3.12/site-packages/reachy_mini/daemon/app/services/bluetooth/install_service_bluetooth.sh"

bash "/venvs/mini_daemon/lib/python3.12/site-packages/reachy_mini/daemon/app/services/wireless/install_service.sh"

bash "/venvs/mini_daemon/lib/python3.12/site-packages/reachy_mini/daemon/app/services/gpio_shutdown/install_service.sh"

for service in /etc/systemd/system/reachy-mini-daemon.service \
               /etc/systemd/system/reachy-mini-bluetooth.service \
                /etc/systemd/system/gpio-shutdown-daemon.service; do
    if [ -f "$service" ]; then
        sed -i 's/^User=root$/User=pollen/' "$service"
    fi
done

echo "Setting up restore state..."
mkdir -p /restore
cp -r /venvs /restore/
chown -R pollen:pollen /restore/
echo "Restore state set up."

echo "Loading I2C kernel module on boot..."
grep -qxF "i2c-dev" /etc/modules-load.d/modules.conf || echo "i2c-dev" >> /etc/modules-load.d/modules.conf

chown -R pollen:pollen /venvs
