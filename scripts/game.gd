extends Node2D

@export var levels: Array[PackedScene] = []
@export var move_trail_enabled: bool = false
@export var move_trail_fade_enabled: bool = false

@onready var level_host: Node2D = $LevelHost
@onready var scenery: AutumnScenery = $AutumnScenery
@onready var menu: Control = $UI/Menu
@onready var win_panel: Control = $UI/WinPanel
@onready var win_title: Label = $UI/WinPanel/Panel/VBox/WinTitle
@onready var win_hint: Label = $UI/WinPanel/Panel/VBox/WinHint
@onready var music: AudioStreamPlayer = $Music

var _index := 0
var _level: Level
var _started := false

func _ready() -> void:
	if levels.is_empty():
		levels = [
			load("res://levels/level_01.tscn"),
			load("res://levels/level_02.tscn"),
		]
	if music.stream is AudioStreamMP3:
		(music.stream as AudioStreamMP3).loop = true
	win_panel.visible = false
	menu.visible = true
	level_host.visible = false
	get_viewport().size_changed.connect(_center_level)
	_show_menu_scenery()

func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			_start_game()
			get_viewport().set_input_as_handled()
		return

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
			win_panel.visible = false
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _started and _level:
		_level.tick(delta)

func _start_game() -> void:
	if _started:
		return
	_started = true
	menu.visible = false
	level_host.visible = true
	if not music.playing:
		music.play()
	_index = 0
	_load_current()

func _show_menu_scenery() -> void:
	var view := get_viewport().get_visible_rect().size
	var board_size := Vector2(view.x * 0.42, view.y * 0.42)
	var host := ((view - board_size) * 0.5).floor()
	if scenery:
		scenery.rebuild(host, board_size, view)

func _load_current() -> void:
	if _level:
		_level.queue_free()
		_level = null
	if _index < 0 or _index >= levels.size() or levels[_index] == null:
		win_title.text = "No clearings found"
		win_hint.text = ""
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
	if not _started:
		_show_menu_scenery()
		return
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
		win_title.text = "All the acorns are gathered"
		win_hint.text = "R to wander this clearing again"
		win_panel.visible = true
		return
	_index += 1
	_load_current()

func _on_level_won() -> void:
	win_title.text = "Pip found an acorn"
	win_hint.text = "Enter — next clearing"
	win_panel.visible = true
