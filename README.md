# Voron 2.4 — Klipper config + notes

Klipper config, calibration prints, and working notes for a Voron 2.4 (250 mm, BTT Octopus, Beacon RevH, Stealthburner + Clockwork 2, Klipper / Mainsail / KlipperScreen).

The goal of the overhaul: first layers that stick, and a failed print that retries in about a minute instead of 5–20.

**Status (2026-10-04):** `config_v2` is checked in a Klipper simulator but **not yet installed on the printer**. The first real run must be supervised.

## What's where

| Path | What it is |
|---|---|
| [`printer_data/config_v2/`](printer_data/config_v2/) | **The new config.** Its [README](printer_data/config_v2/README.md) has the install steps, rollback, and every change with the reason |
| [`printer_data/config/`](printer_data/config/) | The original config as copied from the Pi on 2026-10-03, kept for comparison. `proposed/` holds the first Step 2 drafts (superseded by `config_v2`) |
| [`test_prints/`](test_prints/) | Calibration prints in the order to run them |
| [`docs/notes/`](docs/notes/) | Working notes: the Step 1 review, the Step 2 drafts, and a config_v2 summary |

Live guides (shared docs, printable, export to PDF / Word / Markdown):

- **Voron 2.4 Config Overhaul — Handoff Guide:** install walkthrough, Mainsail setup, experiment order, results log
- **Orca Slicer from Scratch — Voron 2.4:** presets, start G-code, calibration, sharing presets

Ask Dan for the links (they're private docs, shared per person).

## Seeing what changed

The history is built so each commit is one step:

1. Original Pi config
2. Step 2 drafts (`config/proposed/`)
3. `config_v2` clean rebuild
4. Macro cleanup (renames, hidden helpers)
5. VIEW_VARIABLES + KlipperScreen menu
6. Test prints, notes, this README

Ways to read the diffs:

- **On GitHub:** click **Commits**, then any commit for a side-by-side diff (gear icon → *Split*). Steps 4 and 5 are the readable ones.
- **Compare two points:** `https://github.com/<user>/voron/compare/<commit-a>...<commit-b>`
- **Locally:** `git log --oneline`, then `git show <commit>` or `git diff <a> <b> -- printer_data/config_v2/macros/`
- **Old vs new config:** the folder layout changed completely, so a file-by-file diff isn't useful. Compare by topic, e.g. `config/active_config/system/start_stop.cfg` vs `config_v2/macros/print_start_end.cfg`. In VS Code: select both files → right-click → *Compare Selected*.

## Not in this repo (on purpose)

- `deprecated_config/telegram_config.conf`: it contains a Telegram bot token and API key.
- The 19 timestamped `printer-2024*/2025*.cfg` auto-backups and Mainsail theme images.
- Ellis' first-layer patch and EM-cube STLs (no license to redistribute). Download them from [Ellis' Print Tuning Guide](https://github.com/AndrewEllis93/Print-Tuning-Guide). See `test_prints/README.md`.
- Everything else in this folder (Klipper, Moonraker, Mainsail, etc.). Those are installed software copied from the Pi, not config.

## Licenses

Config files are a personal setup, shared as-is. `test_prints/` includes GPL-3.0 files from Klipper and Voron Design; see `test_prints/README.md` for sources.
