## Boot: opens the title screen, or a chosen screen in a prepared state for screenshots.
##
## Command line (after --): --screen=name --fixture=name --talk=scene --shot=path.png --wait=seconds
## A shot run saves one frame and quits, using a throwaway save file.
extends Node


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if "shot" in args:
		GameState.save_path = "user://shot_save.json"
	if "fixture" in args:
		Fixtures.apply(args.fixture)
	await Router.go(args.get("screen", "title"), args)
	if "tablet" in args:
		Tablet.open()
	if "talk" in args:
		# A generated customer on the bench is the scene's guest.
		var guest := ""
		if not GameState.job.is_empty():
			var pilot_id: String = GameState.job_spec(GameState.job.id).pilot
			guest = pilot_id if GameState.pilot(pilot_id).get("generated", false) else ""
		Router.talk(args.talk, guest)
	if "shot" in args:
		await get_tree().create_timer(float(args.get("wait", "1.5"))).timeout
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
