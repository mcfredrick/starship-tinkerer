#!/bin/bash
# accept the port number as an argument
PORT=${1:-9999}
# temporarily cd to the web build directory
pushd "$(dirname "$0")/godot_web_game/build/web" >/dev/null || exit 1
python3 -m http.server "$PORT"
popd >/dev/null || exit 1