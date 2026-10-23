## Line-based dialogue scripts and a runner that steps through them.
##
## Format, one statement per line:
##   == scene_id                   starts a scene
##   odessa happy: Hello, {name}.  a line (speaker, optional expression); "you" is the player
##   * The engine ticks.           narration
##   > Sure thing => yes           choice options; consecutive lines form one choice
##   -- yes                        a label to jump to
##   => yes                        jump
##   ? flag_name => yes            jump if a flag is set
##   ! set flag_name               a command; the runner hands it to the game
##   end                           stop
## Blank lines and lines starting with # are ignored.
class_name Dialogue
extends RefCounted

static var _say := RegEx.create_from_string("^([a-z_]+)(?:\\s+([a-z_]+))?\\s*:\\s*(.+)$")


static func parse(source: String) -> Dictionary:
	var scenes := {}
	var current: Array = []
	for raw in source.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			current = []
			scenes[line.substr(2).strip_edges()] = current
			continue
		assert(scenes.size() > 0, "dialogue line outside a scene: " + line)
		current.append(_statement(line, current))
	for id in scenes:
		_check_labels(id, scenes[id])
	return scenes


static func _statement(line: String, current: Array) -> Dictionary:
	if line == "end":
		return {"t": "end"}
	if line.begins_with(">"):
		var parts := line.substr(1).split("=>")
		assert(parts.size() == 2, "choice needs '=> label': " + line)
		var option := {"text": parts[0].strip_edges(), "to": parts[1].strip_edges()}
		if not current.is_empty() and current[-1].t == "choice":
			current[-1].options.append(option)
			# Popped so the caller re-appends the merged choice in the same place.
			return current.pop_back()
		return {"t": "choice", "options": [option]}
	if line.begins_with("--"):
		return {"t": "label", "name": line.substr(2).strip_edges()}
	if line.begins_with("=>"):
		return {"t": "goto", "to": line.substr(2).strip_edges()}
	if line.begins_with("?"):
		var parts := line.substr(1).split("=>")
		return {"t": "if", "flag": parts[0].strip_edges(), "to": parts[1].strip_edges()}
	if line.begins_with("!"):
		var words := line.substr(1).strip_edges().split(" ", false)
		return {"t": "cmd", "cmd": words[0], "args": Array(words.slice(1))}
	if line.begins_with("*"):
		return {"t": "say", "who": "", "expr": "", "text": line.substr(1).strip_edges()}
	var m := _say.search(line)
	assert(m != null, "can't read dialogue line: " + line)
	return {"t": "say", "who": m.get_string(1), "expr": m.get_string(2), "text": m.get_string(3)}


static func _check_labels(id: String, statements: Array) -> void:
	var labels := {}
	for s in statements:
		if s.t == "label":
			labels[s.name] = true
	for s in statements:
		var targets: Array = []
		if s.t in ["goto", "if"]:
			targets = [s.to]
		elif s.t == "choice":
			targets = s.options.map(func(o): return o.to)
		for to in targets:
			assert(labels.has(to), "scene '%s' jumps to missing label '%s'" % [id, to])


## Steps through one scene. `step()` returns the next "say", "choice" or "end" statement, running
## jumps itself and passing commands to `on_command`. `has_flag` answers "?" checks.
class Runner:
	extends RefCounted

	var statements: Array
	var at := 0
	var on_command: Callable
	var has_flag: Callable

	func _init(scene: Array, command_handler: Callable, flag_check: Callable) -> void:
		statements = scene
		on_command = command_handler
		has_flag = flag_check

	func step() -> Dictionary:
		while at < statements.size():
			var s: Dictionary = statements[at]
			at += 1
			match s.t:
				"label":
					pass
				"goto":
					_jump(s.to)
				"if":
					if has_flag.call(s.flag):
						_jump(s.to)
				"cmd":
					on_command.call(s.cmd, s.args)
				_:
					return s
		return {"t": "end"}

	func choose(option: int) -> void:
		var choice: Dictionary = statements[at - 1]
		assert(choice.t == "choice", "choose() called when not at a choice")
		_jump(choice.options[option].to)

	func _jump(label: String) -> void:
		for i in statements.size():
			if statements[i].t == "label" and statements[i].name == label:
				at = i + 1
				return
