# Orca first-layer setup + config v1 → v2 differences (2026-10-07)

"v1" = what's on the Pi today (`printer_data/config/` → `active_config/…`).
"v2" = the rebuild in `printer_data/config_v2/` (not installed yet).
Differences below were pulled by flattening both configs (following every `[include]`) and comparing section by section, then reading the macros.

---

## Part A — Orca: first-layer test with PLA

### Why PLA first
- Sticks to PEI at a low bed temp (60 °C), needs no enclosure heat soak, no warping.
- PETG can bond *too* well to smooth PEI and tear the surface. ASA/ABS need a 10+ min soak and a warm chamber — the hardest case. Get the machine right with PLA, then move back to ASA.
- For PLA: **front doors open or top panel off** (a hot chamber softens PLA in the heatbreak and clogs).
- Clean the PEI sheet with dish soap + hot water first, then don't touch the print area.

### Turning on Advanced in Orca 2.4.2
- It's still there, but it's **per panel**: a small **Advanced** switch in the header of the Process settings in the left sidebar (next to the process preset name). The Printer and Filament settings windows each have their own switch.
- If you can't find it: **OrcaSlicer → Preferences → Developer mode** shows every setting everywhere (same effect, permanent).

### Plate layout (`Klipper Square - 01 first layer.3mf`)
Right now the plate has `Klipper_square.stl` (a multi-layer 60 mm square) + one 0.2 mm patch.
1. Delete `Klipper_square` from the plate (it's not a first-layer test and adds time).
2. Keep `First_Layer_Patch-0.2mm` (matches your 0.2 mm first layer). Right-click → **Clone** → 4 more copies.
3. Place them (Object list → Position X/Y), patch centres at:
   - (40, 40) · (210, 40) · (40, 210) · (210, 210) · (125, 125)
   - These stay inside the mesh area (25–225) and clear of the purge line at X=1.
4. Don't use Arrange (A) — it clusters them in the middle.

### Settings to change

| Where | Setting | Now | Change to | Why |
|---|---|---|---|---|
| Plate dropdown (top of plate) | Plate type | High Temp Plate | Match your sheet (Textured PEI or High Temp/smooth PEI) | Orca picks bed temp by plate type |
| Filament: Generic PLA @System | Bed temp, first layer + other layers | 55 °C | **60 °C** | Standard PLA-on-PEI temp |
| Filament | Nozzle temp | 220 / 220 | keep | Fine for generic PLA |
| Process → Speed → Initial layer | First layer speed | 50 mm/s | **30 mm/s** | Slow while diagnosing |
| Process → Speed → Initial layer | First layer infill speed | 105 mm/s | **40 mm/s** | 105 is fast enough to drag lines off |
| Process → Others → Bed adhesion | Brim type | Auto | **No-brim** (for this test only) | A brim on a 1-layer patch hides what you're judging |
| Printer → Motion ability | Emit limits to G-code | On (max accel 20000, speed 300, jerk 12) | **Off** — or set to match printer.cfg (accel 4000, speed 300) | When on, Orca sends `SET_VELOCITY_LIMIT` that overrides printer.cfg's 4000 accel cap |
| Process → Speed → Acceleration | Enable accel_to_decel | On | **Off** | Klipper deprecated ACCEL_TO_DECEL (replaced by minimum_cruise_ratio) |

Leave alone (already right): first layer height 0.2, first-layer line width 0.5, first-layer accel 500, fan off for layer 1, flow ratio 0.98, Orca pressure advance off (Klipper's 0.04 applies), relative E, label objects on, start G-code `PRINT_START HOTEND=… BED=…` (works with both v1 and v2).

### Running it
1. Slice, send, start. Watch the first patch go down.
2. Babystep Z in Mainsail (±0.01–0.02) until lines just merge — no gaps, no ridges.
3. Note the total babystep. On v2 it's added to `variable_z_hot_offset` (now 0.04); on v1 it goes in the hard-coded `SET_GCODE_OFFSET Z=0.04` near the end of `PRINT_START` in `active_config/system/start_stop.cfg`.
4. Corners vs. centre tell you whether it's Z offset (all the same) or mesh/QGL (corners differ).

**Heads-up:** until v2 is installed, every attempt runs v1's full PRINT_START (4 homes + full 81-point mesh, no retry shortcut). That's the 5–20 min. See Part C to get v2 on with an easy way back.

---

## Part B — v1 vs v2, step by step

### 1. PRINT_START sequence (the big one)

| # | v1 (today) | v2 |
|---|---|---|
| 0 | Clear mesh, zero offset | Same + relative extrusion (M83), cancel keep-hot timer, set exhaust policy |
| 1 | **Home first** (G28), bed not heating yet | **Start bed + nozzle (150 °C) heating, then home** while they heat |
| 2 | Nozzle 150, **wait for bed** | Park over bed centre, wait for bed |
| 3 | No soak | **Soak 10 min only if bed ≥ 90 °C** (ASA/ABS). PLA: none. Chamber-temp wait if a chamber thermistor is added |
| 4 | `G32`: G28 → QGL → **full G28 again** | Beacon `CALIBRATE=1` on the **hot** bed → QGL (Beacon's recommended order) |
| 5 | Wipe ×1 → contact Z with **CALIBRATE=1** | Wipe ×2 → contact Z (CALIBRATE=0) — the Z zero that's actually used |
| 6 | **Full bed mesh, 9×9 = 81 pts** (`ADAPTIVE=0`) | **Adaptive mesh** (only where parts are), 15×15 density, Beacon scan |
| 7 | Wipe ×3 → **another contact Z** | — (not needed: Z already set after the wipe) |
| 8 | Move over bucket, wait for print temp | Move over bucket, wait for print temp |
| 9 | Wipe ×2, `SET_GCODE_OFFSET Z=0.04` (hard-coded) | `SET_GCODE_OFFSET Z={z_hot_offset}` (one tunable, 0.04) |
| 10 | `_purge_clean` + `_PURGE_LINE` (absolute-E purge, 15 mm retracts, 11 s pauses) | `NOZZLE_PRIME` → `NOZZLE_CLEAN` → `NOZZLE_PURGE_LINE` (relative-E, 0.5 mm retracts, 1 s pauses) |
| — | Every attempt does all of the above | **Retry mode:** if still homed + QGL'd + bed within 15 °C → skips homing, soak, calibrate and QGL. `FULL=1` forces the full run |
| — | No timing | `PS: <step> @ Ns` lines in the console show where time goes |

Net: v1 = 4 homing passes + 81-point mesh every time. v2 = 1 home + 1 hot calibrate + 1 contact Z first time; retries go straight to wipe → Z → mesh → heat → purge.

### 2. Cancel, end of print, idle

| | v1 | v2 |
|---|---|---|
| Cancel | Mainsail default (turns heaters off) | Parks over bucket, 1 mm retract, **keeps bed hot + nozzle 150 °C for 15 min** (works from Mainsail, KlipperScreen, Orca) |
| PRINT_END | 10 mm retract, park at **fixed Z50** (crashes into parts taller than 50 mm), brush wipe | 2 mm retract, park **≥10 mm above the part**, no wipe at bed level |
| Motors after print | stay on until idle_timeout (but v1's PRINT_START re-homes anyway) | stay on until idle_timeout — and PRINT_START **uses** that to skip homing/QGL |
| idle_timeout | 7200 s (2 h) | 1800 s (30 min) |

### 3. Safety fixes

| Setting | v1 | v2 |
|---|---|---|
| extruder `min_temp` | -200 | 0 (instant unplugged/broken-thermistor detection back on) |
| extruder `min_extrude_temp` | 0 | 170 (cold-extrusion protection back on) |
| heater_bed `min_temp` | -250 | 0 |
| `[verify_heater]` extruder/bed | Klipper defaults (always on, just not written in the file) | same defaults, written out so they're visible |
| extruder `max_extrude_only_distance` | default (50) | 120 (lets load/unload macros work) |

### 4. Fans

| Fan | v1 | v2 |
|---|---|---|
| Exhaust | `heater_fan`: 100% whenever bed ≥ 60 °C — pulls heat out of the chamber during ASA | `fan_generic` + `_EXHAUST` macro: **off for ASA/ABS**, 60% for PLA/PETG, 100% for 5 min after a print |
| Controller (electronics) | on only when **bed** ≥ 45 °C | `[controller_fan]`: on whenever **motors or heaters** are on, 60 s tail |

### 5. Probe, QGL, mesh

| Setting | v1 | v2 |
|---|---|---|
| QGL speed | 400 (silently capped at 300) | 300 |
| Mesh points | 9×9, always full bed | 15×15, adaptive |
| Beacon `contact_max_hotend_temperature` | default | 180 (explicit) |
| Beacon `home_z_hop_speed` | default | 30 |
| G32 | G28 → QGL → **G28 (all axes)** | G28 → QGL → **G28 Z only** |

### 6. Macros

- **Renamed** (hidden helpers get `_`, buttons get prefixes): `status_*` → `_status_*`; `case_lights_*` → `LIGHTS_CASE_*`; `CLEAN_NOZZLE`/`dynamic_clean`/`BUCKET_PURGE`/`_PURGE_LINE`/`_PURGE_CLEAN` etc. (7 macros) → `NOZZLE_CLEAN`, `NOZZLE_PRIME`, `NOZZLE_PURGE_LINE`; `DUMP_VARIABLES`/`GET_VARIABLE` → `_DUMP_…`/`_GET_…`.
- **Removed:** `PRINT_START_temp`, `_CG32`, `_CQGL`, `fast_motion_demo` (disabled), `dads_sandbox` (was never included).
- **New:** `PREHEAT`, `COOLDOWN`, `KEEP_HOT`, `PARK_FRONT`, `LOAD_FILAMENT`, `UNLOAD_FILAMENT`, `M600`, `CAL_PID_EXTRUDER`, `CAL_PID_BED`, `CAL_INPUT_SHAPER`, `CAL_BEACON_HOT`, `CAL_FIRST_LAYER`, `VIEW_VARIABLES`.
- Visible macro buttons: 45 → 29.

### 7. Everything else

| Area | v1 | v2 |
|---|---|---|
| Mainsail macros | local copy `active_config/mainsail.cfg` (never updates) | `[include /home/pi/mainsail-config/mainsail.cfg]` (updates with Mainsail) — check the Pi username |
| New sections | — | `[gcode_arcs]`, `[save_variables]` (needs empty `variables.cfg`), `[resonance_tester]` on Beacon's accelerometer, MCU + Pi temperature readouts |
| moonraker.conf | `enable_object_processing: False` | `True` (Orca's exclude-object works without slicer help); Telegram + LED-effect updaters removed |
| KlipperScreen.conf | settings only | + View Variables menus (old settings kept) |
| File layout | `active_config/system/…`, `user/…`, `community/…` | `hardware/…`, `macros/…`, `experimental/…` |

### 8. Identical in both
`[printer]` limits (300 mm/s, 4000 accel), all pins, motor currents, endstops, Z gearing, extruder rotation_distance 22.1 + PA 0.04, input shaper (ei 65.2 / mzv 41.8), Beacon serial + Y offset, mesh area 25–225, and the whole SAVE_CONFIG block (PIDs, Beacon model, saved mesh).

---

## Part C — Switching between v1 and v2

**Recommendation: git branches in `~/printer_data/config` on the Pi.** One command flips every file (printer.cfg, includes, moonraker.conf, KlipperScreen.conf) at once, and `git diff v1 v2` is the same diff your son already reviews.

### Scripts (in this repo: `scripts/`)
- `setup-config-git.sh` — one time. Backs up, creates branch `v1` (today's config, untouched) and `v2` (config_v2 installed per its README steps 2–5), leaves the printer on v1.
- `switch-config.sh v1|v2` — refuses mid-print, commits any SAVE_CONFIG changes on the current branch, switches, restarts Moonraker + FIRMWARE_RESTART + KlipperScreen, reports whether Klipper is ready.
- Full instructions and test notes: `scripts/README.md`.

### Gotchas
- **SAVE_CONFIG is per branch.** A new PID, Beacon model or mesh saved on v2 stays on v2. If you want it on v1 too, copy the `#*#` block across (or `git checkout v2 -- printer.cfg` and edit).
- **Z offset is in different places:** v1 hard-codes 0.04 in PRINT_START; v2 uses `variable_z_hot_offset`. Tune each separately if you go back and forth.
- **Mainsail macro groups** live in Mainsail's database, not the config. Groups set up for v2 names will show missing buttons on v1. Cosmetic.
- **Orca needs no change** — both versions accept `PRINT_START HOTEND=… BED=…`.
- Later, if you want a button for it: Klipper's `gcode_shell_command` extension can run the script from Mainsail. Not worth it until you're switching often.

**Simpler alternative (no git):** keep two folders, `config_v1/` and `config_v2/`, and swap with `mv` + restart. Works, but it's easy to lose a SAVE_CONFIG change and harder to see what differs.
