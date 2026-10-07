#!/bin/bash
# ---------------------------------------------------------------------------
# switch-config.sh  —  flip the printer between config branches. Run ON THE PI.
#
#   ~/scripts/switch-config.sh v2      switch to v2
#   ~/scripts/switch-config.sh v1      switch back
#   ~/scripts/switch-config.sh         show which one is active
#
# What it does:
#   1. Refuses if a print is running or paused.
#   2. Commits anything Klipper changed on the current branch (SAVE_CONFIG
#      results: PID, Beacon model, mesh) so nothing is lost.
#   3. Checks out the other branch.
#   4. Restarts Moonraker, sends FIRMWARE_RESTART, restarts KlipperScreen.
#   5. Tells you whether Klipper came up "ready".
# ---------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "$0")/_common.sh"

cd "$CONFIG_DIR" 2>/dev/null || die "No $CONFIG_DIR"
[[ -d .git ]] || die "$CONFIG_DIR isn't a git repo yet. Run setup-config-git.sh first."

CURRENT=$(git rev-parse --abbrev-ref HEAD)
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  say "Active config: $CURRENT"
  echo "    Branches: $(git branch --format='%(refname:short)' | tr '\n' ' ')"
  git diff --quiet HEAD || echo "    (uncommitted changes on $CURRENT; they'll be saved on the next switch)"
  exit 0
fi

git show-ref --verify --quiet "refs/heads/$TARGET" || die "No branch '$TARGET'. Have: $(git branch --format='%(refname:short)' | tr '\n' ' ')"
[[ "$TARGET" == "$CURRENT" ]] && { say "Already on $TARGET."; exit 0; }

require_idle

# Keep SAVE_CONFIG (and any hand edits) on the branch they belong to.
git add -A
if ! git diff --cached --quiet; then
  git commit -qm "auto-save on $CURRENT before switching to $TARGET ($(date '+%F %H:%M'))"
  say "Saved changes on $CURRENT"
fi

git checkout -q "$TARGET"
touch variables.cfg
say "Switched $CURRENT -> $TARGET"

restart_stack
report_klipper
