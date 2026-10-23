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
| Screenshot a screen | `godot --path . -- --fixture=<name> --screen=<name> --shot=out.png [--wait=2] [--tablet] [--talk=scene]` plus screen params: workbench `--ship= --tab= --repair=N --focus=N` (lean in on a fault) `--fixfx=N` (play its fix) `--demo=paint\|part\|scrub\|<livery>`, race `--at=<meters> --paused`, title `--form=[custom]` |
| Screenshot at phone size | add `--resolution 1170x540` before `--` and `--phone` after it (portrait: `--resolution 390x844`) |
| Hull gallery (every hull, sample loadouts) | `godot --path . --resolution 640x400 res://tools/hull_gallery.tscn -- --out=<png> [--hull=id] [--yaw=rad]` |
| Ship kit | `$B -b --python blender/export_ship_kit.py` (repo root); preview with `preview_kit.py -- out.png [--front]` |
| Portraits | `$B -b --python blender/portraits.py -- [character ...]` |
| Paper-doll layers (generated customers) | `$B -b --python blender/dolls.py -- [layer-prefix ...]` |
| Grommet the cat (3D) | `$B -b --python blender/cat.py` (portrait sheet: `portraits.py -- grommet`) |
| Prop icons | `$B -b --python blender/props.py` |
| Web build | `./export_web.sh` (repo root; output in `godot_web_game/build/web/`) |
| Sound effects | `uv run --with numpy python -I tools/sfx.py` (repo root) |
| Check the live web build | `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1280,720 --timeout=40000 --user-data-dir=<tmp> --screenshot=out.png <url>` (add `--enable-logging=stderr --v=0` and grep `CONSOLE` for errors) |

Fixtures (`scripts/debug/fixtures.gd`): `fresh`, `job`, `scanned`, `finished`, `evening`, `day2`, `brindle`,
`crake`, `midway` (Crake's job with every fault one step in), `board` (day 4, walk-ins on the board),
`walkin` (a walk-in's job on the bench), `levelup`. The shop also takes `--cat=sweet|grumpy|sleepy`.

## Conventions

- Content is data. Code reads `data/` and never hardcodes pilots, parts, jobs or text.
- Pilots and jobs are authored (`world.json`) or generated (`GameState.cast`, `GameState.jobs`, from
  `data/walkins.json` through `Walkins`). Always look them up with `GameState.pilot(id)` and
  `GameState.job_spec(id)`. Generated customers speak as `guest` in dialogue, with `{guest}`,
  `{guest_ship}` and `{request}` tokens; `Router.talk(scene, guest_id)` says who that is.
- Storylets (`data/storylets.json`, scenes in `data/dialogue/storylets.txt`) attach to new walk-ins
  and play a scene per hook (`arrive`, `handoff`, next `morning`) through `Router.story(guest, hook)`.
  Their scenes set story-local flags with `! story <flag>`; the handoff sets `tier_<tier>`.
- Portraits and doll layers import as lossy WebP (`compress/mode=1`, quality 0.85 in their `.import`
  files), which halves the download. New PNGs there need the same setting.
- Hulls need all six sockets and spots 1 to 6 (spots are numbered from 1); the kit test checks this.
- Ship kit mesh names end in a material role (`_paint`, `_trim`, `_glass`, `_metal`, `_glow`,
  `_dark`). Sockets are `<hull>__socket_<slot>`, repair spots `<hull>__spot_<n>`. Ship nose is
  Blender +Y, which is Godot -Z.
- Story progress is flags in `GameState.flags`. Story beats are listed in `world.json` `beats` and
  mark themselves `seen_<scene>` after playing. Job reactions are `<job>_<tier>` scenes, with
  optional `<job>_prank` / `<job>_sabotage` (generic `mischief_*` fallbacks).
- New save fields must load with a default (`d.get(...)`) so older saves keep working.
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

- Phones (coarse pointer, short side ≤ 600 CSS px) run on a 960x540 canvas so everything draws
  larger (`UI.detect_device`). Centered overlays go through `UI.fit` so they center and shrink when
  taller than the screen, and touch hit areas scale by `UI.reach()`. Check new overlays at phone size.

## Verifying visual changes

Look at a rendered frame before calling a visual change done (screenshot command above). Logic
changes need `run_tests.gd` and `check_scripts.tscn` passing.

## Workflow Standards

- Solo project: commit directly to `main`, no PRs.
- Keep each commit a coherent unit, and don't mix refactors with features.
- Follow the user-level code standards (comments explain why, single code path, fail fast).
