#!/bin/bash
set -e

echo "Installing GStreamer plugins..."
# Built by .github/workflows/build-gst-plugins-rs.yml from the tag pinned in
# files/gst-plugins-rs.pin, published as a release asset. Downloaded here (not
# in CI) so local builds behave identically; sha256-verified so a bad download
# fails the build instead of producing a broken image (#78).
source files/gst-plugins-rs.pin
if [ ! -f files/gst-plugins-rs-rpi.tar.gz ]; then
	curl -fL --retry 3 -o files/gst-plugins-rs-rpi.tar.gz "${GST_PLUGINS_RS_URL}"
fi
echo "${GST_PLUGINS_RS_SHA256}  files/gst-plugins-rs-rpi.tar.gz" | sha256sum -c -
tar -xzf files/gst-plugins-rs-rpi.tar.gz -C ${ROOTFS_DIR}/

echo "Updating GStreamer libs..."
tar -xzf files/gstvideo4linux2_custom.tar.gz -C ${ROOTFS_DIR}/tmp
mv ${ROOTFS_DIR}/tmp/libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so.0.2602.0
mv ${ROOTFS_DIR}/tmp/libgstvideo4linux2.so ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/gstreamer-1.0/libgstvideo4linux2.so
ln -sf libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so
ln -sf libgstpbutils-1.0.so.0.2602.0 ${ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/libgstpbutils-1.0.so.0

echo "Installing custom libcamera"
tar -xzf files/libcamera_custom.tar.gz -C ${ROOTFS_DIR}/usr/local

echo 'export GST_PLUGIN_PATH=$GST_PLUGIN_PATH:/opt/gst-plugins-rs/lib/aarch64-linux-gnu/:/usr/local/lib/aarch64-linux-gnu/gstreamer-1.0/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/aarch64-linux-gnu/' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LIBCAMERA_IPA_MODULE_PATH=/usr/local/lib/aarch64-linux-gnu/libcamera/ipa' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo 'export LIBCAMERA_IPA_CONFIG_PATH=/usr/local/share/libcamera/ipa' >> ${ROOTFS_DIR}/home/pollen/.bashrc
echo "GStreamer plugins installed."

echo "Setting up udev rules for respeaker mic array..."
cp files/99-respeaker.rules ${ROOTFS_DIR}/etc/udev/rules.d/

echo "Enabling Git LFS for uv system-wide (issue #56)..."
# Login shells, PAM sessions, and user-scope systemd.
grep -qxF 'UV_GIT_LFS=1' "${ROOTFS_DIR}/etc/environment" \
    || echo 'UV_GIT_LFS=1' >> "${ROOTFS_DIR}/etc/environment"
# System-scope systemd services (reachy-mini-daemon et al. run as User=pollen
# at the system level and do NOT inherit /etc/environment).
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system.conf.d"
cat > "${ROOTFS_DIR}/etc/systemd/system.conf.d/10-uv-git-lfs.conf" <<'EOF'
# reachy-mini-os#56: make uv respect Git LFS in system services that invoke it.
[Manager]
DefaultEnvironment="UV_GIT_LFS=1"
EOF

echo "Installing WirePlumber bluez monitor override (issue #55)..."
install -d -m 0755 "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d"
install -m 0644 files/40-force-monitor-bluez.conf \
    "${ROOTFS_DIR}/etc/wireplumber/wireplumber.conf.d/40-force-monitor-bluez.conf"

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
    /bluetooth/commands/RESTART_DAEMON.sh, \
    /usr/bin/nmcli
pollen ALL=(root) NOPASSWD: REACHY
EOF
chmod 0440 "${ROOTFS_DIR}/etc/sudoers.d/010-pollen-reachy"
# Fail the build if the sudoers file is malformed (a bad file locks out sudo).
on_chroot <<- EOF
	visudo -cf /etc/sudoers.d/010-pollen-reachy
EOF

echo "Creating VERSION.txt file..."
# -f: the file only exists when re-running the stage on a cached rootfs
rm -f ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "ReachyMiniOS: dev" > ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "Created on: $(date '+%Y-%m-%d')" >> ${ROOTFS_DIR}/home/pollen/VERSION.txt
echo "VERSION.txt created."

echo "Installing verification script..."
cp files/reachyminios_check.sh ${ROOTFS_DIR}/usr/local/bin/reachyminios_check
chmod +x ${ROOTFS_DIR}/usr/local/bin/reachyminios_check

echo "Installating password configuration script..."
cp files/config_passwd.sh ${ROOTFS_DIR}/usr/local/bin/config_passwd
chmod +x ${ROOTFS_DIR}/usr/local/bin/config_passwd
