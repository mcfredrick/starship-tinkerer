## The dock's parts market: buy parts, teas and cakes; sell spare parts off your shelves.
extends Screen

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
	var panel := UI.panel(UI.vbox([UI.heading("Quietwater parts market", 30), cols, back], 12), Color(UI.CREAM, 0.97), 22)
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
	if GameState.parts.is_empty():
		_sell.add_child(UI.label("Nothing spare right now.", 18, UI.MUTED))
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


func _sell_part(id: String, price: int) -> void:
	Sfx.play("coins")
	GameState.take(GameState.parts, id)
	GameState.add_pebs(price, "Sold a %s" % Content.part(id).name)
	GameState.save()
	_fill()
