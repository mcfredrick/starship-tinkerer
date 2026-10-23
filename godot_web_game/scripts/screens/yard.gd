## The salvage yard: junkers to buy and fix up, your project ships, and buyers for them. Whichever
## ship you pick sits on the cradle.
extends Screen

var _list: VBoxContainer
var _model: ShipModel
var _shown := ""


func _ready() -> void:
	super()
	add_stage()
	stage.camera.target = Vector3(-1.8, 2.0, 0)
	stage.camera.yaw = 0.7
	stage.camera.distance = 11.5
	stage.camera.refresh()
	ui.add_child(Hud.new())
	_list = UI.vbox([], 10)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(470, 520)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var box := UI.vbox([UI.heading("The salvage yard", 30),
		UI.label("Battered ships, cheap. Fix one up and sell it on, or race it.", 17, UI.MUTED, true), scroll,
		UI.button("Back to the shop", func(): Router.go("shop"), 20)], 10)
	var panel := UI.panel(box, Color(UI.CREAM, 0.97), 20)
	UI.place(panel, Control.PRESET_TOP_RIGHT, Vector2(-526, 84), Vector2(510, 0))
	UI.fit(panel, 84)
	ui.add_child(panel)
	_fill()


func _show(build: Dictionary, key: String) -> void:
	if key == _shown:
		return
	_shown = key
	if _model:
		_model.queue_free()
	_model = ShipModel.new()
	stage.cradle.add_child(_model)
	_model.build(build)


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UI.heading("For sale this week", 22))
	var stock := GameState.yard()
	if stock.is_empty():
		_list.add_child(UI.label("Sold out. New junk turns up every few days.", 17, UI.MUTED))
	for junk in stock:
		_list.add_child(_junker_card(junk))
	var projects := GameState.projects()
	if projects:
		_list.add_child(UI.heading("Your projects", 22))
	for id in projects:
		_list.add_child(_project_card(id))
	if _shown == "":
		if stock:
			_show(stock[0].ship, stock[0].key)
		elif projects:
			_show(GameState.ships[projects[0]], projects[0])


func _junker_card(junk: Dictionary) -> PanelContainer:
	var ship: Dictionary = junk.ship
	var info := "A %s. %d faults, grime thick enough to grow cress in. Fixed up, worth around %s." % [
		Content.parts.hulls[ship.hull].name.to_lower(), ship.faults.size(), UI.pebs(junk.potential)]
	var buy := UI.button("Buy · %s" % UI.pebs(junk.price), _buy.bind(junk), 17)
	buy.disabled = GameState.pebs < int(junk.price)
	var look := UI.button("Look", _show.bind(ship, junk.key), 17)
	return _card("The " + ship.name, info, [look, buy])


func _project_card(id: String) -> PanelContainer:
	var ship: Dictionary = GameState.ships[id]
	var broken: int = ship.get("faults", []).filter(func(f): return not f.fixed).size()
	var state := "Ready to sell" if broken == 0 and ship.get("grime", 0.0) <= 0 else \
		"%d fault%s left%s" % [broken, "" if broken == 1 else "s", ", and filthy" if ship.get("grime", 0.0) > 0 else ""]
	var buttons: Array = [UI.button("Look", _show.bind(ship, id), 16),
		UI.button("Work on her", func(): Router.go("workbench", {"ship": id}), 16)]
	var racing := GameState.race_ship == id
	var race := UI.button("Racing her" if racing else "Race her", _race.bind(id), 16)
	race.disabled = racing or broken > 0
	buttons.append(race)
	var card := _card("The " + ship.name, "%s. Worth %s as she stands." % [state,
		UI.pebs(Trade.ship_value(ship, Content.parts, []))], buttons)
	for b in GameState.buyers(id):
		var who: Dictionary = b.pilot
		var face := Portrait.new()
		face.custom_minimum_size = Vector2(64, 80)
		face.show_pilot(who, "happy")
		var likes := "Loves %s" % who.taste[0]
		var sell := UI.button("Sell to %s · %s" % [who.short, UI.pebs(b.price)], _sell.bind(id, b.price, who.short), 16)
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.get_child(0).add_child(UI.hbox([face, UI.vbox([UI.label(likes, 14, UI.MUTED), sell], 2)], 8))
	return card


func _card(title: String, info: String, buttons: Array) -> PanelContainer:
	var text := UI.label(info, 15, UI.MUTED, true)
	text.custom_minimum_size.x = 420
	var row := UI.hbox(buttons, 8)
	return UI.panel(UI.vbox([UI.heading(title, 19), text, row], 6), Color.WHITE, 12)


func _buy(junk: Dictionary) -> void:
	Sfx.play("coins")
	var id := GameState.buy_junker(junk)
	Router.toast("The %s is yours. She's in the garage." % junk.ship.name)
	_shown = ""
	_fill()
	_show(GameState.ships[id], id)


func _sell(id: String, price: int, buyer: String) -> void:
	Sfx.play("coins")
	var name: String = GameState.ships[id].name
	GameState.sell_ship(id, price, buyer)
	Router.toast("Sold the %s to %s for %s.  Craft +20" % [name, buyer, UI.pebs(price)])
	_shown = ""
	if _model:
		_model.queue_free()
		_model = null
	_fill()


func _race(id: String) -> void:
	GameState.race_ship = id
	GameState.save()
	Router.toast("You'll race the %s." % GameState.ships[id].name)
	_fill()
