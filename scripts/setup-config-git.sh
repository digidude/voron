#!/bin/bash
# ---------------------------------------------------------------------------
# setup-config-git.sh  —  ONE-TIME setup, run ON THE PI.
#
# Turns ~/printer_data/config into a git repo with two branches:
#   v1  = the config the printer runs today, exactly as it is
#   v2  = config_v2 installed on top (README install steps 2-5)
# It leaves the printer on v1. Nothing changes until you run
#   ~/scripts/switch-config.sh v2
#
# Before running, copy config_v2 and these scripts from the Mac:
#   scp -r ~/dev/voron/printer_data/config_v2 pi@<printer>:~/config_v2
#   scp -r ~/dev/voron/scripts               pi@<printer>:~/scripts
#
# Usage:  ~/scripts/setup-config-git.sh [path-to-config_v2]   (default ~/config_v2)
# ---------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/_common.sh"

V2_SRC="${1:-$HOME/config_v2}"

# ---- Checks ---------------------------------------------------------------
command -v git >/dev/null || die "git isn't installed:  sudo apt install git"
[[ -f "$CONFIG_DIR/printer.cfg" ]] || die "No printer.cfg in $CONFIG_DIR"
[[ -f "$V2_SRC/printer.cfg" ]]     || die "No config_v2 at $V2_SRC (see the scp line at the top of this script)"
[[ -e "$CONFIG_DIR/.git" ]]        && die "$CONFIG_DIR is already a git repo. Nothing to set up; use switch-config.sh."
require_idle

# ---- 1. Full backup outside the repo ---------------------------------------
BACKUP="$HOME/printer_data/config_backup_$(date +%F_%H%M)"
say "Backing up config to $BACKUP"
cp -a "$CONFIG_DIR" "$BACKUP"

cd "$CONFIG_DIR"

# ---- 2. Repo + v1 branch (today's config, untouched) -----------------------
say "Creating git repo with branch v1 (today's config)"
git init -q
git symbolic-ref HEAD refs/heads/v1
git config user.name  >/dev/null 2>&1 || git config user.name  "Voron Pi"
git config user.email >/dev/null 2>&1 || git config user.email "pi@voron.local"
cat > .gitignore <<'GI'
# Written by Klipper/Moonraker at runtime; not part of either config.
# Leading "/" = top folder only (v1 has a real active_config/community/variables.cfg).
/variables.cfg
/printer-2*.cfg
/.moonraker.conf.bkp
.DS_Store
GI
git add -A
git commit -qm "v1: original config as found on the Pi"

# ---- 3. v2 branch ----------------------------------------------------------
say "Creating branch v2 from $V2_SRC"
git checkout -q -b v2

# README step 2: archive the old layout (on v2 only; v1 still has it)
mkdir -p archive
for d in active_config deprecated_config proposed; do
  [[ -e "$d" ]] && git mv -k "$d" archive/ 2>/dev/null || true
done

# README step 3: copy in the new files (crowsnest.conf / sonar.conf untouched)
cp -a "$V2_SRC/printer.cfg" "$V2_SRC/moonraker.conf" "$V2_SRC/KlipperScreen.conf" .
for d in hardware macros experimental; do
  rm -rf "$d"; cp -a "$V2_SRC/$d" "$d"
done

# README step 4: save_variables file (Klipper won't start without it)
touch variables.cfg

# README step 5: mainsail-config include must match this Pi's username
if [[ "$USER" != "pi" ]]; then
  say "Pi user is '$USER', not 'pi': fixing the mainsail.cfg include path"
  sed -i "s#/home/pi/mainsail-config/#/home/$USER/mainsail-config/#" printer.cfg
fi
[[ -f "$HOME/mainsail-config/mainsail.cfg" ]] \
  || warn "$HOME/mainsail-config/mainsail.cfg not found. Install mainsail-config (KIAUH) before switching to v2."

git add -A
git commit -qm "v2: rebuilt config (config_v2 installed)"

# ---- 4. Back to v1 so nothing changes yet ----------------------------------
git checkout -q v1
touch variables.cfg   # harmless on v1, keeps the file around for v2

say "Done. Printer is still on v1 (no restart was needed)."
echo
echo "    Backup:        $BACKUP"
echo "    Compare:       cd $CONFIG_DIR && git diff --stat v1 v2"
echo "    Try v2:        ~/scripts/switch-config.sh v2"
echo "    Back to v1:    ~/scripts/switch-config.sh v1"
