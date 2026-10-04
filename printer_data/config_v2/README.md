# Voron 2.4 — config_v2

This is a clean rebuild of the Klipper config. The layout follows the official Voron 2.4 / BTT Octopus reference config, and the probing sequence follows Beacon's documentation. All machine-specific values are carried over from your old config. Drafted 2026-10-03.

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
  leds.cfg                  case lights + Stealthburner LEDs + STATUS_ macros
  sensors.cfg               Octopus/Pi temps + chamber thermistor template
macros/
  print_start_end.cfg       PRINT_START (retry-aware) / PRINT_END
  cancel_keep_hot.cfg       cancel = park + keep warm 15 min
  nozzle_clean.cfg          CLEAN_NOZZLE, BUCKET_PRIME, PURGE_LINE
  utility.cfg               G32, PARK_*, PREHEAT, COOLDOWN, LOAD/UNLOAD, M600
  calibration.cfg           PID_*, SHAPER_CALIBRATE_ALL, BEACON_CALIBRATE_HOT, FIRST_LAYER_CHECK
  debug.cfg                 DUMP_VARIABLES, GET_VARIABLE
experimental/               auto-included playground (*.cfg)
moonraker.conf              cleaned up
```

## Install (on the Pi)

1. **Back up the current config.**
   `cp -r ~/printer_data/config ~/printer_data/config_backup_$(date +%F)`
2. **Archive the clutter.** Move the 25 `printer-2024*.cfg` / `printer-2025*.cfg` backups, `active_config/` and `deprecated_config/` into a folder named `archive/`. Klipper ignores any file that nothing includes, so this is only for tidiness.
3. **Copy in the new files.** Copy everything from `config_v2/` into `~/printer_data/config/`: `printer.cfg`, `hardware/`, `macros/`, `experimental/` and `moonraker.conf`. Keep your existing `KlipperScreen.conf`, `crowsnest.conf` and `sonar.conf`; they're unchanged.
4. **Check the Pi username.** The first include in `printer.cfg` assumes it's `pi`: `/home/pi/mainsail-config/mainsail.cfg`. If it isn't, fix that path.
5. **Restart.** Restart Moonraker, then run `FIRMWARE_RESTART` from Mainsail.
6. **First test, supervised.** Home, run `G32`, then a small ASA print. Watch the `PS:` lines in the console.

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
- **Calibration macros:** `PID_EXTRUDER`, `PID_BED`, `SHAPER_CALIBRATE_ALL`, `BEACON_CALIBRATE_HOT`, `FIRST_LAYER_CHECK`.
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

## Orca changes to pair with this (in the slicer, not here)

- **Filament flow ratio:** ASA is currently 0.926. Run Orca's flow calibration; if you don't, try 0.95–1.0 for first-layer adhesion.
- **Brim** on parts with sharp corners for ASA/ABS.
- **Machine start G-code:** no change needed. Optional: add `SOAK=0` when the printer is already heat-soaked.
- **Accel-to-decel:** if Orca's "Klipper: use accel_to_decel" is on, consider turning it off. Klipper replaced `max_accel_to_decel` with `minimum_cruise_ratio` in 2024.

## Suggested next upgrades (not done here)

1. **Chamber thermistor:** see `hardware/sensors.cfg`.
2. **Thermal expansion calibration:** [BeaconPrinterTools](https://github.com/YanceyA/BeaconPrinterTools) measures your nozzle's expansion and sets `z_hot_offset` automatically for each print temperature.
3. **Re-run tuning:** `SHAPER_CALIBRATE_ALL` and pressure-advance tuning in Orca.
4. **Mechanical checks:** belt tension (including matched Z belts), bed mounting (one bolt fixed, the others free to slide), and a clean PEI sheet (dish soap and water).
