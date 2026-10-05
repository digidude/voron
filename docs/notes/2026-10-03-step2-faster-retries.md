# Step 2 — faster retries: draft files (2026-10-03)

All drafts live in `printer_data/config/proposed/`. Nothing in the live config was changed or included. **Superseded by `printer_data/config_v2/`.**

## start_stop_v2.cfg — PRINT_START / PRINT_END
Drop-in replacement for `active_config/system/start_stop.cfg`; same macro names, same Orca start gcode.
- Bed + hotend(150) heat in parallel with initial G28.
- Retry-aware: if still homed + QGL applied + bed within 15 C of target -> skip G28, QGL, soak. `FULL=1` forces everything.
- Soak: auto 10 min when BED >= 90 on first attempt; `SOAK=<min>` overrides.
- One contact Z home at controlled 140-160 C nozzle, after a 2-pass wipe. Adaptive mesh (`MESH=0` to skip).
- Final heat over bucket; 15 mm prime, 0.5 mm retract; relative-E purge line (E14 + E10).
- `z_hot_offset` kept at 0.04 (old behavior) as a variable to tune.
- `_PS_MARK` prints elapsed seconds per phase ("PS: ...").
- PRINT_END: retract 10 -> 2 mm; calls `_EXHAUST MODE=end` if installed.
- Calls `_KEEP_HOT_ARM` and `_EXHAUST` only if those files are installed (independent install).

## cancel_keep_hot.cfg — cancel leaves printer ready to retry
- Uses Mainsail `_CLIENT_VARIABLE`: park at cancel over bucket (120,250), cancel retract 5 -> 1 mm, `user_cancel_macro: _KEEP_HOT`.
- `_KEEP_HOT` re-heats bed to last print temp + nozzle to 150 for 15 min, then `_KEEP_HOT_OFF` turns heaters off.
- `COOLDOWN` (heaters off + cancel timer), `KEEP_HOT ENABLE=0|1 MINUTES=n`.
- Caveat: any error-triggered cancel (virtual_sdcard on_error_gcode) also keeps heat for 15 min.

## exhaust_fan_v2.cfg — exhaust fan under macro control
- Replaces `[heater_fan exhaust_fan]` (100% when bed > 60 C) with `[fan_generic exhaust_fan]` on PD13. Old section must be deleted from fans.cfg.
- ABS/ASA (bed >= 90): off while printing. PLA/PETG: 60%. PRINT_END: 100% for 5 min then off.

## Still open (at the time)
- Safety limits (min_temp / min_extrude_temp) in extruder_bed.cfg.
- controller_fan -> `[controller_fan]`.
- Tune z_hot_offset and Orca first-layer flow (0.926).
