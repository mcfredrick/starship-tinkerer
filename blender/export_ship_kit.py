"""Build the ship kit and export it for Godot.

Run: Blender -b --python blender/export_ship_kit.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import bpy  # noqa: E402

from kit_common import clear_scene  # noqa: E402
from ship_kit import build_kit  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "ships" / "kit.glb"

clear_scene()
build_kit()
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True, export_apply=False,
                          export_materials="NONE")
print("exported", OUT)
