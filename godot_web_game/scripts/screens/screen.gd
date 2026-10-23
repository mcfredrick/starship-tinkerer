## Base for screens: an optional 3D stage behind a full-window UI layer.
class_name Screen
extends Node

var stage: Stage
var ui: Control


func _init() -> void:
	ui = UI.full(Control.new())
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	ui.theme = Router.theme
	add_child(ui)


func add_stage() -> Stage:
	stage = Stage.new()
	add_child(stage)
	move_child(stage, 0)
	return stage


func show_ship(ship_id: String) -> ShipModel:
	var model := ShipModel.new()
	stage.cradle.add_child(model)
	model.build(GameState.ships[ship_id])
	return model
