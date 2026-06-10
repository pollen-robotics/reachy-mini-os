#!/bin/bash

echo "Installing GStreamer plugins..."
tar -xzf files/gst-plugins-rs-rpi.tar.gz -C ${ROOTFS_DIR}/
# Set environment variable for GStreamer plugins
echo 'export GST_PLUGIN_PATH=/opt/gst-plugins-rs/lib/aarch64-linux-gnu/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo "GStreamer plugins installed."

echo "Setting up udev rules for respeaker mic array..."
cp files/99-respeaker.rules ${ROOTFS_DIR}/etc/udev/rules.d/

# raspberrypi-sys-mods >= 1:20251028+1 removes /etc/sudoers.d/010_pi-nopasswd
# (its postinst calls dpkg-maintscript-helper rm_conffile). Reachy creates the
# pollen user at build time, bypassing the Imager/firstboot userconf flow that
# would otherwise grant passwordless sudo, so pollen ends up without it. The
# reachy daemons run as pollen with no TTY and rely on sudo for a handful of
# privileged operations, which breaks WiFi and Bluetooth when sudo prompts.
#
# Grant ONLY the exact command vectors the daemon needs. Do NOT grant blanket
# NOPASSWD or bare /usr/bin/systemctl: that is a trivial local root escalation
# via `systemctl link` of an attacker-controlled unit whose ExecStart runs as
# root. Pinning each command to fixed arguments removes the escalation
# primitive. NOTE: the /bluetooth/commands/*.sh scripts MUST remain root-owned
# and non-pollen-writable, or this scoping is bypassable.
echo "Granting pollen scoped passwordless sudo..."
install -d -m 0755 "${ROOTFS_DIR}/etc/sudoers.d"
cat > "${ROOTFS_DIR}/etc/sudoers.d/010-pollen-reachy" <<'EOF'
Cmnd_Alias REACHY = \
    /usr/bin/systemctl restart reachy-mini-daemon, \
    /usr/bin/systemctl restart reachy-mini-bluetooth, \
    /usr/sbin/rfkill unblock bluetooth, \
    /usr/sbin/rfkill unblock wifi, \
    /usr/sbin/shutdown -h now, \
    /usr/bin/chown pollen\:pollen -R /venvs, \
    /bluetooth/commands/HOTSPOT.sh, \
    /bluetooth/commands/WIFI_RESET.sh, \
    /bluetooth/commands/SOFTWARE_RESET.sh, \
    /bluetooth/commands/RESTART_DAEMON.sh
pollen ALL=(root) NOPASSWD: REACHY
EOF
chmod 0440 "${ROOTFS_DIR}/etc/sudoers.d/010-pollen-reachy"
# Fail the build if the sudoers file is malformed (a bad file locks out sudo).
on_chroot <<- EOF
	visudo -cf /etc/sudoers.d/010-pollen-reachy
EOF

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