extends Node2D

@export var levels: Array[PackedScene] = []
@export var move_trail_enabled: bool = false
@export var move_trail_fade_enabled: bool = false

@onready var level_host: Node2D = $LevelHost
@onready var scenery: AutumnScenery = $AutumnScenery
@onready var win_panel: Control = $UI/WinPanel
@onready var win_art: TextureRect = $UI/WinPanel/Panel/VBox/WinArt
@onready var next_btn: TextureButton = $UI/WinPanel/Panel/VBox/NextButton
@onready var tada: AudioStreamPlayer = $Tada

var _index := 0
var _level: Level

func _ready() -> void:
	if levels.is_empty():
		levels = [
			load("res://levels/level_01.tscn"),
			load("res://levels/level_02.tscn"),
		]
	App.ensure_music()
	next_btn.pressed.connect(_next_level)
	win_panel.visible = false
	level_host.visible = true
	get_viewport().size_changed.connect(_center_level)
	_load_current()

func _process(delta: float) -> void:
	if _level:
		_level.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_load_current()
		get_viewport().set_input_as_handled()
		return
	if _level and _level.handle_input(event):
		if not _level.has_won():
			win_panel.visible = false
		get_viewport().set_input_as_handled()

func _load_current() -> void:
	if _level:
		_level.queue_free()
		_level = null
	if _index < 0 or _index >= levels.size() or levels[_index] == null:
		win_art.visible = false
		next_btn.visible = false
		win_panel.visible = true
		return
	_level = levels[_index].instantiate()
	_level.move_trail_enabled = move_trail_enabled
	_level.move_trail_fade_enabled = move_trail_fade_enabled
	level_host.add_child(_level)
	_level.won.connect(_on_level_won)
	win_panel.visible = false
	await get_tree().process_frame
	_center_level()

func _center_level() -> void:
	if _level == null or not is_instance_valid(_level):
		return
	var board: Board = _level.get_node_or_null("Board") as Board
	if board == null:
		return
	var board_size := Vector2(board.columns * board.cell_size, board.rows * board.cell_size)
	var view := get_viewport().get_visible_rect().size
	level_host.position = ((view - board_size) * 0.5).floor()
	if scenery:
		scenery.rebuild(level_host.position, board_size, view)

func _next_level() -> void:
	if _index + 1 >= levels.size():
		win_art.visible = true
		next_btn.visible = false
		win_panel.visible = true
		return
	_index += 1
	_load_current()

func _on_level_won() -> void:
	win_art.visible = true
	next_btn.visible = _index + 1 < levels.size()
	win_panel.visible = true
	tada.play()
