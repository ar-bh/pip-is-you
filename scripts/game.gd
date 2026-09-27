extends Node2D

@export var levels: Array[PackedScene] = []
@export var move_trail_enabled: bool = true
@export var move_trail_fade_enabled: bool = true
@export var levels_folder: String = "res://levels"
## If true, auto-loads every level_*.tscn in levels_folder (sorted).
## Manual Levels array is only used when this is off or the folder is empty.
@export var auto_discover_levels: bool = true

@onready var level_host: Node2D = $LevelHost
@onready var scenery: AutumnScenery = $AutumnScenery
@onready var win_panel: Control = $UI/WinPanel
@onready var win_art: TextureRect = $UI/WinPanel/Panel/VBox/WinArt
@onready var next_btn: TextureButton = $UI/WinPanel/Panel/VBox/NextButton
@onready var hint_btn_plate: PanelContainer = $UI/HintButtonPlate
@onready var hint_btn: TextureButton = $UI/HintButtonPlate/HintButton
@onready var hint_panel: PanelContainer = $UI/HintPanel
@onready var hint_label: Label = $UI/HintPanel/Margin/HintLabel
@onready var guide_label: Label = $UI/GuideLabel
@onready var tada: AudioStreamPlayer = $Tada

var _index := 0
var _level: Level
var _guide_base_y := 0.0
var _guide_phase := 0.0

func _ready() -> void:
	if auto_discover_levels:
		var found := _discover_levels()
		if not found.is_empty():
			levels = found
	if levels.is_empty():
		levels = [
			load("res://levels/level_01.tscn"),
			load("res://levels/level_02.tscn"),
			load("res://levels/level_03.tscn"),
		]
	App.ensure_music()
	next_btn.pressed.connect(_next_level)
	hint_btn.pressed.connect(_toggle_hint)
	hint_panel.visible = false
	win_panel.visible = false
	level_host.visible = true
	get_viewport().size_changed.connect(_center_level)
	get_viewport().size_changed.connect(_fit_hint_ui)
	get_viewport().size_changed.connect(_fit_guide_ui)
	_fit_hint_ui()
	_fit_guide_ui()
	_load_current()

func _discover_levels() -> Array[PackedScene]:
	var found: Array[PackedScene] = []
	var paths: PackedStringArray = []
	var dir := DirAccess.open(levels_folder)
	if dir == null:
		return found
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("level_") and file_name.ends_with(".tscn"):
			paths.append(levels_folder.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	for path in paths:
		var packed: PackedScene = load(path)
		if packed != null:
			found.append(packed)
	return found

func _process(delta: float) -> void:
	if _level:
		_level.tick(delta)
		if scenery:
			scenery.update_tree_fade(_level.get_you_pieces(), level_host.position, delta)
	_bob_guide(delta)

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
	hint_panel.visible = false
	if _index < 0 or _index >= levels.size() or levels[_index] == null:
		win_art.visible = false
		next_btn.visible = false
		hint_btn_plate.visible = false
		hint_btn.visible = false
		guide_label.visible = false
		win_panel.visible = true
		return
	_level = levels[_index].instantiate()
	_level.move_trail_enabled = move_trail_enabled
	_level.move_trail_fade_enabled = move_trail_fade_enabled
	level_host.add_child(_level)
	_level.won.connect(_on_level_won)
	win_panel.visible = false
	_refresh_hint_ui()
	_refresh_guide_ui()
	await get_tree().process_frame
	_center_level()

func _refresh_hint_ui() -> void:
	var text := ""
	if _level:
		text = _level.hint_text.strip_edges()
	hint_btn_plate.visible = not text.is_empty()
	hint_btn.visible = not text.is_empty()
	hint_label.text = text
	hint_panel.visible = false
	_fit_hint_ui()

func _refresh_guide_ui() -> void:
	var text := ""
	if _level:
		text = _level.guide_text.strip_edges()
	guide_label.text = text
	guide_label.visible = not text.is_empty()
	_fit_guide_ui()

func _toggle_hint() -> void:
	if hint_label.text.is_empty():
		return
	hint_panel.visible = not hint_panel.visible
	_fit_hint_ui()

func _fit_hint_ui() -> void:
	var view := get_viewport().get_visible_rect().size
	var margin := 16.0
	hint_btn_plate.reset_size()
	var plate_size := hint_btn_plate.get_combined_minimum_size()
	hint_btn_plate.size = plate_size
	hint_btn_plate.position = Vector2(margin, margin)
	hint_panel.reset_size()
	var panel_size := hint_panel.get_combined_minimum_size()
	panel_size.x = clampf(panel_size.x, 180.0, minf(360.0, view.x - margin * 2.0))
	hint_panel.size = panel_size
	hint_panel.position = Vector2(margin, margin + plate_size.y + 8.0)

func _fit_guide_ui() -> void:
	if guide_label == null:
		return
	var view := get_viewport().get_visible_rect().size
	guide_label.reset_size()
	var size := guide_label.get_combined_minimum_size()
	size.x = minf(maxf(size.x, 280.0), view.x - 48.0)
	guide_label.size = size
	_guide_base_y = view.y - size.y - 28.0
	guide_label.position = Vector2((view.x - size.x) * 0.5, _guide_base_y)

func _bob_guide(delta: float) -> void:
	if guide_label == null or not guide_label.visible:
		return
	_guide_phase += delta * 2.2
	guide_label.position.y = _guide_base_y + sin(_guide_phase) * 4.0

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
		var blocked: Array[Vector2] = []
		# Keep whole tree canopies clear of puzzle tiles (words, walls, etc.).
		var cell_r := float(board.cell_size) * 0.75
		for piece in _level.pieces:
			blocked.append(level_host.position + piece.position)
		scenery.rebuild(level_host.position, board_size, view, _index, blocked, cell_r)
	for piece in _level.pieces:
		piece.refresh_depth()

func _next_level() -> void:
	if _index + 1 >= levels.size():
		win_art.visible = true
		next_btn.visible = false
		win_panel.visible = true
		return
	_index += 1
	_load_current()

func get_level_index() -> int:
	return _index

func go_back_level() -> void:
	if _index <= 0:
		return
	_index -= 1
	win_panel.visible = false
	_load_current()

func _on_level_won() -> void:
	hint_panel.visible = false
	hint_btn_plate.visible = false
	hint_btn.visible = false
	guide_label.visible = false
	win_art.visible = true
	next_btn.visible = _index + 1 < levels.size()
	win_panel.visible = true
	tada.play()
