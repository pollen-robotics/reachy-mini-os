#!/bin/bash

echo "Cloning Reachy Mini repository..."
SRC_DIR=/tmp/reachy_mini_code
rm -Rf $SRC_DIR
git clone --depth 1 -b 283-prepare-wireless-version https://github.com/pollen-robotics/reachy_mini.git $SRC_DIR
echo "Repository cloned to $SRC_DIR."

echo "Creating Python virtual environment..."
rm -Rf /venvs
sudo mkdir /venvs
sudo chown -R pollen:pollen /venvs
cd /venvs
python -m venv mini_daemon
source mini_daemon/bin/activate

echo "Installing Reachy Mini daemon..."
pip install --upgrade --force-reinstall --no-cache-dir   "git+https://github.com/pollen-robotics/reachy_mini.git@283-prepare-wireless-version#egg=reachy_mini[wireless-version]"

bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/bluetooth/install_service_bluetooth.sh
bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/wireless/install_service.sh

for service in /etc/systemd/system/reachy-mini-daemon.service \
               /etc/systemd/system/reachy-mini-bluetooth.service; do
    if [ -f "$service" ]; then
        sed -i 's/^User=root$/User=pollen/' "$service"
    fi
done

echo "Setting up restore state..."
mkdir -p /restore/mini_daemon
cp -r /venvs/mini_daemon/ /restore/mini_daemon
echo "Restore state set up."

echo "Cleaning up..."
rm -Rf $SRC_DIR
