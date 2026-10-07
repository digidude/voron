#!/bin/bash
# ---------------------------------------------------------------------------
# backup-pi.remote.sh  —  READ-ONLY probe. Piped to the Pi over ssh stdin by
# backup-pi.sh; never copied to or stored on the Pi.
#
# Allowed here: cat, ls, grep, curl GET, git rev-parse / config --get, crontab -l,
# systemctl list-*, apt-mark showmanual, uname, lsusb. No sudo, no writes.
# backup-pi.sh lints this file for anything else before it connects.
#
# Output is one text stream; "##FILE <path>" lines mark where each file starts.
# Paths starting public/ are safe to commit; private/ may hold secrets.
# ---------------------------------------------------------------------------
export PYTHONDONTWRITEBYTECODE=1
H="$HOME"
API="http://127.0.0.1:7125"

emit() { printf '##FILE %s\n' "$1"; shift; "$@" 2>&1; echo; }

# ---- System ---------------------------------------------------------------
emit public/system/os-release.txt   cat /etc/os-release
emit public/system/uname.txt        uname -a
emit public/system/hostname.txt     cat /etc/hostname
emit public/system/serial-by-id.txt ls -l /dev/serial/by-id /dev/serial/by-path /dev/v4l/by-id
emit public/system/lsusb.txt        lsusb
emit public/system/enabled-services.txt systemctl list-unit-files --state=enabled
emit public/system/apt-manual.txt   apt-mark showmanual
emit public/system/crontab.txt      crontab -l

for f in /boot/firmware/config.txt /boot/firmware/cmdline.txt /boot/config.txt /boot/cmdline.txt; do
  [ -f "$f" ] && emit "public/boot${f#/boot}" cat "$f"
done
for f in /etc/nginx/sites-available/* /etc/nginx/conf.d/* /etc/udev/rules.d/*.rules /etc/X11/xorg.conf.d/*; do
  [ -f "$f" ] && emit "public${f}" cat "$f"
done

# ---- Component versions (pins for a rebuild) -------------------------------
printf '##FILE public/versions.txt\n'
echo "# name  commit  branch  origin"
for d in klipper moonraker mainsail-config KlipperScreen crowsnest sonar beacon_klipper klipper-led_effect katapult kiauh; do
  p="$H/$d"
  [ -d "$p/.git" ] || continue
  echo "$d $(git -C "$p" rev-parse HEAD) $(git -C "$p" rev-parse --abbrev-ref HEAD) $(git -C "$p" config --get remote.origin.url)"
done
echo "mainsail $(cat "$H/mainsail/.version" 2>/dev/null)"
echo
echo "# Klipper extras that are symlinks or non-stock (e.g. beacon.py)"
find "$H/klipper/klippy/extras" -maxdepth 1 -type l -exec readlink -f {} +
echo

# ---- MCU build config ------------------------------------------------------
emit public/klipper.config cat "$H/klipper/.config"

# ---- Moonraker / Klipper runtime (HTTP GET only) ---------------------------
emit public/api/printer-info.json  curl -s --max-time 5 "$API/printer/info"
emit public/api/server-info.json   curl -s --max-time 5 "$API/server/info"
emit public/api/system-info.json   curl -s --max-time 5 "$API/machine/system_info"
emit private/api/history-totals.json curl -s --max-time 5 "$API/server/history/totals"

# Moonraker database: Mainsail UI settings, macro groups, webcams, etc.
# Read through the API instead of copying the LMDB files (which would be torn
# while Moonraker runs, and the /backup endpoint would write on the Pi).
for ns in $(curl -s --max-time 5 "$API/server/database/list" \
            | python3 -c 'import sys,json; print(" ".join(json.load(sys.stdin)["result"]["namespaces"]))' 2>/dev/null); do
  emit "private/database/$ns.json" curl -s --max-time 10 "$API/server/database/item?namespace=$ns"
done

# ---- Small private files ---------------------------------------------------
emit private/systemd-env.txt sh -c 'for f in "$HOME"/printer_data/systemd/*; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done'
