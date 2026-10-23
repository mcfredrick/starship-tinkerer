## A hawker's cart, parked outside the shop: four offers, maybe something they're buying, and a
## hawker with opinions about all of it.
extends Screen

var _cards: GridContainer
var _wanted: VBoxContainer
var _visit: Dictionary
var _who: Dictionary


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	bg.color = Color("2a2238")
	ui.add_child(bg)
	_visit = GameState.hawker_today()
	_who = GameState.pilot(_visit.id)
	var portrait := Portrait.new()
	portrait.show_pilot(_who, "happy")
	UI.place(portrait, Control.PRESET_BOTTOM_LEFT, Vector2(10, -500), Vector2(400, 500))
	ui.add_child(portrait)
	ui.add_child(Hud.new())

	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.add_theme_constant_override("h_separation", 12)
	_cards.add_theme_constant_override("v_separation", 12)
	_wanted = UI.vbox([], 6)
	var box := UI.vbox([UI.heading("%s's cart" % _who.name, 30), UI.label(_who.blurb, 17, UI.MUTED, true), _cards,
		_wanted, UI.button("Back to the shop", func(): Router.go("shop"), 20)], 12)
	var panel := UI.panel(box, Color(UI.CREAM, 0.97), 20)
	UI.place(panel, Control.PRESET_CENTER_RIGHT, Vector2(-760, -290), Vector2(720, 0))
	UI.fit(panel, 84)
	ui.add_child(panel)
	_fill()
	_greet.call_deferred()


func _greet() -> void:
	var seen := "met_%s_%d" % [_visit.id, GameState.day]
	if not GameState.flags.has(seen):
		GameState.flags[seen] = true
		await Router.talk("hawker_" + _visit.id)


func _fill() -> void:
	for c in _cards.get_children() + _wanted.get_children():
		c.queue_free()
	var offers: Array = _visit.cart.offers
	for i in offers.size():
		_cards.add_child(_card(offers[i], i))
	var slot: String = _visit.cart.wanted
	if slot == "":
		return
	_wanted.add_child(UI.heading("%s is buying %s, and paying well." % [_who.short, SLOT_WORDS[slot]], 19, UI.TEAL, true))
	var any := false
	for id in GameState.parts:
		if Content.part(id).slot == slot:
			any = true
			var price := roundi(Market.resale(id) * 1.3)
			_wanted.add_child(UI.button("Sell your %s · %s" % [Content.part(id).name, UI.pebs(price)], _sell.bind(id, price), 17))
	if not any:
		_wanted.add_child(UI.label("You haven't any spare on your shelves.", 16, UI.MUTED))


func _card(offer: Dictionary, index: int) -> PanelContainer:
	var title := ""
	var desc := ""
	match offer.kind:
		"worn":
			title = "Worn %s" % Content.part(offer.part).name.to_lower()
			desc = "\"Barely used.\" It has been used a great deal. Restore it and it's good as new."
		"part":
			title = Content.part(offer.part).name
			desc = Content.part(offer.part).desc
		"trinket":
			title = Content.trade.trinkets[offer.trinket].name
			desc = Content.trade.trinkets[offer.trinket].desc
		"mystery":
			title = "Mystery crate"
			desc = "Could be anything. Probably bolts."
			# A trained ear can tell what's rattling inside.
			if Skills.level(GameState.skills.diagnostics) >= 2:
				desc += " " + ("It rattles like something solid." if offer.tier != "junk" else "It sounds like loose bolts.")
	var sold: bool = index in _visit.bought
	var b := UI.button("Sold" if sold else "Buy · %s" % UI.pebs(offer.price), _buy.bind(index), 17)
	b.disabled = sold or GameState.pebs < int(offer.price)
	var text := UI.label(desc, 15, UI.MUTED, true)
	text.custom_minimum_size.x = 300
	var card := UI.panel(UI.vbox([UI.heading(title, 19), text, b], 6), Color.WHITE, 12)
	card.custom_minimum_size.x = 330
	return card


func _buy(index: int) -> void:
	Sfx.play("coins")
	Router.toast(GameState.buy_from_cart(index))
	_fill()


func _sell(id: String, price: int) -> void:
	Sfx.play("coins")
	GameState.take(GameState.parts, id)
	GameState.add_pebs(price, "Sold a %s to %s" % [Content.part(id).name, _who.short])
	GameState.save()
	_fill()


const SLOT_WORDS := {"engine": "engines", "fins": "fins", "cockpit": "cockpits", "lights": "lights"}
