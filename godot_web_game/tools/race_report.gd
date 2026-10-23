## Simulates club races with AI drivers and prints finish times, for balancing.
## Run: godot --headless --path godot_web_game --script res://tools/race_report.gd
extends SceneTree


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts.json"))
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var stock: Dictionary = world.ships.kettle
	var tuned := stock.duplicate(true)
	tuned.parts.merge({"engine": "engine_hush", "fins": "fin_swept", "lights": "lights_bar", "top": "gadget_ribbon"}, true)
	var racer := stock.duplicate(true)
	racer.parts.merge({"engine": "engine_sprint", "fins": "fin_wing", "cockpit": "cockpit_visor", "top": "gadget_ribbon"},
		true)
	for build in [["stock", stock], ["tuned", tuned], ["racer", racer]]:
		print("--- kettle ", build[0], " rating ", ShipStats.rating(ShipStats.compute(build[1], data)))
		print(report(build[1], data, world))
	quit()


static func report(kettle: Dictionary, data: Dictionary, world: Dictionary) -> String:
	var race: Dictionary = world.race.club
	var sim := RaceSim.new(Track.quietwater(), race.laps)
	var walls := {}
	var entries := [["kettle", kettle, 0.92]]
	for pilot in race.rivals:
		entries.append([pilot, world.ships[world.pilots[pilot].ship], race.rivals[pilot]])
	for entry in entries:
		var b: Dictionary = entry[1]
		sim.add_racer(entry[0], ShipStats.compute(b, data), ShipStats.gadget(b, data), true, entry[2])
		walls[entry[0]] = 0
	while not sim.finished() and sim.time < 600:
		sim.step(1.0 / 60.0, {})
		for e in sim.events:
			if e.type == "wall":
				walls[e.id] += 1
	var lines: Array = ["track %.0f m" % sim.track.length]
	for r in sim.standings():
		lines.append("%-8s %6.1fs  top %.0f  walls %d" % [r.id, r.finish, r.m.top_speed, walls[r.id]])
	return "\n".join(lines)
