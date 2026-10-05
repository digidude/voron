# Voron 2.4 test prints

Run these in folder order: each step assumes the earlier ones are dialed in. Change one thing per print and write down the value (results log in the Handoff Guide).

Steps with no folder (temperature, retraction, max speed, tolerance) are generated inside Orca: **Calibration** menu. No file needed.

| # | Folder / where | File(s) | What it tells you | How to read it |
|---|---|---|---|---|
| 01 | `01_first_layer/` | `First_Layer_Patch-0.2mm.stl` (match your first-layer height; 0.24 / 0.25 / 0.3 also included) | Z offset + mesh, everywhere on the bed | Place 5 copies: 4 corners + center. Babystep live until lines just merge, no gaps or ridges. Add the total to `variable_z_hot_offset` |
| 02 | `02_size/` | `calibrate_size.stl` (Klipper) | X/Y accuracy and skew | Measure with calipers; Klipper's `skew_correction` docs explain the math |
| 03 | Orca → Calibration | Temp tower | Best nozzle temp | Pick the cleanest section |
| 04 | `04_flow_em_cubes/` | `labeled_0.900-1.050/EM_Cube-*.stl` (or the unlabeled one) | Flow ratio (extrusion multiplier) | Ellis' method: print several, pick the smoothest top surface without overfill. Labeled cubes have the value embossed. Your ASA is at 0.926 now; expect 0.95–1.0 |
| 05 | `05_pressure_advance/` | `square_tower.stl` (Klipper) — or Orca's PA pattern | Corner sharpness | Klipper docs: "Pressure advance" tuning. Orca's pattern test is quicker |
| 06 | `06_input_shaper_check/` | `ringing_tower.stl` (Klipper) | Ghosting after `CAL_INPUT_SHAPER` | Ripples next to the notches should be gone |
| 07 | Orca → Calibration | Retraction test | Stringing | Shortest retraction with no strings |
| 08 | Orca → Calibration | Max volumetric speed | Hotend melt limit | Note where the walls start to fail; use ~80% of it |
| 09 | `09_abs_warp_test/` | `Warp_Bar_150x20x5.stl` | ABS/ASA corner lifting | Print along X, 3 walls, 15% infill, no brim first. Lay it on glass: any rocking = warp. Repeat with brim / after chamber thermistor |
| 10 | `10_overall_voron_cube/` | `Voron_Design_Cube_v7.stl` | Overhangs, bridges, text, dimensions | Voron's own all-in-one check. 30 mm cube |
| 11 | Voron GitHub | A real Voron part in ASA (e.g. a spare Stealthburner part) | Final exam | Fits + no warp = done |

**Git note:** Ellis' first-layer patches and EM cubes (`01_first_layer/First_Layer_Patch-*.stl`, everything in `04_flow_em_cubes/`) aren't in the git repo because they have no redistribution license. Download them from his repo (link below) into those folders.

## Sources

- First-layer patches and EM cubes: Ellis' Print Tuning Guide — github.com/AndrewEllis93/Print-Tuning-Guide (`test_prints/`). Guide: ellis3dp.com
- Voron Design Cube v7: github.com/VoronDesign/Voron-2 (`STLs/Test_Prints/`), GPL-3.0 (license in that folder)
- `calibrate_size`, `square_tower`, `ringing_tower`: Klipper (`klipper/docs/prints/`), GPL-3.0
- Warp bar: simple 150 × 20 × 5 mm box generated for this project

Downloaded 2026-10-04.
