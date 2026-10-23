#!/bin/zsh
# Renders every screen in its key states at desktop and phone size into a folder, makes a contact
# sheet of each, and lists any script errors. Needs a display (it uses the real renderer).
# Usage: tools/sweep.sh [out_dir]   (default: /tmp/starship-sweep)
out=${1:-/tmp/starship-sweep}
mkdir -p "$out/desktop" "$out/phone"
cd "$(dirname "$0")/../godot_web_game" || exit 1
shots=(
	"title:--screen=title" "form:--screen=title --form=custom" "intro_talk:--fixture=fresh --screen=shop --talk=odessa_arrives"
	"shop:--fixture=job --screen=shop" "scan:--fixture=job --screen=workbench --tab=Scan"
	"repair:--fixture=crake --screen=workbench --tab=Repair" "weld:--fixture=scanned --screen=workbench --repair=0"
	"bolts:--fixture=brindle --screen=workbench --repair=0" "wash:--fixture=scanned --screen=workbench --tab=Wash"
	"parts:--fixture=scanned --screen=workbench --tab=Parts" "paint:--fixture=scanned --screen=workbench --tab=Paint"
	"tune:--fixture=scanned --screen=workbench --tab=Tune" "handoff:--fixture=finished --screen=handoff --wait=3"
	"tea:--fixture=evening --screen=tea" "tablet:--fixture=evening --screen=shop --tablet" "market:--fixture=hawker --screen=market"
	"night:--fixture=evening --screen=night" "perk:--fixture=levelup --screen=night" "board:--fixture=board --screen=board"
	"walkin:--fixture=walkin --screen=workbench --tab=Repair" "hawker:--fixture=hawker --screen=hawker --wait=3"
	"yard:--fixture=yard --screen=yard" "drawers:--fixture=drawers --screen=drawers" "event:--fixture=close_pass --screen=event --wait=6"
	"lighthouse:--fixture=lumen --screen=event --id=lumen_reach --lit --wait=2"
	"race_club:--fixture=evening --screen=race --wait=4" "race_shadow:--fixture=evening --screen=race --race=shadow_run --at=600 --wait=4"
	"race_gardens:--fixture=evening --screen=race --race=garden_dash --at=600 --wait=4" "race_pause:--fixture=evening --screen=race --paused --wait=2"
)
: > "$out/errors.txt"
for entry in $shots; do
	name=${entry%%:*}
	args=(${=entry#*:})
	godot --path . --resolution 1280x720 -- $args --shot="$out/desktop/$name.png" 2>&1 | grep -A2 "SCRIPT ERROR" | sed "s/^/[desktop $name] /" >> "$out/errors.txt"
	godot --path . --resolution 1170x540 -- --phone $args --shot="$out/phone/$name.png" 2>&1 | grep -A2 "SCRIPT ERROR" | sed "s/^/[phone $name] /" >> "$out/errors.txt"
done
uv run --with pillow python -I - "$out" <<'PY'
import glob, sys
from PIL import Image, ImageDraw
out = sys.argv[1]
for size in ("desktop", "phone"):
    files = sorted(glob.glob(f"{out}/{size}/*.png"))
    thumbs = []
    for f in files:
        im = Image.open(f).convert("RGB")
        im.thumbnail((480, 270))
        ImageDraw.Draw(im).text((6, 4), f.split("/")[-1][:-4], fill=(255, 255, 0))
        thumbs.append(im)
    cols = 4
    sheet = Image.new("RGB", (480 * cols, 270 * ((len(thumbs) + cols - 1) // cols)))
    for i, im in enumerate(thumbs):
        sheet.paste(im, ((i % cols) * 480, (i // cols) * 270))
    sheet.save(f"{out}/{size}_sheet.png")
PY
echo "Screens in $out (contact sheets: desktop_sheet.png, phone_sheet.png)"
if [ -s "$out/errors.txt" ]; then echo "SCRIPT ERRORS:"; cat "$out/errors.txt"; exit 1; fi
echo "No script errors."
