# Runbook: set up v1/v2 config branches on the Pi

Date: 2026-10-07. Status: **not yet run on the Pi** (as of this note). Everything marked "changes the Pi" needs the owner's OK first.

Result: `~/printer_data/config` becomes a local git repo with branch `v1` (current config, untouched) and `v2` (`config_v2` installed). `switch-config.sh` flips between them. Setup leaves the printer on v1 and restarts nothing.

## Preflight (read-only, checked 2026-10-07)

| Check | Result |
|---|---|
| `git`, `curl`, `python3` on Pi | present |
| `~/mainsail-config/mainsail.cfg` (v2 includes it) | present |
| Printer state | standby |
| Disk | 44 GB free |
| KlipperScreen service | present |
| `~/config_v2`, `~/scripts` | absent: copy first |
| `sudo` | needs a password, so switching must be from an interactive SSH login |

## Steps

1. **Copy from the Mac** (changes the Pi: adds two new folders):
   ```bash
   scp -r ~/dev/voron/printer_data/config_v2 pi@voron.local:~/config_v2
   scp -r ~/dev/voron/scripts               pi@voron.local:~/scripts
   ```
2. **Log in interactively:**
   ```bash
   ssh pi@voron.local
   chmod +x ~/scripts/*.sh
   ```
3. **Run setup** (changes the Pi: backs up and `git init`s the config; printer stays on v1):
   ```bash
   ~/scripts/setup-config-git.sh
   ```
   Backup goes to `~/printer_data/config_backup_<date>`.
4. **Verify nothing changed on v1:**
   ```bash
   cd ~/printer_data/config
   git branch                # v1 (active), v2
   git status --short        # empty
   git diff --stat v1 v2
   ```
5. **Switch to v2** (printer idle; prompts for sudo password; restarts Moonraker, FIRMWARE_RESTART, KlipperScreen):
   ```bash
   ~/scripts/switch-config.sh v2
   ```
6. **Switch back any time:**
   ```bash
   ~/scripts/switch-config.sh v1
   ~/scripts/switch-config.sh        # show active branch
   ```

## After the first switch to v2, check in Mainsail
- Klipper state is ready; Beacon connected
- Heater, fan and temperature readings look sane
- v2 has no SAVE_CONFIG block: redo PID, Beacon model, and bed mesh on v2. They do not carry over from v1.

## Rollback
`switch-config.sh v1`. Fallback: the `config_backup_<date>` folder from step 3.

## Gotchas
- SAVE_CONFIG results stay on the branch that produced them.
- `variables.cfg` is gitignored and shared by both branches.
- The first real run of the switch scripts: earlier tests used stubs only.
- If Moonraker or Klipper doesn't answer after a switch, open Mainsail for the error, then switch back.

## Related
- `scripts/README.md`: script reference
- `scripts/backup-pi.sh`: read-only backup from the Mac (output in gitignored `backups/`)
- `docs/pi-snapshot/`: non-secret snapshot of the Pi's system state (2026-10-07)
- `2026-10-07-v1-vs-v2-and-orca-first-layer.md`: what differs between v1 and v2
