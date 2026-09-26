class_name Piece
extends Node2D

## One tile on the board: forest object or word block.

signal moved

@export var cell: Vector2i
@export var is_text: bool = false
@export var id: StringName = &"pip"

const OBJECT_COLORS := {
	&"pip": Color(0.86, 0.45, 0.22),
	&"acorn": Color(0.55, 0.32, 0.14),
	&"bush": Color(0.28, 0.48, 0.22),
	&"leaf": Color(0.92, 0.48, 0.18),
	&"wall": Color(0.22, 0.22, 0.22),
}

const WORD_COLORS := {
	&"pip": Color(0.86, 0.45, 0.22),
	&"acorn": Color(0.55, 0.32, 0.14),
	&"bush": Color(0.28, 0.48, 0.22),
	&"leaf": Color(0.92, 0.48, 0.18),
	&"is": Color(0.85, 0.85, 0.85),
	&"you": Color(0.95, 0.35, 0.55),
	&"win": Color(0.95, 0.82, 0.25),
	&"stop": Color(0.45, 0.55, 0.85),
	&"push": Color(0.45, 0.75, 0.55),
}

## Real art when available. Key = "id|1" for text, "id|0" for object.
const SPRITES := {
	"acorn|0": preload("res://tiles/acorn.png"),
	"acorn|1": preload("res://tiles/acorn_text.png"),
	"pip|1": preload("res://tiles/pip_text.png"),
	"is|1": preload("res://tiles/is_text.png"),
	"you|1": preload("res://tiles/you_text.png"),
	"win|1": preload("res://tiles/win_text.png"),
}

var _board: Board


func setup(board: Board, at: Vector2i, text: bool, piece_id: StringName) -> void:
	_board = board
	cell = at
	is_text = text
	id = piece_id
	_build_visual()
	snap_to_cell()


func snap_to_cell() -> void:
	position = _board.cell_center(cell)


func animate_to_cell(duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _board.cell_center(cell), duration)
	tween.finished.connect(func() -> void:
		snap_to_cell()
		moved.emit()
	)


func display_name() -> String:
	if id == &"wall":
		return "#"
	return String(id).to_upper()


func _sprite_key() -> String:
	return "%s|%d" % [String(id), 1 if is_text else 0]


func _build_visual() -> void:
	var size := float(_board.cell_size)
	var key := _sprite_key()
	if SPRITES.has(key):
		var sprite := Sprite2D.new()
		sprite.texture = SPRITES[key]
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_size: Vector2 = sprite.texture.get_size()
		var longest := maxf(tex_size.x, tex_size.y)
		if longest > 0.0:
			sprite.scale = Vector2.ONE * (size / longest)
		add_child(sprite)
		return

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
	label.add_theme_font_size_override("font_size", 13 if is_text else 15)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = display_name()
	add_child(label)

	if is_text:
		body.color = WORD_COLORS.get(id, Color(0.85, 0.85, 0.85))
	else:
		body.color = OBJECT_COLORS.get(id, Color(0.5, 0.5, 0.5))
