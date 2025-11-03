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

echo "Installing ReSpeaker XVF3800 USB 4-Mic Array tools..."
git clone https://github.com/respeaker/reSpeaker_XVF3800_USB_4MIC_ARRAY.git /tmp/respeaker_tools
cp -r /tmp/respeaker_tools/host_control/rpi_64bit /opt/xvf_host_rpi_64bit
chown pollen:pollen /opt/xvf_host_rpi_64bit
echo 'export PATH=$PATH:/opt/xvf_host_rpi_64bit' >> /home/pollen/.bashrc
rm -rf /tmp/respeaker_tools

echo "Setting up restore state..."
mkdir -p /restore/mini_daemon
cp -r /venvs/mini_daemon/ /restore/mini_daemon
echo "Restore state set up."


