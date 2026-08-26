#!/bin/bash

# Single source of truth for the SDK version: the daemon venv, the pre-seeded
# apps_venv and the daemon's own apps_venv sync check must all agree.
REACHY_MINI_VERSION="1.10.0"

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
uv pip install "reachy-mini[wireless-version]==${REACHY_MINI_VERSION}"
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

echo "Pre-installing conversation app and default move datasets..."
runuser -u pollen -- env "REACHY_MINI_VERSION=${REACHY_MINI_VERSION}" /venvs/mini_daemon/bin/python - <<'PYEOF'
import asyncio
import logging
import os
import subprocess
import sys

from reachy_mini.apps.sources import hf_space
from reachy_mini.apps.sources.local_common_venv import install_package
from reachy_mini.motion.recorded_move import DEFAULT_DATASETS, preload_dataset

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("preinstall")

apps = asyncio.run(hf_space.list_available_apps())
app = next((a for a in apps if a.name == "reachy_mini_conversation_app"), None)
if app is None:
    sys.exit("reachy_mini_conversation_app not found in the app store catalog")
if asyncio.run(install_package(app, logger, wireless_version=True)) != 0:
    sys.exit("conversation app install failed")

# install_package creates apps_venv with an UNPINNED reachy-mini, so it picks up
# whatever is latest on PyPI at build time. On every wireless boot the daemon's
# check_and_sync_apps_venv_sdk() compares that against its own version with
# exact string equality and reinstalls over the network when they differ - the
# first-boot download this block exists to avoid. Assert rather than force a
# downgrade: if the app ever needs a newer SDK than the image ships, that is a
# call for whoever bumps REACHY_MINI_VERSION, not something to paper over here.
pin = os.environ["REACHY_MINI_VERSION"]
seeded = subprocess.run(
    [
        "/venvs/apps_venv/bin/python",
        "-c",
        "from importlib.metadata import version; print(version('reachy_mini'))",
    ],
    capture_output=True,
    text=True,
).stdout.strip()
if seeded != pin:
    sys.exit(
        f"apps_venv reachy-mini is '{seeded}', daemon is '{pin}': the daemon "
        "would resync apps_venv over the network on first boot"
    )

for name in DEFAULT_DATASETS:
    if preload_dataset(name) is None:
        sys.exit(f"dataset preload failed: {name}")
PYEOF

echo "Setting up restore state..."
mkdir -p /restore
cp -r /venvs /restore/
chown -R pollen:pollen /restore/
echo "Restore state set up."

echo "Loading I2C kernel module on boot..."
grep -qxF "i2c-dev" /etc/modules-load.d/modules.conf || echo "i2c-dev" >> /etc/modules-load.d/modules.conf

chown -R pollen:pollen /venvs
