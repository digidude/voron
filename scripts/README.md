# scripts/ — run these ON THE PI

Switch the printer between the original config (**v1**) and the rebuilt one (**v2**) with one command. Both live as git branches in `~/printer_data/config`.

| Script | When | What it does |
|---|---|---|
| `setup-config-git.sh` | Once | Backs up the config, makes it a git repo, commits today's config as branch `v1`, installs config_v2 as branch `v2`, leaves the printer on **v1** |
| `switch-config.sh v1\|v2` | Any time the printer is idle | Saves SAVE_CONFIG changes on the current branch, switches, restarts Moonraker + FIRMWARE_RESTART + KlipperScreen, reports whether Klipper is ready |
| `switch-config.sh` | Any time | Shows which config is active |
| `_common.sh` | — | Shared helpers (idle check, restarts) |

## First time

From the Mac:
```bash
scp -r ~/dev/voron/printer_data/config_v2 pi@<printer>:~/config_v2
scp -r ~/dev/voron/scripts               pi@<printer>:~/scripts
```
On the Pi (SSH):
```bash
chmod +x ~/scripts/*.sh
~/scripts/setup-config-git.sh      # printer stays on v1
~/scripts/switch-config.sh v2      # try v2
~/scripts/switch-config.sh v1      # go back any time
```

## Safety built in
- Refuses to run while a print is running or paused.
- `setup` refuses if the config folder is already a git repo, and makes a full copy to `~/printer_data/config_backup_<date>` first.
- If the Pi user isn't `pi`, `setup` fixes v2's `mainsail-config` include path.
- Nothing is deleted: v2's branch moves `active_config/` and `deprecated_config/` into `archive/`; v1 still has them in place.

## Things to know
- **SAVE_CONFIG results stay with their branch.** PID, Beacon model or mesh saved on v2 doesn't show up on v1.
- **First-layer Z offset is in different places:** v1 hard-codes `SET_GCODE_OFFSET Z=0.04` in `active_config/system/start_stop.cfg`; v2 uses `variable_z_hot_offset` in `macros/print_start_end.cfg`.
- **Mainsail macro groups** are stored in Mainsail, not the config. Groups made for v2 names show missing buttons on v1.
- **Orca needs no change.** Both accept `PRINT_START HOTEND=… BED=…`.
- Compare the two: `cd ~/printer_data/config && git diff v1 v2`

## Tested
In a simulated Pi home folder (Moonraker/systemctl stubbed): setup, v1→v2→v1, auto-save of a SAVE_CONFIG change, refusal while printing, unknown branch, re-running setup, non-`pi` username. After setup and after switching back, v1 is byte-identical to the original config; v2 is identical to `config_v2/`. Not yet run on the real Pi.
