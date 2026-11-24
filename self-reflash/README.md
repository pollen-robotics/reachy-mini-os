# Self-reflash (prototype)

Reflash a Reachy Mini Wireless (CM4, eMMC) with a new ReachyMiniOS image over
WiFi, without the USB/rpiboot procedure. Works on robots already in the field
(single rootfs, no A/B partitions): the robot rewrites its own eMMC from RAM.

## How it works

1. `reachy-os-upgrade.sh` (on the robot, as root):
   - checks it runs on a 4 GB CM4 booted from eMMC;
   - writes a plan to `/var/lib/reachy-os-upgrade/`:
     - the image URL (or a local zip) and its sha256 when given;
     - a `wpa_supplicant.conf` for the WiFi network the robot is on (open,
       WPA-PSK or SAE), so the flasher can download the image itself;
     - the list of state to carry over: all saved NetworkManager connections,
       SSH host keys and `authorized_keys`, robot name, HF tokens, pollen's
       password hash, and the HF model cache when it fits in RAM;
     - the installed apps, to reinstall from the app store on the new OS;
     - the current time (the board has no RTC, TLS needs a clock);
   - builds `reachy-flasher.img`, a ~15 MB initramfs made of this system's
     own binaries (busybox, Info-ZIP `unzip` for zip64, curl,
     wpa_supplicant), WiFi driver modules and firmware, and installs it on the
     boot partition with a `tryboot.txt` pointing at it;
   - `reboot '0 tryboot'`.
2. The firmware boots `tryboot.txt` **once**. `flasher-init.sh` runs from RAM:
   - copies the plan and the state to carry over into tmpfs, unmounts the old
     rootfs;
   - brings WiFi up and downloads the image zip into RAM (no free disk space
     needed), resuming on interruption;
   - checks sha256 and the zip CRC;
   - writes the image to `/dev/mmcblk0`, restores the saved state onto the
     new rootfs, installs a one-shot `reachy-restore-apps.service`, reboots.
3. First boot of the new image grows the rootfs (`rpi-resize`) as after a USB
   flash, reconnects to the saved WiFi, and `reachy-restore-apps.service`
   reinstalls the recorded apps through the daemon's app store API once the
   daemon and the internet are up, then disables itself.

The flasher log ends up in `/var/log/reachy-os-flasher.log` on whichever
rootfs is on the disk afterwards.

Tested on a robot, v1.0.0 → v1.0.0 over WiFi: ~7 min from reboot to new OS
(download 3 min, CRC check 1.5 min, write 2 min); WiFi networks, robot name,
HF tokens and cache, SSH keys kept; apps reinstalled on first boot.

## Failure modes

- Anything failing **before** the write (no WiFi, download error, bad
  checksum, corrupt zip): the flasher reboots, and since tryboot is one-shot,
  the old OS boots unchanged.
- Power loss **during** the write (~2 min): the robot no longer boots and
  needs the usual USB reflash, i.e. no worse than today.
- systemd leaves the hardware watchdog armed across reboot
  (`RebootWatchdogSec=2min`); the flasher keeps feeding it.

## Testing

```bash
sudo ./reachy-os-upgrade.sh --dry-run <zip URL>
```

`--dry-run` does everything up to the write (WiFi, download, checks) and
reboots into the old OS; check `/var/log/reachy-os-flasher.log` for
`DRY RUN OK`.

## Not covered yet

- Who triggers it: the plan is an "Update OS" action in the daemon. The script
  needs root, and v1.0.x images only give pollen a scoped sudoers list, so the
  owner has to authorize the privileged step (or the image has to ship a
  sudoers rule for this script).
- Release images should publish a `.sha256` so the download is checked
  against a value from CI.
- WPA-Enterprise networks; apps not in the app store (private or local) are
  not reinstalled.
- Longer term, this is the one-time migration path to an A/B layout with a
  real update framework (e.g. RAUC), where a power cut during an update no
  longer matters.
