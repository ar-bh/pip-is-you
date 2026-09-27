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
@onready var guide_plate: PanelContainer = $UI/GuidePlate
@onready var guide_label: Label = $UI/GuidePlate/GuideLabel
@onready var tada: AudioStreamPlayer = $Tada
@onready var ui_layer: CanvasLayer = $UI

var _index := 0
var _level: Level
var _guide_base_y := 0.0
var _guide_phase := 0.0
var _undo_hint_active := false
var _guide_fade := 1.0
var _guide_covering := false
## First board row whose cell overlaps the guide band. Fade while YOU is on/below it.
var _guide_fade_min_row := 999
var _flash: ColorRect
var _flash_tween: Tween

const _GUIDE_COLOR := Color(0.08, 0.08, 0.08, 1)
const _UNDO_HINT_COLOR := Color(0.55, 0.28, 0.05, 1)
const _FLASH_COLOR := Color(0.85, 0.08, 0.08, 0.55)
const _GUIDE_FADE_ALPHA := 0.08
const _GUIDE_FADE_SPEED := 5.0
const _GUIDE_BOB := 3.0

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
			load("res://levels/level_04.tscn"),
			load("res://levels/level_05.tscn"),
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
	_setup_flash()
	_load_current()

func _setup_flash() -> void:
	_flash = ColorRect.new()
	_flash.name = "NoYouFlash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(_FLASH_COLOR.r, _FLASH_COLOR.g, _FLASH_COLOR.b, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.offset_left = 0.0
	_flash.offset_top = 0.0
	_flash.offset_right = 0.0
	_flash.offset_bottom = 0.0
	ui_layer.add_child(_flash)
	# Keep under win/hint UI but above the game.
	ui_layer.move_child(_flash, 0)

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
	_update_guide(delta)

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
		guide_plate.visible = false
		win_panel.visible = true
		return
	_level = levels[_index].instantiate()
	_level.move_trail_enabled = move_trail_enabled
	_level.move_trail_fade_enabled = move_trail_fade_enabled
	level_host.add_child(_level)
	_level.won.connect(_on_level_won)
	_level.rules_changed.connect(_on_rules_changed)
	win_panel.visible = false
	_refresh_hint_ui()
	_refresh_guide_ui()
	await get_tree().process_frame
	_center_level()

func _on_rules_changed(_text: String) -> void:
	# Only update guide copy / undo-hint mode. Never reset fade here —
	# rules_changed fires after every move and was causing the opaque flash.
	_refresh_guide_ui(false)

func _refresh_hint_ui() -> void:
	var text := ""
	if _level:
		text = _level.hint_text.strip_edges()
	hint_btn_plate.visible = not text.is_empty()
	hint_btn.visible = not text.is_empty()
	hint_label.text = text
	hint_panel.visible = false
	_fit_hint_ui()

func _refresh_guide_ui(reset_fade: bool = true) -> void:
	var was_undo_hint := _undo_hint_active
	_undo_hint_active = false
	if _level and is_instance_valid(_level) and not _level.has_won() and not _level.has_you():
		_undo_hint_active = true
		guide_label.text = "YOU has no form. press Z to undo or R to restart"
		guide_plate.visible = true
		guide_label.add_theme_color_override("font_color", _UNDO_HINT_COLOR)
		guide_label.add_theme_font_size_override("font_size", 26)
		if not was_undo_hint:
			_flash_no_you()
	else:
		var text := ""
		if _level:
			text = _level.guide_text.strip_edges()
		guide_label.text = text
		guide_plate.visible = not text.is_empty()
		guide_label.add_theme_color_override("font_color", _GUIDE_COLOR)
		guide_label.add_theme_font_size_override("font_size", 24)
	if reset_fade:
		_guide_fade = 1.0
		_guide_covering = false
		guide_plate.modulate = Color.WHITE
	_fit_guide_ui()
	_recompute_guide_fade_rows()

func _flash_no_you() -> void:
	if _flash == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = _FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	if guide_plate == null or guide_label == null:
		return
	var view := get_viewport().get_visible_rect().size
	var width := view.x - 48.0
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.custom_minimum_size = Vector2(width - 36.0, 0.0)
	guide_label.size = Vector2(width - 36.0, 0.0)
	guide_label.reset_size()
	var label_h := maxf(guide_label.get_minimum_size().y, guide_label.get_combined_minimum_size().y)
	guide_label.size = Vector2(width - 36.0, label_h)
	guide_plate.reset_size()
	var plate_size := guide_plate.get_combined_minimum_size()
	plate_size.x = width
	plate_size.y = maxf(plate_size.y, label_h + 20.0)
	guide_plate.size = plate_size
	guide_plate.scale = Vector2(1.08, 0.94)
	var draw_w := plate_size.x * guide_plate.scale.x
	_guide_base_y = view.y - plate_size.y * guide_plate.scale.y - 20.0
	guide_plate.position = Vector2((view.x - draw_w) * 0.5, _guide_base_y)
	_recompute_guide_fade_rows()

func _recompute_guide_fade_rows() -> void:
	# Map guide overlap to discrete board rows so fade never depends on
	# animated sprite positions (which caused mid-move flashing).
	_guide_fade_min_row = 999
	if _level == null or not is_instance_valid(_level) or guide_plate == null:
		return
	var board: Board = _level.get_node_or_null("Board") as Board
	var pieces_root := _level.get_node_or_null("Pieces") as Node2D
	if board == null or pieces_root == null:
		return
	var xform := pieces_root.get_global_transform_with_canvas()
	var pad := float(board.cell_size) * 0.4
	var mid_x := board.columns / 2
	for y in range(board.rows):
		var cy := (xform * board.cell_center(Vector2i(mid_x, y))).y
		if cy + pad >= _guide_base_y:
			_guide_fade_min_row = y
			return

func _guide_should_fade() -> bool:
	if guide_plate == null or not guide_plate.visible:
		return false
	# Mouse over the stable bottom guide band (ignores bob).
	var view := get_viewport().get_visible_rect()
	var guide_h := guide_plate.size.y * guide_plate.scale.y
	var band := Rect2(0.0, _guide_base_y - 12.0, view.size.x, guide_h + 32.0)
	if band.has_point(get_viewport().get_mouse_position()):
		return true
	if _level == null or not is_instance_valid(_level):
		return false
	for piece in _level.get_you_pieces():
		if piece != null and is_instance_valid(piece) and piece.cell.y >= _guide_fade_min_row:
			return true
	return false

func _update_guide(delta: float) -> void:
	if guide_plate == null or not guide_plate.visible:
		return
	_guide_phase += delta * 2.2
	var bob := sin(_guide_phase) * _GUIDE_BOB
	guide_plate.position.y = _guide_base_y + bob

	_guide_covering = _guide_should_fade()
	var target := _GUIDE_FADE_ALPHA if _guide_covering else 1.0
	_guide_fade = move_toward(_guide_fade, target, _GUIDE_FADE_SPEED * delta)
	var c := Color(1, 1, 1, _guide_fade)
	if _undo_hint_active and not _guide_covering:
		var pulse := 0.88 + 0.12 * (0.5 + 0.5 * sin(_guide_phase * 2.4))
		c = Color(pulse, pulse, pulse, _guide_fade)
	guide_plate.modulate = c

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
		var cell_r := float(board.cell_size) * 0.75
		for piece in _level.pieces:
			blocked.append(level_host.position + piece.position)
		scenery.rebuild(level_host.position, board_size, view, _index, blocked, cell_r)
	for piece in _level.pieces:
		piece.refresh_depth()
	_recompute_guide_fade_rows()

func _next_level() -> void:
	if _index + 1 >= levels.size():
		App.ensure_music()
		get_tree().change_scene_to_file("res://scenes/end_comic.tscn")
		return
	_index += 1
	_load_current()

func get_level_index() -> int:
	return _index

func get_level_count() -> int:
	return levels.size()

func go_back_level() -> void:
	if _index <= 0:
		return
	_index -= 1
	win_panel.visible = false
	_load_current()

func skip_level() -> void:
	_next_level()

func _on_level_won() -> void:
	hint_panel.visible = false
	hint_btn_plate.visible = false
	hint_btn.visible = false
	guide_plate.visible = false
	win_art.visible = true
	next_btn.visible = true
	win_panel.visible = true
	tada.play()
