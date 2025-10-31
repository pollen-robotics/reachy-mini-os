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

echo "Installing Reachy Mini daemon..."
uv pip install --force-reinstall "git+https://github.com/pollen-robotics/reachy_mini.git@prepare-wireless-version-2#egg=reachy_mini[wireless-version]"

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


