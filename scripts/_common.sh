# Shared helpers for the config scripts. Sourced, not run directly.
# Runs ON THE PI.

CONFIG_DIR="${CONFIG_DIR:-$HOME/printer_data/config}"
MOONRAKER="${MOONRAKER:-http://127.0.0.1:7125}"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mXX \033[0m %s\n' "$*" >&2; exit 1; }

# Refuse to touch the config while a print is running or paused.
# If Moonraker isn't answering we can't tell, so ask before going on.
require_idle() {
  local state
  state=$(curl -s --max-time 5 "$MOONRAKER/printer/objects/query?print_stats=state" \
          | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["status"]["print_stats"]["state"])' 2>/dev/null)
  case "$state" in
    printing|paused) die "Printer is $state. Finish or cancel the print first." ;;
    "") warn "Couldn't reach Moonraker to check for a running print."
        read -r -p "    Is the printer idle? Continue? [y/N] " a
        [[ "$a" =~ ^[Yy]$ ]] || die "Stopped." ;;
    *)  say "Printer state: $state (OK)" ;;
  esac
}

# Restart only the services whose config could have changed.
# Moonraker re-reads moonraker.conf only at startup; FIRMWARE_RESTART makes
# Klipper re-read printer.cfg and resets the Octopus so its pin setup matches.
restart_stack() {
  say "Restarting Moonraker..."
  sudo systemctl restart moonraker
  for i in $(seq 1 30); do
    curl -s --max-time 2 "$MOONRAKER/server/info" >/dev/null && break
    sleep 1
  done
  say "FIRMWARE_RESTART (Klipper re-reads the config)..."
  curl -s -X POST "$MOONRAKER/printer/firmware_restart" >/dev/null \
    || warn "Couldn't send FIRMWARE_RESTART. Run it from Mainsail."
  if systemctl list-unit-files | grep -q '^KlipperScreen\.service'; then
    say "Restarting KlipperScreen..."
    sudo systemctl restart KlipperScreen
  fi
}

# Wait for Klipper and report whether the config loaded.
report_klipper() {
  local st msg
  for i in $(seq 1 30); do
    st=$(curl -s --max-time 2 "$MOONRAKER/printer/info" \
         | python3 -c 'import sys,json; r=json.load(sys.stdin)["result"]; print(r["state"]+"|"+r["state_message"].splitlines()[0])' 2>/dev/null)
    [[ "$st" == ready* || "$st" == error* || "$st" == shutdown* ]] && break
    sleep 1
  done
  case "$st" in
    ready*) say "Klipper is ready." ;;
    "")     warn "Klipper didn't answer in 30 s. Check Mainsail." ;;
    *)      warn "Klipper: ${st#*|}"
            warn "Open Mainsail for the full error. To go back: switch-config.sh <other branch>" ;;
  esac
}
