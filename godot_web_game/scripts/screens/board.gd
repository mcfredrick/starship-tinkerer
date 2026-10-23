## The job board: today's walk-ins, each a card with who they are, their ship, what they want and
## what it pays. Taking one brings their ship into the bay.
extends Screen


func _ready() -> void:
	super()
	var bg := UI.full(ColorRect.new())
	bg.color = Color("2a2238")
	ui.add_child(bg)
	ui.add_child(Hud.new())
	var cards := UI.hbox([], 16)
	var offers := GameState.job_board()
	for i in offers.size():
		cards.add_child(_card(offers[i], i))
	if offers.is_empty():
		cards.add_child(UI.label("The board's empty. Everyone who stopped by today has been seen to.", 20, UI.CREAM, true))
	var box := UI.vbox([UI.heading("The job board", 32, UI.CREAM),
		UI.label("Walk-ins pin their requests here. Take one on and their ship comes into the bay.", 18,
			Color(UI.CREAM, 0.75), true), cards, UI.button("Back to the shop", func(): Router.go("shop"), 20)], 14)
	UI.place(box, Control.PRESET_CENTER, Vector2(-580, -280), Vector2(1160, 0))
	UI.fit(box, 84)
	ui.add_child(box)


func _card(offer: Dictionary, index: int) -> PanelContainer:
	var who: Dictionary = offer.pilot
	var job: Dictionary = offer.job
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(170, 212)
	portrait.show_pilot(who, "happy")
	var steps := 0
	for f in job.faults:
		steps += Content.parts.faults[f.type].steps.size()
	var work := "%d fault%s, %d step%s of work" % [job.faults.size(), "" if job.faults.size() == 1 else "s", steps,
		"" if steps == 1 else "s"]
	var pay := "Pays %s" % UI.pebs(job.budget)
	for item in job.barter:
		pay += ", plus %s" % Content.item(item).name
	var hull: String = Content.parts.hulls[offer.ship.hull].name
	var info := UI.vbox([
		UI.heading(who.name, 22),
		UI.label("A regular" if who.get("regular", false) else "New face", 14, UI.ROSE if who.get("regular", false) else UI.MUTED),
		UI.label(who.blurb, 15, UI.MUTED, true),
		UI.label("The %s, a %s" % [offer.ship.name, hull.to_lower()], 16, UI.TEAL, true),
	], 4)
	var top := UI.hbox([portrait, info], 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var request := UI.label("\"%s\"" % job.request, 16, UI.INK, true)
	request.custom_minimum_size.x = 330
	var body := UI.vbox([top, request, UI.label(work, 16, UI.MUTED), UI.heading(pay, 20, UI.AMBER_DARK),
		UI.button("Take the job", _take.bind(index), 20)], 8)
	var card := UI.panel(body, UI.CREAM, 16)
	card.custom_minimum_size.x = 370
	return card


func _take(index: int) -> void:
	var manner: String = GameState.board[index].pilot.traits[0]
	var id := GameState.accept_offer(index)
	var scene := "walkin_arrives_" + manner
	if GameState.cast[id].visits > 1:
		scene = "walkin_returns"
	await Router.talk(scene if Content.dialogue.has(scene) else "walkin_arrives", id)
	await Router.story(id, "arrive")
	Router.go("shop")
