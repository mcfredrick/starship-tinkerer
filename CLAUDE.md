# Starship Tinkerer

Cozy starship repair shop game for crap.games (starship-tinkerer.crap.games). Design lives in
`docs/DESIGN.md`. Read it before adding features or content.

## Layout

- `godot_web_game/`: Godot 4.5.1 project, Compatibility renderer so it exports to web. Scaffolded
  from `~/Crap Games/crap-games-template`.
- `godot_web_game/js/`: share and music features loaded by `custom_shell.html` from `js/`.
- `blender/`: art pipeline scripts, run inside Blender's Python:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --python blender/<script>.py`.
  Follows the Graffiti Pets pipeline in `~/Code/cloddy-game-crap/blender/`.
- `docs/`: design doc.

## Commands

| Task | Command |
| --- | --- |
| Run the game | `godot --path godot_web_game` |
| Reimport after asset changes | `godot --headless --path godot_web_game --import` |
| Web build | `./export_web.sh` (output in `godot_web_game/build/web/`) |
| Serve the web build | `./serve_on_port.sh` |

## Conventions

- Game content (pilots, jobs, parts, teas, cakes, reading) is data under `godot_web_game/data/`.
  Code reads it and never hardcodes content.
- Ship kit mesh names end in a material role (`_paint`, `_trim`, `_glass`, `_metal`, `_glow`) so the
  paint shop can recolor any part. Sockets are empties named `socket_<slot>`.
- Generated art in `godot_web_game/assets/` is committed so the game builds without Blender.
- Currency is pebs everywhere in UI and data (`pebs`, never "credits" or "coins").

## Verifying visual changes

Look at a rendered frame before calling a visual change done. Godot can save a frame headlessly once
a `--shot=` flag is wired into the main scene (as in Graffiti Pets), and Blender renders with
`-b --python <script> -- <args>`.

## Workflow Standards

- Solo project: commit directly to `main`, no PRs.
- Keep each commit a coherent unit, and don't mix refactors with features.
- Follow the user-level code standards (comments explain why, single code path, fail fast).
