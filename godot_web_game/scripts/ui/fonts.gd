## The game's fonts. Web builds have no system fonts to borrow from, so every glyph must come from
## a bundled font: symbols (checkmarks, dots, hearts, arrows) fall back to a subset of Noto Sans
## Symbols 2 behind every face.
class_name Fonts
extends RefCounted

const HEADING := "res://assets/fonts/Fredoka.ttf"
const BODY := "res://assets/fonts/Nunito.ttf"
const ITALIC := "res://assets/fonts/NunitoItalic.ttf"
const PIXEL := "res://assets/fonts/PixelifySans.ttf"
const SYMBOLS := "res://assets/fonts/Symbols.ttf"


## Set with the art style. Here rather than read from UI, so tests can load this without autoloads.
static var pixel := true


## In the 8-bit style every face is the pixel font, slanted to stand in for italics.
static func make(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(PIXEL if pixel else path)
	f.fallbacks = [load(SYMBOLS)]
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	if pixel:
		f.base_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.base_font.hinting = TextServer.HINTING_NONE
		# This face runs wider than the layouts were written for.
		f.spacing_glyph = -1
		f.spacing_space = 2
		# Its built-in line height is far looser than they were written for, too.
		f.spacing_top = -2
		f.spacing_bottom = -4
		if path == ITALIC:
			f.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return f


## Whether `font` (its base face or one of its fallbacks) has a glyph for `c`.
static func covers(font: FontVariation, c: int) -> bool:
	return font.base_font.has_char(c) or font.fallbacks.any(func(f): return f.has_char(c))
