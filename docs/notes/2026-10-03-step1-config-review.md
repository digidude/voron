# Voron 2.4 config review (Step 1) — 2026-10-03

Scope: `printer_data/config/printer.cfg` + everything it includes under `active_config/`, `moonraker.conf`, plus the most recent Orca gcode (`carriage_mount_ASA_29m47s.gcode`, ASA, 250/105, relative E). Recommendations only — nothing modified.

## A. Likely contributors to first-layer peeling (fix first)

1. **Exhaust fan runs 100% whenever bed > 60 °C** (`fans.cfg` `[heater_fan exhaust_fan]`, fan_speed 1.0). For ASA/ABS this dumps chamber heat during the whole print -> cold chamber, warping, corners lifting. Change to a `[fan_generic exhaust_fan]` controlled by macro/slicer (off or low for the first layers), or at minimum `fan_speed: 0.3`.
2. **No chamber heat soak.** PRINT_START waits for bed temp only, then goes straight to leveling. ASA on a 250 needs ~10–20 min soak (or chamber thermistor + `TEMPERATURE_WAIT`). Without it, the first layer goes down on a bed whose edges / frame are still moving.
3. **Purge-sequence filament math leaves the nozzle starved at print start.** Slicer uses relative E (M83), and `_TEMP_BUCKET_PURGE` also forces M83. Net sequence: +20 purge, **-10** retract, then `_PURGE_CLEAN` **-5** more, then `_PURGE_LINE` +11 prime -> still ~4 mm retracted when the line starts, then +15 / +30, then -0.2. 15 mm of retract at 250 °C with dwells (3 s, 3 s, 5 s) risks heat creep and an underfed first few cm. Reduce bucket retract to ~0.5–1 mm, drop the extra `G1 E-5`, and rewrite `_PURGE_LINE` explicitly for relative E.
4. **`SET_GCODE_OFFSET Z=0.04` hard-coded in PRINT_START** lifts the nozzle 0.04 mm on top of Beacon contact homing (done at 150 °C). Probably meant as hot-nozzle expansion compensation, but it's a blind number and reduces squish. Verify with a first-layer test + live babystepping and put the result in a variable; also look at Beacon's own hot-nozzle expansion compensation instead of a manual offset.
5. **Orca filament flow ratio 0.926** on that ASA profile (and initial line width 0.5). Low first-layer flow + the lift above = thin, poorly bonded first layer. Calibrate flow; consider 1.0 on layer 1.

## B. Errors / safety

- `extruder min_temp: -200`, `heater_bed min_temp: -250`, `min_extrude_temp: 0` — removes thermistor-fault and cold-extrusion protection. Use `min_temp: 0` (or 10) and `min_extrude_temp: 170`.
- `params.BED|int` / `params.HOTEND|int` have no defaults — a manual `PRINT_START` without params silently uses 0.
- `_TEMP_BUCKET_PURGE` uses `M83 E` (stray param) and never restores mode — harmless with Orca relative E, broken if any slicer/profile uses absolute E.
- `SAVE_CONFIG` block has `[stepper_z] position_endstop = 0.572` while Z uses the Beacon virtual endstop — stale leftover; confirm Klipper isn't warning about it.
- `controller_fan` is a `heater_fan` tied to the bed (>45 °C) — drivers/Pi get no airflow on cold prints. Use `[controller_fan]` (on when steppers enabled).
- `moonraker.conf`: telegram bot entry still "TODO", uses `/home/pi/...` while others use `~` — remove if not installed (stops update-manager errors). Beacon updater on `channel: dev`; consider `stable`.

## C. Redundancy that costs time (feeds Step 2)

PRINT_START does: G28 (contact + autocalibrate) -> G32 (BED_MESH_CLEAR, **G28**, QGL, **G28**) -> wipe -> `G28 Z CONTACT CALIBRATE=1` -> full 9x9 mesh -> 3 wipes -> `G28 Z CONTACT` -> move to Z40, heat hotend 150->250 -> 2 wipes -> bucket purge (11 s of dwells) -> 3 more wipes -> purge line.
- 4 full/Z homes + 2 contact homes; `CALIBRATE=1` duplicates `home_autocalibrate: unhomed`.
- G32's leading G28 is redundant (already homed); only Z re-home is needed after QGL.
- Hotend heats only after all probing — could preheat to 150 earlier (already done) and overlap more of the final heat.
- Mesh is `ADAPTIVE=0` though comment says adaptive; `exclude_object` and Orca labels are already set up, so `ADAPTIVE=1` works.
- QGL `speed: 400` > `max_velocity: 300` (clamped, cosmetic).
- Bed `max_power: 0.6` is the Voron default for heater sizing — a big part of heat time; leave unless heater/SSR rating allows more.

## D. Housekeeping

- `active_config/mainsail.cfg` is a copy of `~/mainsail-config/mainsail.cfg`; include the repo file (or symlink) so updates apply.
- `_CG32` / `_CQGL` only home; never QGL/mesh conditionally — either finish or delete.
- `CLEAN_NOZZLE`, `CLEAN_NOZZLE_WIPES`, `dynamic_clean` are three near-duplicates; keep one with a WIPES param.
- `PRINT_START_temp` and ~25 timestamped `printer-2024*.cfg` backups clutter the config dir; move to an archive folder.
- `G32`, PRINT_START comments stale ("80%", "adaptive").
