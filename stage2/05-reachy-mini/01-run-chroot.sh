#!/bin/bash

echo "Installing UV tool..."
rm -Rf /opt/uv
mkdir -p /opt/uv
chown -R pollen:pollen /opt/uv
runuser -u pollen -- curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/opt/uv" sh
source /opt/uv/env

echo "Creating Python virtual environment..."
rm -Rf /venvs
mkdir /venvs
chown -R pollen:pollen /venvs
cd /venvs
runuser -u pollen -- uv venv mini_daemon --python 3.12
source mini_daemon/bin/activate

echo "Cloning reachy-mini repository..."
runuser -u pollen -- git clone -b prepare-wireless-version-2 https://github.com/pollen-robotics/reachy_mini.git /venvs/src/reachy_mini
runuser -u pollen -- git lfs install
runuser -u pollen -- pushd /venvs/src/reachy_mini && git lfs pull && popd

echo "Installing Reachy Mini daemon..."
uv pip install --force-reinstall "-e /venvs/src/reachy_mini[wireless-version]"

mkdir -p /bluetooth

bash /venvs/mini_daemon/lib/python3.12/site-packages/reachy_mini/daemon/app/services/bluetooth/install_service_bluetooth.sh
bash /venvs/mini_daemon/lib/python3.12/site-packages/reachy_mini/daemon/app/services/wireless/install_service.sh

for service in /etc/systemd/system/reachy-mini-daemon.service \
               /etc/systemd/system/reachy-mini-bluetooth.service; do
    if [ -f "$service" ]; then
        sed -i 's/^User=root$/User=pollen/' "$service"
    fi
done

echo "Setting up restore state..."
mkdir -p /restore
cp -r /venvs/mini_daemon/ /restore
echo "Restore state set up."

echo "Loading I2C kernel module on boot..."
grep -qxF "i2c-dev" /etc/modules-load.d/modules.conf || echo "i2c-dev" >> /etc/modules-load.d/modules.conf
