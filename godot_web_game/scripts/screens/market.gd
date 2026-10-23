## The dock's parts market: buy parts, teas and cakes; sell spare parts off your shelves.
extends Screen

## The repair each kind of worn part needs.
const RESTORE_GAMES := {"engine": "calibrate", "fins": "dent", "cockpit": "weld", "lights": "rewire", "top": "bolts"}

var _buy: VBoxContainer
var _sell: VBoxContainer


func _ready() -> void:
	super()
	add_stage()
	stage.camera.target = Vector3(0, 2.0, 0)
	stage.camera.yaw = -0.4
	stage.camera.refresh()
	show_ship("kettle")
	ui.add_child(Hud.new())

	_buy = UI.vbox([], 6)
	_sell = UI.vbox([], 6)
	var buy_scroll := _scroll(_buy, 470)
	var sell_scroll := _scroll(_sell, 470)
	var cols := UI.hbox([UI.vbox([UI.heading("For sale", 24), buy_scroll]),
		UI.vbox([UI.heading("Your shelves", 24), sell_scroll])], 24)
	var back := UI.button("Back to the shop", func(): Router.go("shop"), 20)
	var header := UI.vbox([UI.heading("Quietwater parts market", 30)], 4)
	if Market.news():
		header.add_child(UI.label("Market news: " + Market.news(), 16, UI.TEAL, true))
	var panel := UI.panel(UI.vbox([header, cols, back], 12), Color(UI.CREAM, 0.97), 22)
	UI.place(panel, Control.PRESET_CENTER, Vector2(-560, -290), Vector2(1120, 0))
	UI.fit(panel, 76)
	ui.add_child(panel)
	_fill()


func _scroll(content: Control, height: float) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(520, height)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


func _fill() -> void:
	for c in _buy.get_children() + _sell.get_children():
		c.queue_free()
	for id in Content.world.market:
		var p: Dictionary = Content.part(id)
		var cost := Market.price(id)
		_buy.add_child(_row(p.name, p.desc, "Buy · %s" % UI.pebs(cost), _buy_part.bind(id), GameState.pebs >= cost))
	for id in Content.comforts.teas.keys() + Content.comforts.cakes.keys():
		var item: Dictionary = Content.item(id)
		if item.price > 0:
			_buy.add_child(_row(item.name, item.desc, "Buy · %s" % UI.pebs(item.price), _buy_item.bind(id),
				GameState.pebs >= item.price))
	if GameState.parts.is_empty() and GameState.worn.is_empty():
		_sell.add_child(UI.label("Nothing spare right now.", 18, UI.MUTED))
	for id in GameState.worn:
		var p: Dictionary = Content.part(id)
		var row := _row("Worn %s  × %d" % [p.name.to_lower(), GameState.worn[id]],
			"Scuffed and tired. Restore it (a spark and a quick repair) and it's as good as new.",
			"Sell · %s" % UI.pebs(Market.worn_resale(id)), _sell_worn.bind(id), true)
		var restore := UI.button("Restore", _restore.bind(id), 16)
		restore.disabled = GameState.spark <= 0
		row.get_child(0).add_child(restore)
		_sell.add_child(row)
	for id in GameState.parts:
		var p: Dictionary = Content.part(id)
		var price := Market.resale(id)
		_sell.add_child(_row("%s  × %d" % [p.name, GameState.parts[id]], p.desc, "Sell · %s" % UI.pebs(price),
			_sell_part.bind(id, price), true))


func _row(name: String, desc: String, action_text: String, action: Callable, enabled: bool) -> Control:
	var text := UI.vbox([UI.label(name, 19), UI.label(desc, 15, UI.MUTED, true)], 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.button(action_text, action, 16)
	b.disabled = not enabled
	b.custom_minimum_size.x = 150
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UI.panel(UI.hbox([text, b]), Color(1, 1, 1, 0.55), 8)


func _buy_part(id: String) -> void:
	var p: Dictionary = Content.part(id)
	GameState.add_pebs(-Market.price(id), "")
	GameState.give(GameState.parts, id)
	GameState.save()
	Router.toast("%s is on your shelf." % p.name)
	_fill()


func _buy_item(id: String) -> void:
	var item: Dictionary = Content.item(id)
	GameState.add_pebs(-item.price, "")
	GameState.give(GameState.items, id)
	GameState.save()
	Router.toast("%s, wrapped in paper." % item.name)
	_fill()


func _sell_worn(id: String) -> void:
	Sfx.play("coins")
	GameState.add_pebs(Market.worn_resale(id), "Sold a worn %s" % Content.part(id).name.to_lower())
	GameState.take(GameState.worn, id)
	GameState.save()
	_fill()


## Restoring a worn part: a repair minigame suited to it, then it joins your sound parts.
func _restore(id: String) -> void:
	var game_id: String = RESTORE_GAMES[Content.part(id).slot]
	GameState.spark -= 1
	var game: Minigame = load("res://scripts/minigames/%s.gd" % game_id).new()
	game.setup(id.hash() % 6)
	game.leniency = GameState.leniency("mechanics", game_id)
	game.theme = Router.theme
	ui.add_child(game)
	await game.finished
	GameState.take(GameState.worn, id)
	GameState.give(GameState.parts, id)
	GameState.add_xp("craft", 8)
	GameState.save()
	Sfx.play("success")
	Router.toast("Restored: %s. Craft +8" % Content.part(id).name)
	_fill()


func _sell_part(id: String, price: int) -> void:
	Sfx.play("coins")
	GameState.take(GameState.parts, id)
	GameState.add_pebs(price, "Sold a %s" % Content.part(id).name)
	GameState.save()
	_fill()
