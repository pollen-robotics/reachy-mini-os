#!/bin/bash

echo "Creating Python virtual environment..."
rm -Rf /venvs
sudo mkdir /venvs
sudo chown -R pollen:pollen /venvs
cd /venvs
python -m venv mini_daemon
source mini_daemon/bin/activate

echo "Installing Reachy Mini daemon..."
pip install --upgrade --force-reinstall --no-cache-dir "git+https://github.com/pollen-robotics/reachy_mini.git@prepare-wireless-version-2#egg=reachy_mini[wireless-version]"


bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/bluetooth/install_service_bluetooth.sh
bash /venvs/mini_daemon/lib/python3.13/site-packages/reachy_mini/daemon/app/services/wireless/install_service.sh

for service in /etc/systemd/system/reachy-mini-daemon.service \
               /etc/systemd/system/reachy-mini-bluetooth.service; do
    if [ -f "$service" ]; then
        sed -i 's/^User=root$/User=pollen/' "$service"
    fi
done

#echo "Enabling wifi activation service..."
#ln -fs /etc/systemd/system/reachy-mini-activate-wifi.service /etc/systemd/system/multi-user.target.wants/reachy-mini-activate-wifi.service

echo "Setting up restore state..."
mkdir -p /restore/mini_daemon
cp -r /venvs/mini_daemon/ /restore/mini_daemon
echo "Restore state set up."


