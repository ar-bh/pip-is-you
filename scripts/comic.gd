extends Control

const DEFAULT_COMICS: Array[String] = [
	"res://assets/comics/comic1.png",
	"res://assets/comics/comic2.png",
	"res://assets/comics/comic3.png",
	"res://assets/comics/comic4.png",
	"res://assets/comics/comic5.png",
]
const PARALLAX_SPEED := 12.0
const GRID_MARGIN := 36.0
const GRID_GAP := 18.0
const NEXT_HEIGHT := 72.0

@export var comic_paths: Array[String] = []
@export var next_scene_path: String = "res://scenes/game.tscn"
@export var parallax_texture: Texture2D

@onready var parallax_a: TextureRect = $Parallax/LayerA
@onready var parallax_b: TextureRect = $Parallax/LayerB
@onready var panels_root: Control = $Panels
@onready var next_btn: TextureButton = $NextButton
@onready var next_plate: ColorRect = $NextPlate

var _panels: Array[TextureRect] = []
var _revealed := 0
var _scroll := 0.0

func _ready() -> void:
	App.ensure_music()
	if comic_paths.is_empty():
		comic_paths = DEFAULT_COMICS.duplicate()
	if parallax_texture != null:
		parallax_a.texture = parallax_texture
		parallax_b.texture = parallax_texture
	next_btn.pressed.connect(_on_next)
	get_viewport().size_changed.connect(_fit_layout)
	_build_panels()
	_fit_layout()
	_reveal_next()

func _process(delta: float) -> void:
	var tile_w: float = parallax_a.size.x
	if tile_w <= 1.0:
		return
	_scroll = fmod(_scroll + PARALLAX_SPEED * delta, tile_w)
	parallax_a.position.x = -_scroll
	parallax_b.position.x = -_scroll + tile_w

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_on_next()
		get_viewport().set_input_as_handled()

func _build_panels() -> void:
	for child in panels_root.get_children():
		child.queue_free()
	_panels.clear()
	for path in comic_paths:
		var panel := TextureRect.new()
		panel.texture = load(path)
		panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.visible = false
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panels_root.add_child(panel)
		_panels.append(panel)

func _fit_layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_fit_parallax(view)
	_fit_grid(view)
	_fit_next(view)

func _fit_parallax(view: Vector2) -> void:
	var tex := parallax_a.texture.get_size()
	var s := maxf(view.y / tex.y, view.x / tex.x)
	var tile := Vector2(tex.x * s, tex.y * s)
	for layer in [parallax_a, parallax_b]:
		layer.size = tile
		layer.position.y = (view.y - tile.y) * 0.5
	parallax_a.position.x = -_scroll
	parallax_b.position.x = -_scroll + tile.x

func _fit_grid(view: Vector2) -> void:
	var bottom_reserve := NEXT_HEIGHT + 28.0
	var area := Rect2(
		GRID_MARGIN,
		GRID_MARGIN,
		view.x - GRID_MARGIN * 2.0,
		view.y - GRID_MARGIN * 2.0 - bottom_reserve,
	)
	var count := _panels.size()
	if count <= 0:
		return
	# Prefer a 3-wide top row; leftover panels center on the next row.
	var cols := 3 if count > 2 else count
	var rows := int(ceil(float(count) / float(cols)))
	var cell_w := (area.size.x - GRID_GAP * float(maxi(cols - 1, 0))) / float(cols)
	var cell_h := (area.size.y - GRID_GAP * float(maxi(rows - 1, 0))) / float(maxi(rows, 1))
	var cell := minf(cell_w, cell_h)
	var grid_w := cell * float(cols) + GRID_GAP * float(maxi(cols - 1, 0))
	var grid_h := cell * float(rows) + GRID_GAP * float(maxi(rows - 1, 0))
	var origin := Vector2(
		area.position.x + (area.size.x - grid_w) * 0.5,
		area.position.y + (area.size.y - grid_h) * 0.5,
	)
	for i in count:
		var row := int(i / cols)
		var col_in_row := i % cols
		var panels_in_row := mini(cols, count - row * cols)
		var row_w := cell * float(panels_in_row) + GRID_GAP * float(maxi(panels_in_row - 1, 0))
		var row_x := origin.x + (grid_w - row_w) * 0.5
		_panels[i].position = Vector2(
			row_x + float(col_in_row) * (cell + GRID_GAP),
			origin.y + float(row) * (cell + GRID_GAP),
		)
		_panels[i].size = Vector2(cell, cell)

func _fit_next(view: Vector2) -> void:
	var w := minf(220.0, view.x * 0.28)
	var pos := Vector2((view.x - w) * 0.5, view.y - NEXT_HEIGHT - 16.0)
	next_plate.position = pos + Vector2(-10, -6)
	next_plate.size = Vector2(w + 20, NEXT_HEIGHT + 12)
	next_btn.custom_minimum_size = Vector2(w, NEXT_HEIGHT)
	next_btn.size = Vector2(w, NEXT_HEIGHT)
	next_btn.position = pos

func _reveal_next() -> void:
	_panels[_revealed].visible = true
	_revealed += 1

func _on_next() -> void:
	if _revealed >= _panels.size():
		App.ensure_music()
		get_tree().change_scene_to_file(next_scene_path)
		return
	_reveal_next()
