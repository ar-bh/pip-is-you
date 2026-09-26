extends Node2D

## Loads TileMap levels in order. Paint new levels under res://levels/.

@export var levels: Array[PackedScene] = []

@onready var level_host: Node2D = $LevelHost
@onready var rules_label: Label = $UI/RulesLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var win_label: Label = $UI/WinLabel
@onready var level_label: Label = $UI/LevelLabel

var _index := 0
var _level: Level


func _ready() -> void:
	if levels.is_empty():
		levels = [
			load("res://levels/level_01.tscn"),
			load("res://levels/level_02.tscn"),
		]
	_load_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_load_current()
		get_viewport().set_input_as_handled()
		return
	if _level and _level.has_won() and event.is_action_pressed("ui_accept"):
		_next_level()
		get_viewport().set_input_as_handled()
		return
	if _level and _level.handle_input(event):
		if not _level.has_won():
			win_label.visible = false
			hint_label.text = "Arrows / WASD · Z undo · R restart\nPaint levels with tiles/piece_tileset.tres"
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _level:
		_level.tick(delta)


func _load_current() -> void:
	if _level:
		_level.queue_free()
		_level = null
	if _index < 0 or _index >= levels.size() or levels[_index] == null:
		win_label.text = "No levels found"
		win_label.visible = true
		return
	_level = levels[_index].instantiate()
	level_host.add_child(_level)
	_level.won.connect(_on_level_won)
	_level.rules_changed.connect(_on_rules_changed)
	_on_rules_changed(_level.rules.describe())
	win_label.visible = false
	level_label.text = "Level %d / %d" % [_index + 1, levels.size()]
	hint_label.text = "Arrows / WASD · Z undo · R restart\nPaint levels with tiles/piece_tileset.tres"


func _next_level() -> void:
	if _index + 1 >= levels.size():
		win_label.text = "All acorns found"
		win_label.visible = true
		hint_label.text = "R to replay this level"
		return
	_index += 1
	_load_current()


func _on_level_won() -> void:
	win_label.text = "Pip found an acorn!\nEnter = next level"
	win_label.visible = true
	hint_label.text = "Enter next · R restart · Z undo"


func _on_rules_changed(text: String) -> void:
	rules_label.text = "Rules\n" + text
