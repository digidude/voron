# config_v2 — full replacement config (2026-10-03 / 2026-10-04)

Location: `printer_data/config_v2/` (README.md inside has install, rollback, full change list). Supersedes the earlier drafts in `printer_data/config/proposed/`.

Validation: loaded and run in Klipper batch mode at the Pi's exact Klipper version (v0.13.0-419-g2e5802370) with an STM32F446 dictionary; no config errors or deprecation warnings; all macros executed (print, cancel, retry, PRINT_END, G32, M600/RESUME, utilities). [beacon] was stubbed with [probe] for the simulation; Beacon option names verified against the installed beacon.py (v2.0.0-23). Real heating/probing/timing untested. Note: `klipper/out/klipper.dict` on the Mac is a stale AVR build; build a fresh STM32F446 dict for simulation.

Key decisions:
- Baseline: official Voron 2.4 Octopus layout + Beacon contact docs; not Klippain (last release v4.4.0-beta.1, June 2024).
- Mainsail macros included from /home/pi/mainsail-config/mainsail.cfg (verify Pi username).
- Exhaust fan -> fan_generic + _EXHAUST policy; controller fan -> [controller_fan].
- PRINT_START: retry-aware, hot-bed Beacon CALIBRATE=1 before QGL, contact Z after wipe, adaptive 15x15 mesh, z_hot_offset 0.04 (Beacon suggests ~0.06 start).
- Cancel keeps bed/150C nozzle for 15 min; motors stay on after PRINT_END; idle_timeout 1800. Keep-hot is automatic on Mainsail/KlipperScreen/Orca cancel (via _CLIENT_VARIABLE user_cancel_macro); retry = reprint within 15 min.
- Safety limits fixed (min_temp 0, min_extrude_temp 170).
- resonance_tester uses Beacon accelerometer; RP2040 ADXL kept as disabled file.

## Macro cleanup (2026-10-04)
- Convention: UPPER_CASE = user button; `_` prefix = hidden helper/console tool; prefixes CAL_, LIGHTS_, NOZZLE_, PARK_.
- Hidden: `_status_*` (11), `_set_logo_leds_off`, `_set_nozzle_leds_on/off`, `_DUMP_VARIABLES`, `_GET_VARIABLE`.
- Renamed: LIGHTS_CASE_WHITE/OFF/NIGHT; CAL_PID_EXTRUDER, CAL_PID_BED, CAL_INPUT_SHAPER (was SHAPER_CALIBRATE_ALL), CAL_BEACON_HOT, CAL_FIRST_LAYER; NOZZLE_CLEAN, NOZZLE_PRIME (was BUCKET_PRIME), NOZZLE_PURGE_LINE.
- Kept standard names: PRINT_START/END, G32, M600, LOAD_/UNLOAD_FILAMENT (Mainsail/KlipperScreen buttons), PAUSE/RESUME/CANCEL_PRINT.
- experimental/demo_motion_macros.cfg -> .cfg.disabled (empty experimental glob is OK in Klipper).
- Visible macros 45 -> 28 (29 with VIEW_VARIABLES). Re-simulated: all renamed macros run; old names return Unknown command.
- Mainsail macro groups (Print / Prep / Toolhead / Calibration / Lights / Learn) are a manual UI step — layout in config_v2/README.md.

## View Variables (2026-10-04)
- `VIEW_VARIABLES` (macros/debug.cfg): SHOW=tunables (default; list in `_VIEW_TUNABLES.variable_macros`), SHOW=state (homed/QGL/mesh/temps/offset + predicts RETRY vs FULL PRINT_START with reason), NAME= (-> _DUMP_VARIABLES), PATH= (-> _GET_VARIABLE). Read-only.
- New `config_v2/KlipperScreen.conf`: "View Variables" submenu in both __main and __print (My Settings / Printer State / Open Console); auto-generated block from the old file preserved. Verified with KlipperScreen's own config loader.
- Simulated in Klipper: all modes, cold / after PRINT_START / after cancel / after COOLDOWN.

Open items: chamber thermistor, BeaconPrinterTools thermal expansion calibration, Orca flow ratio (0.926) + brim, first supervised test on the Pi, Pi undervoltage/throttling warnings (power supply).
