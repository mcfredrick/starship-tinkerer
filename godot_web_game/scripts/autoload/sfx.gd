## Sound effects: one-shots from a small player pool, and loops a caller can steer and stop.
## The sounds are synthesized by tools/sfx.py.
extends Node

const NAMES := ["click", "ping", "found", "success", "weld", "tick", "pour", "coins", "bonk", "engine", "whoosh",
	"bump", "beep", "go", "spray", "purr", "mrrp", "honk"]
const POOL := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for n in NAMES:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## A player for a looping sound (looping is set in its .import file), parented to `owner` so it
## stops when that screen goes away.
func loop(name: String, owner: Node, volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.volume_db = volume_db
	owner.add_child(p)
	return p
