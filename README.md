# Starship Tinkerer

A cozy starship repair shop. Fix, modify and upgrade ships for friendly pilots, get paid in pebs
(or jam), take tea breaks with a good book, and rebuild and race your own ship if you like.

Development builds play at https://mcfredrick.github.io/starship-tinkerer/, and the release will
live at https://starship-tinkerer.crap.games. See [docs/DESIGN.md](docs/DESIGN.md) for the design.

## Development

Requires Godot 4.5.1. The art pipeline also needs Blender 4.3.

```bash
godot --path godot_web_game      # run the game
./export_web.sh                  # web build into godot_web_game/build/web/
./serve_on_port.sh               # serve it locally
```

Pushing to `main` deploys to GitHub Pages through the shared workflow in
[mcfredrick/crap_games](https://github.com/mcfredrick/crap_games). The "Update Game Registry"
workflow is run by hand at release to list the game on https://all.crap.games. Pull in template
fixes with `copier update --trust`.
