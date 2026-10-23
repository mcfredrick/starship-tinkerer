## The game's fonts. Web builds have no system fonts to borrow from, so every glyph must come from
## a bundled font: symbols (checkmarks, dots, hearts, arrows) fall back to a subset of Noto Sans
## Symbols 2 behind every face.
class_name Fonts
extends RefCounted

const HEADING := "res://assets/fonts/Fredoka.ttf"
const BODY := "res://assets/fonts/Nunito.ttf"
const ITALIC := "res://assets/fonts/NunitoItalic.ttf"
const SYMBOLS := "res://assets/fonts/Symbols.ttf"


static func make(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.fallbacks = [load(SYMBOLS)]
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	return f


## Whether `font` (its base face or one of its fallbacks) has a glyph for `c`.
static func covers(font: FontVariation, c: int) -> bool:
	return font.base_font.has_char(c) or font.fallbacks.any(func(f): return f.has_char(c))
