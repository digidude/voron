# Voron 2.4 — config_v2

This is a clean rebuild of the Klipper config. The layout follows the official Voron 2.4 / BTT Octopus reference config, and the probing sequence follows Beacon's documentation. All machine-specific values are carried over from your old config. Drafted 2026-10-03.

## Related

- **Handoff Guide** (overview, decisions, and the results log for test prints): https://claude.ai/artifact/BYiP8vtwQ9XhrJBHuGidYb
- **Orca Slicer from Scratch** (slicer setup to pair with this config): https://claude.ai/artifact/4QghdcxjAcYA2dbD4WtgKx
- **Test prints**: `voron/test_prints/README.md` on the Mac copy (`../../test_prints/` from here). 10 calibration steps in order, STLs included. These stay on the Mac; they don't get copied to the Pi.
- **History:** `config/proposed/` held the first Step 2 drafts (PRINT_START, keep-hot, exhaust). All of that is folded into this folder; `proposed/` is kept only for reference. `config/deprecated_config/` and `config/active_config/` are the original files from the Pi; see Install step 2.

## How it was checked

- **Real Klipper, simulated printer.** The config was loaded by the same Klipper version as your Pi (v0.13.0-419) in batch mode, using an STM32F446 build of the firmware. Klipper accepted every section with no errors or deprecation warnings. Every macro ran to completion, including a simulated print, a cancel, a retry, PRINT_END, G32, M600/RESUME and the utility macros.
- **Beacon, by hand instead.** The `[beacon]` section can't be loaded without the physical Beacon attached, so the simulation used a stand-in probe. Every Beacon option name was checked against your installed `beacon.py` instead.
- **Not tested:** real temperatures, real probing and timings. The first real run is still a supervised test.

## File layout

```
printer.cfg                 includes + [mcu] [printer] input shaper, idle timeout, SAVE_CONFIG block
hardware/
  motors.cfg                X/Y/Z steppers + TMC2209 drivers
  extruder.cfg              Clockwork 2 + hotend heater
  bed.cfg                   bed heater
  beacon.cfg                Beacon, QGL, bed mesh, resonance tester
  fans.cfg                  all fans + _EXHAUST policy
  leds.cfg                  case lights + Stealthburner LEDs + hidden _status_ macros
  sensors.cfg               Octopus/Pi temps + chamber thermistor template
macros/
  print_start_end.cfg       PRINT_START (retry-aware) / PRINT_END
  cancel_keep_hot.cfg       cancel = park + keep warm 15 min
  nozzle_clean.cfg          NOZZLE_CLEAN, NOZZLE_PRIME, NOZZLE_PURGE_LINE
  utility.cfg               G32, PARK_*, PREHEAT, COOLDOWN, LOAD/UNLOAD, M600
  calibration.cfg           CAL_PID_*, CAL_INPUT_SHAPER, CAL_BEACON_HOT, CAL_FIRST_LAYER
  debug.cfg                 VIEW_VARIABLES (+ _DUMP_VARIABLES, _GET_VARIABLE)
experimental/               auto-included playground (*.cfg)
moonraker.conf              cleaned up
```

## Install (on the Pi)

1. **Back up the current config.**
   `cp -r ~/printer_data/config ~/printer_data/config_backup_$(date +%F)`
2. **Archive the clutter.** Move the 25 `printer-2024*.cfg` / `printer-2025*.cfg` backups, `active_config/` and `deprecated_config/` into a folder named `archive/`. Klipper ignores any file that nothing includes, so this is only for tidiness.
3. **Copy in the new files.** Copy everything from `config_v2/` into `~/printer_data/config/`: `printer.cfg`, `hardware/`, `macros/`, `experimental/` and `moonraker.conf`. Also copy the new `KlipperScreen.conf` (adds the View Variables menu; your existing settings are preserved at the bottom). Keep your existing `crowsnest.conf` and `sonar.conf`; they're unchanged.
4. **Create the save-variables file.** Klipper won't start without it: `touch ~/printer_data/config/variables.cfg`
5. **Check the Pi username.** The first include in `printer.cfg` assumes it's `pi`: `/home/pi/mainsail-config/mainsail.cfg`. If it isn't, fix that path.
6. **Restart.** Restart Moonraker, then run `FIRMWARE_RESTART` from Mainsail.
7. **First test, supervised.** Home, run `G32`, then a small PLA print (dial in with PLA first). Watch the `PS:` lines in the console.

**Rollback:** copy the backup folder back and run `FIRMWARE_RESTART`.

## What changed, and why

### Fixes

| Where | Change | Why |
|---|---|---|
| extruder.cfg | `min_temp` -200 → 0, `min_extrude_temp` 0 → 170 | Restores thermistor-fault and cold-extrusion protection |
| bed.cfg | `min_temp` -250 → 0 | Same |
| fans.cfg | Exhaust: 100%-when-bed-hot → macro controlled. Off for ABS/ASA, 60% for PLA, 5 minutes at 100% after a print | It was pulling heat out of the chamber, a likely cause of corners lifting |
| fans.cfg | Controller fan follows motors and heaters, not the bed | Drivers and Pi had no airflow on cold-bed jobs |
| nozzle_clean.cfg | Purge rewritten for relative extrusion. Retracts cut from 15 mm to 0.5 mm, pauses from 11 s to 1 s | The old purge started the line under-primed; long retracts at print temperature risk heat creep |
| print_start_end.cfg | PRINT_END parks at least 10 mm above the part | The old fixed Z50 would drive the nozzle *into* parts taller than 50 mm |
| print_start_end.cfg | Defaults for BED/HOTEND | Running PRINT_START by hand without values used 0°C |
| printer.cfg | Mainsail macros included from the `mainsail-config` repo | Your copy wasn't getting updates |
| beacon.cfg | QGL speed 400 → 300 | It was being silently capped at max_velocity |

### Speed (faster attempts and retries)

- **PRINT_START** heats the bed and nozzle while homing. It homes Z with contact once, plus one calibration on the hot bed, instead of 4–6 homes. The mesh is adaptive (only where parts are).
- **Retry mode.** If the printer is still homed, levelled and the bed is within 15°C of target, PRINT_START skips homing, QGL and the soak. Add `FULL=1` to force everything.
- **Keep warm on cancel.** A cancel parks over the bucket, retracts 1 mm, and keeps the bed at print temperature and the nozzle at 150°C for 15 minutes.
- **Motors stay on after PRINT_END,** so the next print can skip homing and QGL. `idle_timeout` turns them off after 30 minutes.
- **Time per step.** `PS: <step> @ Ns` lines show where the time goes.
- **G32** re-homes only Z after QGL.

### Quality

- **Heat soak:** 10 minutes automatically for beds at 90°C and above. A chamber-temperature wait takes over if you add a chamber thermistor.
- **Beacon calibration on the hot bed** before QGL, as Beacon's docs recommend.
- **Nozzle expansion offset:** `z_hot_offset` (default 0.04; Beacon suggests about 0.06 as a start) is a single setting to tune.
- **Mesh:** 15×15 points (scanning, so almost no extra time). `zero_reference_position` matches the Beacon home spot.

### New nice-to-haves (all optional)

- **Printer config:** `[gcode_arcs]` (for Orca arc fitting) and `[save_variables]` (persistent macro values).
- **Temperature readouts:** Octopus MCU and Pi CPU temperatures in Mainsail.
- **Chamber thermistor:** template included. Recommended ~$2 upgrade.
- **Input shaper:** `[resonance_tester]` uses Beacon's built-in accelerometer. Your old RP2040/ADXL board is kept as `experimental/adxl_rp2040.cfg.disabled`.
- **Utility macros:** `PREHEAT`, `COOLDOWN`, `KEEP_HOT`, `PARK_FRONT`, `LOAD_FILAMENT`, `UNLOAD_FILAMENT`, `M600`.
- **Calibration macros:** `CAL_PID_EXTRUDER`, `CAL_PID_BED`, `CAL_INPUT_SHAPER`, `CAL_BEACON_HOT`, `CAL_FIRST_LAYER`.
- **Case lights:** the macros are one-line `SET_LED` calls now.
- **moonraker.conf:**
  - Object processing on.
  - Beacon updates on the `stable` channel.
  - Removed the unused Telegram and LED-effect updater entries (notes inside if you want them back).

### Removed

- `PRINT_START_temp`, `_CG32`, `_CQGL`, `dads_sandbox` (it was never included anyway).
- Seven duplicate purge/clean macros, now three.
- The `klipperScreen.cfg` include. It only held KlipperScreen's own settings, which live in `KlipperScreen.conf`.

### Carried over unchanged (machine-specific)

- **Wiring and Beacon:** all pins, the Beacon serial number, the Beacon Y offset of 25, and the MCU on `/dev/ttyAMA0`.
- **Motion:** motor currents, endstop positions, axis limits and Z gear ratio.
- **Extruder:** `rotation_distance` 22.1 with 50:10 gearing, and pressure advance 0.04.
- **Tuning results:** input shaper (ei 65.2 / mzv 41.8), and the entire SAVE_CONFIG block (PID values, Beacon model, saved mesh).
- **Peripherals:** brush, bucket and purge positions, fan pins, LED colours.

## Macro cleanup (2026-10-04)

Goal: a tidy Mainsail Macros panel. Backup of the pre-cleanup files: `printer_data/config_v2.bak-2026-10-04-pre-macro-cleanup/`.

**Naming convention** (also documented at the top of the macro includes in `printer.cfg`):

- `UPPER_CASE` = a command you run by hand; shows as a button.
- `_anything` = internal helper or console tool; Mainsail hides it.
- Prefixes so related buttons sort together: `CAL_*`, `LIGHTS_*`, `NOZZLE_*`, `PARK_*`.
- Left alone on purpose because other tools look for these names: `PRINT_START`/`PRINT_END` (Orca), `G32`, `M600`, `LOAD_FILAMENT`/`UNLOAD_FILAMENT` (Mainsail and KlipperScreen load/unload buttons), `PAUSE`/`RESUME`/`CANCEL_PRINT` (Mainsail).

**Renames**

| Old | New | Why |
|---|---|---|
| `status_*` (11 macros) | `_status_*` | Internal LED helpers; hidden |
| `set_logo_leds_off`, `set_nozzle_leds_on/off` | `_set_...` | Internal LED helpers; hidden |
| `DUMP_VARIABLES`, `GET_VARIABLE` | `_DUMP_VARIABLES`, `_GET_VARIABLE` | Console tools; hidden but still autocomplete in the console |
| `CASE_LIGHTS_WHITE/OFF/NIGHT` | `LIGHTS_CASE_WHITE/OFF/NIGHT` | Prefix grouping |
| `PID_EXTRUDER`, `PID_BED` | `CAL_PID_EXTRUDER`, `CAL_PID_BED` | Prefix grouping |
| `SHAPER_CALIBRATE_ALL` | `CAL_INPUT_SHAPER` | Prefix grouping |
| `BEACON_CALIBRATE_HOT` | `CAL_BEACON_HOT` | Prefix grouping |
| `FIRST_LAYER_CHECK` | `CAL_FIRST_LAYER` | Prefix grouping |
| `CLEAN_NOZZLE`, `BUCKET_PRIME`, `PURGE_LINE` | `NOZZLE_CLEAN`, `NOZZLE_PRIME`, `NOZZLE_PURGE_LINE` | Prefix grouping |
| `fast_motion_demo` | (disabled) | `experimental/demo_motion_macros.cfg` renamed to `.cfg.disabled` |

All internal calls were updated. Every visible macro has a `description:`. Re-tested in the Klipper simulator (same Klipper version, STM32F446 dictionary, Beacon stubbed out because it needs its own MCU): G32, PRINT_START (full and retry), PRINT_END, CANCEL_PRINT + keep-hot, every renamed macro, and the debug tools all ran with no unknown-command or template errors. The old names correctly come back as "Unknown command".

**Result:** 28 visible macros (22 of ours + 6 from Mainsail), down from 45 (29 with VIEW_VARIABLES, added later). The groups below show only the ones that make sense for what the printer is doing.

### Mainsail macro groups (do this in the Mainsail UI)

Mainsail stores groups in its own database, not in the Klipper config, so this step is manual. Go to **Settings → Macros**, switch **Management** to **Expert**, then add these groups. In Expert mode, a macro that isn't in any group doesn't appear on the dashboard, which is how `PRINT_START`, `PRINT_END` and `SET_PRINT_STATS_INFO` stay off it (Orca calls those).

| Group | Show when | Macros |
|---|---|---|
| **Print** | printing, paused | PAUSE, RESUME, CANCEL_PRINT, M600, SET_PAUSE_NEXT_LAYER, SET_PAUSE_AT_LAYER |
| **Prep** | standby | PREHEAT, COOLDOWN, G32, KEEP_HOT, LOAD_FILAMENT, UNLOAD_FILAMENT |
| **Toolhead** | standby, paused | PARK_FRONT, PARK_REAR, NOZZLE_CLEAN, NOZZLE_PRIME, NOZZLE_PURGE_LINE |
| **Calibration** | standby (collapsed) | CAL_FIRST_LAYER, CAL_BEACON_HOT, CAL_PID_EXTRUDER, CAL_PID_BED, CAL_INPUT_SHAPER |
| **Lights** | always | LIGHTS_CASE_WHITE, LIGHTS_CASE_NIGHT, LIGHTS_CASE_OFF |
| **Learn** | always | VIEW_VARIABLES |

Tip: color the Print group red (PAUSE and CANCEL should be easy to find) and Calibration a muted color.

**If you use these anywhere else, update them:** KlipperScreen custom menus, Mainsail console history, or Orca G-code that called `CLEAN_NOZZLE`/`PURGE_LINE` directly. Orca's standard start line (`PRINT_START ...`) is unchanged.

## View Variables (2026-10-04)

One read-only button for "what is the printer thinking?" Safe to press mid-print. Output goes to the console. Backup of the files before this change: `printer_data/config_v2.bak-2026-10-04-pre-view-variables/`.

| Command | Shows |
|---|---|
| `VIEW_VARIABLES` or `SHOW=tunables` | Your tunable settings: PRINT_START, keep-hot, brush/bucket positions, exhaust |
| `VIEW_VARIABLES SHOW=state` | Homed, QGL, mesh, position, Z offset, temps, and whether the next PRINT_START takes the RETRY path (with the reason if not) |
| `VIEW_VARIABLES NAME=<text>` | Free search over everything (uses `_DUMP_VARIABLES`) |
| `VIEW_VARIABLES PATH=<a.b>` | One exact value (uses `_GET_VARIABLE`) |

- **Mainsail:** click the arrow on the VIEW_VARIABLES button to fill in SHOW / NAME / PATH. It's in the **Learn** group above.
- **KlipperScreen:** a **View Variables** menu on the main screen and in the in-print menu, with My Settings, Printer State and Open Console buttons. Defined in `KlipperScreen.conf`.
- To add another macro to the tunables list, edit `variable_macros` in `_VIEW_TUNABLES` (`macros/debug.cfg`).

Tested in the Klipper simulator (cold start, after PRINT_START, after a cancel, after COOLDOWN, all four modes). `KlipperScreen.conf` was loaded with KlipperScreen's own config parser: no errors, and the menus appear in both menus.

## Orca changes to pair with this (in the slicer, not here)

- **Filament flow ratio:** ASA is currently 0.926. Run Orca's flow calibration; if you don't, try 0.95–1.0 for first-layer adhesion.
- **Brim** on parts with sharp corners for ASA/ABS.
- **Machine start G-code:** no change needed. Optional: add `SOAK=0` when the printer is already heat-soaked.
- **Accel-to-decel:** if Orca's "Klipper: use accel_to_decel" is on, consider turning it off. Klipper replaced `max_accel_to_decel` with `minimum_cruise_ratio` in 2024.

## Suggested next upgrades (not done here)

1. **Chamber thermistor:** see `hardware/sensors.cfg`.
2. **Thermal expansion calibration:** [BeaconPrinterTools](https://github.com/YanceyA/BeaconPrinterTools) measures your nozzle's expansion and sets `z_hot_offset` automatically for each print temperature.
3. **Re-run tuning:** work through `test_prints/README.md` in order (first layer → size → temp → flow → pressure advance → input shaper check → ABS warp). `CAL_INPUT_SHAPER` comes before step 06. Log results in the Handoff Guide.
4. **Mechanical checks:** belt tension (including matched Z belts), bed mounting (one bolt fixed, the others free to slide), and a clean PEI sheet (dish soap and water).
