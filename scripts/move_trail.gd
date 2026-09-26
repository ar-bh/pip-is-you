class_name MoveTrail
extends Node2D

## Permanent path under YOU. All bottoms, then all tops (highlights always visible).

const BOTTOM_TEX := preload("res://tiles/bottom_trail.png")
const TOP_TEX := preload("res://tiles/trail_top.png")

@export var drop_distance: float = 10.0
@export var min_scale: float = 1.6
@export var max_scale: float = 2.8
@export var y_offset: float = 14.0

var _level: Level
var _last_drop: Dictionary = {} # Piece -> Vector2
var _rng := RandomNumberGenerator.new()
## Each entry: { pos, rot, scale, top_pos, top_rot, top_scale }
var _stamps: Array[Dictionary] = []


func setup(level: Level) -> void:
	_level = level
	_last_drop.clear()
	_stamps.clear()
	_rng.randomize()
	z_index = -1
	y_sort_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(_delta: float) -> void:
	if _level == null or not is_instance_valid(_level):
		return
	for piece in _level.get_you_pieces():
		_track(piece)


func _draw() -> void:
	var bottom_half := BOTTOM_TEX.get_size() * 0.5
	var top_half := TOP_TEX.get_size() * 0.5
	for stamp in _stamps:
		draw_set_transform(stamp.pos, stamp.rot, stamp.scale)
		draw_texture(BOTTOM_TEX, -bottom_half)
	for stamp in _stamps:
		draw_set_transform(stamp.top_pos, stamp.top_rot, stamp.top_scale)
		draw_texture(TOP_TEX, -top_half)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _track(piece: Piece) -> void:
	var pos := piece.position + Vector2(0.0, y_offset)
	if not _last_drop.has(piece):
		_last_drop[piece] = pos
		return
	var prev: Vector2 = _last_drop[piece]
	var traveled := pos.distance_to(prev)
	if traveled < drop_distance:
		return
	var steps := maxi(1, int(traveled / drop_distance))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		_drop(prev.lerp(pos, t))
	_last_drop[piece] = pos


func _drop(at: Vector2) -> void:
	var origin := at + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-4.0, 4.0))
	var rot := _rng.randf_range(-0.4, 0.4)
	var s := _rng.randf_range(min_scale, max_scale)
	var stretch := _rng.randf_range(0.85, 1.1)
	var top_s := s * _rng.randf_range(0.55, 0.8)
	_stamps.append({
		"pos": origin,
		"rot": rot,
		"scale": Vector2(s, s * stretch),
		"top_pos": origin + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0)),
		"top_rot": rot + _rng.randf_range(-0.15, 0.15),
		"top_scale": Vector2(top_s, top_s * _rng.randf_range(0.9, 1.05)),
	})
	queue_redraw()
