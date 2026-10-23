# Starship Tinkerer

Cozy starship repair shop game for crap.games (starship-tinkerer.crap.games; dev builds at
mcfredrick.github.io/starship-tinkerer). Design lives in `docs/DESIGN.md`. Read it before adding
features or content.

## Layout

- `godot_web_game/`: Godot 4.5.1 project, Compatibility renderer so it exports to web. Scaffolded
  from `~/Crap Games/crap-games-template` (`copier update --trust` pulls template fixes).
  - `data/`: all content as JSON plus dialogue scripts in `data/dialogue/*.txt` (format documented
    in `scripts/core/dialogue.gd`). Non-resource files ship via `include_filter` in
    `export_presets.cfg`.
  - `scripts/core/`: pure logic with no scene dependencies (pronouns, dialogue, ship stats,
    grading, skills). `scripts/race/`: track and race physics, also pure.
  - `scripts/autoload/`: `Content` (read-only data), `GameState` (the save), `Router` (screens,
    dialogue, toasts).
  - `scripts/screens/`: one script per screen, building its own nodes. `scripts/ui/`, `scripts/world/`,
    `scripts/minigames/`: widgets, 3D pieces and repair minigames.
  - `assets/`: generated art (ship kit glb, portraits, props) and OFL fonts.
- `blender/`: art pipeline, run inside Blender's Python. Follows the Graffiti Pets pipeline in
  `~/Code/cloddy-game-crap/blender/`.
- `docs/`: design doc.

## Commands

Run from `godot_web_game/` unless noted. `B` is `/Applications/Blender.app/Contents/MacOS/Blender`.

| Task | Command |
| --- | --- |
| Run the game | `godot --path .` |
| Reimport (after assets or new `class_name`s) | `godot --headless --import` |
| Logic tests | `godot --headless --script res://tests/run_tests.gd` |
| Compile every script | `godot --headless res://tools/check_scripts.tscn` |
| Race balance report | `godot --headless --script res://tools/race_report.gd` |
| Screenshot a screen | `godot --path . -- --fixture=<name> --screen=<name> --shot=out.png [--wait=2] [--tablet] [--repair=0]` |
| Ship kit | `$B -b --python blender/export_ship_kit.py` (repo root); preview with `preview_kit.py -- out.png [--front]` |
| Portraits | `$B -b --python blender/portraits.py -- [character ...]` |
| Prop icons | `$B -b --python blender/props.py` |
| Web build | `./export_web.sh` (repo root; output in `godot_web_game/build/web/`) |
| Sound effects | `uv run --with numpy python -I tools/sfx.py` (repo root) |
| Check the live web build | `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1280,720 --timeout=40000 --user-data-dir=<tmp> --screenshot=out.png <url>` (add `--enable-logging=stderr --v=0` and grep `CONSOLE` for errors) |

Fixtures (`scripts/debug/fixtures.gd`): `fresh`, `job`, `scanned`, `finished`, `evening`, `day2`.

## Conventions

- Content is data. Code reads `data/` and never hardcodes pilots, parts, jobs or text.
- Ship kit mesh names end in a material role (`_paint`, `_trim`, `_glass`, `_metal`, `_glow`,
  `_dark`). Sockets are `<hull>__socket_<slot>`, repair spots `<hull>__spot_<n>`. Ship nose is
  Blender +Y, which is Godot -Z.
- Story progress is flags in `GameState.flags`. Shop beats mark themselves `seen_<scene>`.
- Player-facing text uses pronoun tokens (`{name}`, `{they}`, `{is|are}`...) and never assumes a
  gender for the player.
- Currency is pebs everywhere (`pebs`, never "credits" or "coins").
- Generated art in `assets/` is committed so the game builds without Blender.

## Gotchas

- Controls only inherit a theme from a Control or Window parent. Screens and overlays sit under
  plain Nodes and CanvasLayers, so top-level controls get `Router.theme` explicitly.
- Autoloads don't exist under `--script`, so tests and tools use only `class_name` logic, and the
  script checker runs as a scene.
- New `class_name`s and new font or texture files need `godot --headless --import` before other
  scripts can see them.
- GDScript can't infer types from Dictionary values: write `var x: float = d.v`, not `var x := d.v`.
- Blender's EEVEE prints Metal shader errors in background mode but still renders correctly.

## Verifying visual changes

Look at a rendered frame before calling a visual change done (screenshot command above). Logic
changes need `run_tests.gd` and `check_scripts.tscn` passing.

## Workflow Standards

- Solo project: commit directly to `main`, no PRs.
- Keep each commit a coherent unit, and don't mix refactors with features.
- Follow the user-level code standards (comments explain why, single code path, fail fast).
