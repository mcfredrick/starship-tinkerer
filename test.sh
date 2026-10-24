#!/bin/sh
# Runs every automated check: compile all scripts, the logic tests, the autoplay soak test (a bot
# plays three seeded 40-day runs), then the layout check at desktop and phone size (nothing off screen). Fails if any script fails to compile or load, even when a runner
# itself would still report a pass.
cd "$(dirname "$0")/godot_web_game" || exit 1
godot --headless --import >/dev/null 2>&1
out=$(godot --headless res://tools/check_scripts.tscn 2>&1; godot --headless --script res://tests/run_tests.gd 2>&1;
	godot --headless res://tools/soak.tscn 2>&1; godot --headless res://tools/layout_check.tscn 2>&1;
	godot --headless res://tools/layout_check.tscn -- --phone 2>&1)
echo "$out" | grep -E "SCRIPT ERROR|Failed to load|does not compile|ERROR: [^PRB1]|FAILED|passed|compile|^seed" | grep -v "leaked\|Pages in use"
if echo "$out" | grep -qE "SCRIPT ERROR|Failed to load|does not compile|FAILED"; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL CHECKS PASSED"
