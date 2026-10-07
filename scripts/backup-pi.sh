#!/bin/bash
# ---------------------------------------------------------------------------
# backup-pi.sh  —  run on the MAC. Read-only backup of the printer Pi.
#
#   ./scripts/backup-pi.sh [host]        (default: voron.local)
#   ./scripts/backup-pi.sh --dry-run     print what would run; don't connect
#
# Guarantees:
#   - Nothing is written to, installed on, or restarted on the Pi. The probe
#     (backup-pi.remote.sh) is piped over ssh stdin; the only other remote
#     command is `tar -c` to stdout. No sudo.
#   - A lint step refuses to connect if the probe contains a write-ish command.
#   - Unavoidable side effects of any ssh login: auth log / lastlog entries,
#     and file access times.
#
# Output (gitignored): backups/<host>-<timestamp>/
#   public/   system facts, boot files, nginx/udev, versions, MCU .config
#   private/  config tarball, Moonraker DB namespaces, secrets, env files
# Only public/ is a candidate for committing, and only after you've read it.
# ---------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
PROBE="$HERE/backup-pi.remote.sh"

DRY=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY=1; shift; fi
HOST="${1:-voron.local}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }

# ---- Lint: the probe must be read-only ------------------------------------
lint() {
  local body bad
  body=$(sed 's/#.*$//' "$PROBE" | sed -e 's#2>&1##g' -e 's#2>/dev/null##g' -e 's#>/dev/null##g')
  bad=$(printf '%s\n' "$body" | grep -nE '(^|[^[:alnum:]_-])(sudo|rm|mv|cp|chmod|chown|tee|dd|touch|mkdir|ln|kill|reboot|shutdown)([^[:alnum:]_-]|$)|systemctl[[:space:]]+(start|stop|restart|enable|disable|daemon)|git[[:space:]]+-C[[:space:]]+[^ ]+[[:space:]]+(pull|fetch|checkout|reset|status|clean|commit|gc)|(apt|apt-get|pip|pip3)[[:space:]]+(install|remove|upgrade)|curl[^|]*(-X|--request|-d|--data)|sed[[:space:]]+-i|>' || true)
  [[ -z "$bad" ]] || { printf '%s\n' "$bad" >&2; die "Probe has a write-ish command (above). Not connecting."; }
  say "Probe lint passed (read-only)."
}
lint

if (( DRY )); then
  say "Dry run. This is exactly what will be piped to $HOST:"
  cat "$PROBE"
  say "Plus: tar -c (to stdout) of ~/printer_data/{config,systemd,moonraker.secrets}"
  exit 0
fi

# ---- Run ------------------------------------------------------------------
DEST="$REPO/backups/${HOST}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST/public" "$DEST/private"
# Reuse an already-authenticated shared connection if one exists, e.g. started with
#   ssh -M -S ~/.ssh/cm-voron -fN voron.local
CTL="${SSH_CONTROL:-$HOME/.ssh/cm-voron}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10)
[[ -S "$CTL" ]] && SSH+=(-S "$CTL")
SSH+=("$HOST")

say "Connecting to $HOST (read-only)..."
"${SSH[@]}" true || die "Can't ssh to $HOST."

say "1/2 Probing system, versions, Moonraker (HTTP GET)..."
"${SSH[@]}" 'bash -s' < "$PROBE" \
  | awk -v out="$DEST" '
      /^##FILE /{ if (f) close(f); f = out "/" $2; d = f; sub(/\/[^\/]*$/, "", d);
                  system("mkdir -p \"" d "\""); next }
      f { print > f }'

say "2/2 Streaming config files (tar to stdout, nothing written on the Pi)..."
# Excludes Klipper's auto-backups (printer-20*.cfg). Missing optional paths are fine.
"${SSH[@]}" 'tar -czf - --ignore-failed-read --exclude="printer-20*.cfg" -C "$HOME/printer_data" config systemd moonraker.secrets' \
  > "$DEST/private/printer_data.tar.gz" 2>"$DEST/private/tar-warnings.txt" || true
tar -tzf "$DEST/private/printer_data.tar.gz" >/dev/null || die "Config tarball is unreadable."

say "Done: $DEST"
printf '    %s files in public/, %s in private/\n' \
  "$(find "$DEST/public" -type f | wc -l | tr -d ' ')" "$(find "$DEST/private" -type f | wc -l | tr -d ' ')"
echo "    Review public/ before committing anything. private/ never goes to git."
