class_name MoveTrail
extends Node2D

const BOTTOM_TEX := preload("res://assets/tiles/bottom_trail.png")
const TOP_TEX := preload("res://assets/tiles/trail_top.png")

@export var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled:
			_stamps.clear()
			_last_drop.clear()
			queue_redraw()

@export var fade_enabled: bool = false
@export var drop_distance: float = 10.0
@export var min_scale: float = 1.6
@export var max_scale: float = 2.8
@export var y_offset: float = 14.0
@export var lifetime: float = 3.2
@export var fade_start: float = 1.6

var _level: Level
var _last_drop: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _stamps: Array[Dictionary] = []

func setup(level: Level) -> void:
	_level = level
	_last_drop.clear()
	_stamps.clear()
	_rng.randomize()
	z_index = -1
	y_sort_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(enabled)
	queue_redraw()

func set_trail_enabled(on: bool) -> void:
	enabled = on
	set_process(on)
	if not on:
		_stamps.clear()
		_last_drop.clear()
		queue_redraw()

func set_fade_enabled(on: bool) -> void:
	fade_enabled = on
	if not fade_enabled:
		for stamp in _stamps:
			stamp.age = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	if not enabled or _level == null or not is_instance_valid(_level):
		return
	for piece in _level.get_you_pieces():
		_track(piece)
	if fade_enabled:
		_age_stamps(delta)

func _draw() -> void:
	if not enabled or _stamps.is_empty():
		return
	var bottom_half := BOTTOM_TEX.get_size() * 0.5
	var top_half := TOP_TEX.get_size() * 0.5
	for stamp in _stamps:
		var col := Color(1, 1, 1, _stamp_alpha(stamp))
		draw_set_transform(stamp.pos, stamp.rot, stamp.scale)
		draw_texture(BOTTOM_TEX, -bottom_half, col)
	for stamp in _stamps:
		var col := Color(1, 1, 1, _stamp_alpha(stamp))
		draw_set_transform(stamp.top_pos, stamp.top_rot, stamp.top_scale)
		draw_texture(TOP_TEX, -top_half, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _stamp_alpha(stamp: Dictionary) -> float:
	if not fade_enabled:
		return 1.0
	var age: float = stamp.age
	var life: float = stamp.life
	var fade_at: float = minf(fade_start, life * 0.55)
	if age <= fade_at:
		return 1.0
	return 1.0 - clampf((age - fade_at) / maxf(life - fade_at, 0.001), 0.0, 1.0)

func _age_stamps(delta: float) -> void:
	if _stamps.is_empty():
		return
	var alive: Array[Dictionary] = []
	for stamp in _stamps:
		stamp.age = float(stamp.age) + delta
		if stamp.age < stamp.life:
			alive.append(stamp)
	_stamps = alive
	queue_redraw()

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
		"age": 0.0,
		"life": lifetime * _rng.randf_range(0.85, 1.2),
	})
	queue_redraw()
