class_name Piece
extends Node2D

signal moved

@export var cell: Vector2i
@export var is_text: bool = false
@export var id: StringName = &"pip"

const OBJECT_COLORS := {
	&"pip": Color(0.851, 0.341, 0.388),
	&"acorn": Color(0.55, 0.32, 0.14),
	&"bush": Color(55 / 255.0, 148 / 255.0, 110 / 255.0),
	&"leaf": Color(31 / 255.0, 129 / 255.0, 5 / 255.0),
	&"wall": Color(0.22, 0.22, 0.22),
}

const WORD_COLORS := {
	&"pip": Color(0.851, 0.341, 0.388),
	&"acorn": Color(0.55, 0.32, 0.14),
	&"bush": Color(55 / 255.0, 148 / 255.0, 110 / 255.0),
	&"leaf": Color(31 / 255.0, 129 / 255.0, 5 / 255.0),
	&"is": Color(0.85, 0.85, 0.85),
	&"you": Color(0.95, 0.35, 0.55),
	&"win": Color(0.95, 0.82, 0.25),
	&"stop": Color(0.67, 0.2, 0.2),
	&"push": Color(0.45, 0.75, 0.55),
}

const SPRITES := {
	"acorn|0": preload("res://assets/tiles/acorn.png"),
	"acorn|1": preload("res://assets/tiles/acorn_text.png"),
	"bush|0": preload("res://assets/tiles/bush.png"),
	"bush|1": preload("res://assets/tiles/bush_text.png"),
	"leaf|0": preload("res://assets/tiles/leaf.png"),
	"leaf|1": preload("res://assets/tiles/leaf_text.png"),
	"pip|1": preload("res://assets/tiles/pip_text.png"),
	"is|1": preload("res://assets/tiles/is_text.png"),
	"you|1": preload("res://assets/tiles/you_text.png"),
	"win|1": preload("res://assets/tiles/win_text.png"),
	"stop|1": preload("res://assets/tiles/stop_text.png"),
	"wall|0": preload("res://assets/tiles/wall_text.png"),
	"wall|1": preload("res://assets/tiles/wall_text.png"),
}

const UI_FONT := preload("res://assets/fonts/comicneue.ttf")
const PIP_RIGHT := preload("res://assets/tiles/pip_right.png")
const PIP_DOWN := preload("res://assets/tiles/pip_down.png")
const PIP_UP := preload("res://assets/tiles/pip_up.png")

var _board: Board
var _sprite: Sprite2D
var facing: Vector2i = Vector2i.DOWN
var _move_tween: Tween

func setup(board: Board, at: Vector2i, text: bool, piece_id: StringName) -> void:
	_board = board
	cell = at
	is_text = text
	id = piece_id
	facing = Vector2i.DOWN
	_build_visual()
	snap_to_cell()

func snap_to_cell() -> void:
	position = _board.cell_center(cell)
	refresh_depth()

func set_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO or not _has_directional_art():
		return
	facing = direction
	_apply_facing()

func animate_to_cell(duration: float, reverse: bool = false) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var dest := _board.cell_center(cell)
	if reverse and _has_directional_art():
		# Face opposite of travel — reversed playback of the normal move anim.
		var delta := dest - position
		var face := Vector2i.ZERO
		if absf(delta.x) >= absf(delta.y) and absf(delta.x) > 0.01:
			face = Vector2i.LEFT if delta.x > 0.0 else Vector2i.RIGHT
		elif absf(delta.y) > 0.01:
			face = Vector2i.UP if delta.y > 0.0 else Vector2i.DOWN
		if face != Vector2i.ZERO:
			set_facing(face)
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD)
	_move_tween.set_ease(Tween.EASE_IN if reverse else Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", dest, duration)
	_move_tween.finished.connect(func() -> void:
		snap_to_cell()
		moved.emit()
	)

func refresh_depth() -> void:
	z_as_relative = false
	z_index = int(global_position.y)

func _process(_delta: float) -> void:
	if _move_tween != null and _move_tween.is_running():
		refresh_depth()

func display_name() -> String:
	if id == &"wall":
		return "#"
	return String(id).to_upper()

func _has_directional_art() -> bool:
	return not is_text and id == &"pip"

func _sprite_key() -> String:
	return "%s|%d" % [String(id), 1 if is_text else 0]

func _apply_facing() -> void:
	if _sprite == null or not _has_directional_art():
		return
	match facing:
		Vector2i.UP:
			_sprite.texture = PIP_UP
			_sprite.flip_h = false
		Vector2i.DOWN:
			_sprite.texture = PIP_DOWN
			_sprite.flip_h = false
		Vector2i.LEFT:
			_sprite.texture = PIP_RIGHT
			_sprite.flip_h = true
		Vector2i.RIGHT:
			_sprite.texture = PIP_RIGHT
			_sprite.flip_h = false
		_:
			_sprite.texture = PIP_DOWN
			_sprite.flip_h = false
	_fit_sprite(_sprite)

func _fit_sprite(sprite: Sprite2D) -> void:
	var size := float(_board.cell_size)
	var tex_size: Vector2 = sprite.texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest > 0.0:
		sprite.scale = Vector2.ONE * (size / longest)

func _make_sprite(tex: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_sprite(sprite)
	return sprite

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()
	_sprite = null

	if _has_directional_art():
		_sprite = _make_sprite(PIP_DOWN)
		add_child(_sprite)
		_apply_facing()
		return

	var key := _sprite_key()
	if SPRITES.has(key):
		_sprite = _make_sprite(SPRITES[key])
		add_child(_sprite)
		return

	var size := float(_board.cell_size)
	var pad := size * 0.08
	var body := ColorRect.new()
	body.position = Vector2(-size * 0.5 + pad, -size * 0.5 + pad)
	body.size = Vector2(size - pad * 2.0, size - pad * 2.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = body.position
	label.size = body.size
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18 if is_text else 20)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = display_name()
	add_child(label)

	if is_text:
		body.color = WORD_COLORS.get(id, Color(0.85, 0.85, 0.85))
	else:
		body.color = OBJECT_COLORS.get(id, Color(0.5, 0.5, 0.5))
