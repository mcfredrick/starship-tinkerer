## The game's look in one place: the theme, palette and small builders for common widgets.
class_name UI
extends RefCounted

const INK := Color("4a3428")
const CREAM := Color("fbf3e4")
const PAPER := Color("f3e6cc")
const AMBER := Color("e8a33d")
const AMBER_DARK := Color("c7832a")
const TEAL := Color("3f8f8f")
const SAGE := Color("8fae7e")
const ROSE := Color("e48aa0")
const MUTED := Color("8a7565")
const GOOD := Color("5f9e6e")
const BAD := Color("c8643f")

## Phones get a smaller canvas (so everything draws larger) and touch gets roomier hit areas.
## Both are decided once at boot by `detect_device`.
const COMPACT_SIZE := Vector2i(960, 540)
static var compact := false
static var touch := false

static var heading_font: FontVariation
static var body_font: FontVariation
static var bold_font: FontVariation


static func build_theme() -> Theme:
	heading_font = Fonts.make(Fonts.HEADING, 600)
	body_font = Fonts.make(Fonts.BODY, 600)
	bold_font = Fonts.make(Fonts.BODY, 800)
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 20
	for type in ["Label", "RichTextLabel", "Button", "LineEdit", "CheckBox", "OptionButton"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("bold_font", "RichTextLabel", bold_font)
	t.set_font("italics_font", "RichTextLabel", Fonts.make(Fonts.ITALIC, 600))

	t.set_stylebox("panel", "PanelContainer", box(CREAM, 18, 16, true))
	t.set_stylebox("panel", "Panel", box(CREAM, 18, 16, true))

	t.set_font("font", "Button", heading_font)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(AMBER, 14, 10, false, AMBER_DARK))
	t.set_stylebox("hover", "Button", box(AMBER.lightened(0.18), 14, 10, false, AMBER_DARK))
	t.set_stylebox("pressed", "Button", box(AMBER_DARK, 14, 10, false, AMBER_DARK.darkened(0.2)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 14, 10, false, TEAL))
	t.set_stylebox("disabled", "Button", box(PAPER.darkened(0.08), 14, 10, false, PAPER.darkened(0.2)))

	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, 10, 10, false, PAPER.darkened(0.25)))
	t.set_stylebox("focus", "LineEdit", box(Color.WHITE, 10, 10, false, TEAL))
	t.set_font_size("font_size", "LineEdit", 24)
	t.set_color("font_placeholder_color", "LineEdit", Color(UI.MUTED, 0.75))

	t.set_stylebox("panel", "TooltipPanel", box(INK, 8, 8, false))
	t.set_color("font_color", "TooltipLabel", CREAM)

	var grabber := box(AMBER, 10, 0, false, AMBER_DARK)
	t.set_stylebox("slider", "HSlider", box(PAPER.darkened(0.15), 6, 3, false))
	t.set_stylebox("grabber_area", "HSlider", grabber)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)

	t.set_stylebox("background", "ProgressBar", box(PAPER.darkened(0.12), 6, 0, false))
	t.set_stylebox("fill", "ProgressBar", box(TEAL, 6, 0, false))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t


static func detect_device(window: Window, args: PackedStringArray) -> void:
	if OS.has_feature("web"):
		touch = JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches", true)
		compact = touch and JavaScriptBridge.eval("Math.min(screen.width, screen.height) <= 600", true)
	if "--phone" in args:
		touch = true
		compact = true
	if compact:
		window.content_scale_size = COMPACT_SIZE


## On touch web builds, tapping `edit` opens the page's touchPrompt (js/touch-feature.js): a labelled
## box above the phone keyboard, since Godot's own field can't summon the keyboard reliably and the
## keyboard would cover it. Elsewhere the field works as normal.
static func touch_text(edit: LineEdit, label: String) -> void:
	if not (touch and OS.has_feature("web")):
		return
	edit.editable = false
	edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	edit.gui_input.connect(func(event: InputEvent):
		var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
		if not tapped:
			return
		edit.accept_event()
		var done := JavaScriptBridge.create_callback(func(args: Array):
			edit.text = str(args[0]).left(edit.max_length if edit.max_length > 0 else 9999)
			edit.text_changed.emit(edit.text))
		# The callback must outlive this function, or JS calls into a freed object.
		_prompt_callbacks.append(done)
		JavaScriptBridge.get_interface("window").touchPrompt(label, edit.text, edit.max_length, done))


static var _prompt_callbacks: Array = []


## Scale for touch hit areas: fingers are blunter than cursors.
static func reach() -> float:
	return 1.6 if touch else 1.0


static func box(color: Color, radius: int, pad: int, shadow := false, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	if border.a > 0:
		s.set_border_width_all(2)
		s.border_width_bottom = 4
		s.border_color = border
	if shadow:
		s.shadow_color = Color(0.1, 0.05, 0.1, 0.35)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s


static func label(text: String, size := 20, color := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func heading(text: String, size := 30, color := INK, wrap := false) -> Label:
	var l := label(text, size, color, wrap)
	l.add_theme_font_override("font", heading_font)
	return l


static func button(text: String, action: Callable, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func(): Sfx.play("click", randf_range(0.95, 1.08)))
	b.pressed.connect(action)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func panel(content: Control, color := CREAM, pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, 18, pad, true))
	p.add_child(content)
	return p


static func vbox(children: Array = [], sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func hbox(children: Array = [], sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func icon(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	return t


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Anchors `c` to a preset point and places it at `offset` from that point with `size`.
static func place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> Control:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y
	return c


## Keeps a placed panel on screen. When it would run past the band between `top` and `bottom` (as
## fixed desktop layouts do on a phone's shorter canvas), it is centered in that band and scaled to
## fit. Offsets are always rebuilt from the placed and minimum sizes, so a transient size seen
## mid-layout (wrapping labels start out very tall) never sticks.
static func fit(c: Control, top := 12.0, bottom := 12.0) -> void:
	var placed := [c.anchor_top, c.anchor_bottom, c.offset_top, c.offset_bottom, c.grow_vertical]
	var placed_height: float = placed[3] - placed[2] if placed[0] == placed[1] else 0.0
	var placed_width: float = c.offset_right - c.offset_left if c.anchor_left == c.anchor_right else 0.0
	var refit := func():
		var view := c.get_viewport_rect().size
		var need := c.get_combined_minimum_size()
		need = need.max(Vector2(placed_width, placed_height))
		var y: float = placed[0] * view.y + placed[2]
		var fits: bool = y >= top and y + need.y <= view.y - bottom and need.x <= view.x
		c.anchor_top = placed[0] if fits else 0.5
		c.anchor_bottom = placed[1] if fits else 0.5
		c.grow_vertical = placed[4] if fits else Control.GROW_DIRECTION_BOTH
		var mid := (top - bottom) / 2
		c.offset_top = placed[2] if fits else mid - need.y / 2
		c.offset_bottom = placed[3] if fits else mid + need.y / 2
		var room := Vector2(view.x - 24, view.y - top - bottom)
		c.pivot_offset = need / 2
		c.scale = Vector2.ONE * (1.0 if fits else minf(1.0, minf(room.x / need.x, room.y / need.y)))
	c.resized.connect(refit)
	c.minimum_size_changed.connect(refit)
	c.ready.connect(func(): c.get_viewport().size_changed.connect(refit))
	# A fixed-size panel never resizes, so without this one pass it would only fit after a window change.
	c.ready.connect(refit, CONNECT_DEFERRED)


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func pebs(n: int) -> String:
	return "%d pebs" % n
