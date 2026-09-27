class_name AutumnScenery
extends Node2D

const TREES: Array[Texture2D] = [
	preload("res://assets/tiles/tree_1.png"),  # yellow
	preload("res://assets/tiles/tree_2.png"),  # orange
	preload("res://assets/tiles/tree_3.png"),  # amber
]
const ROCK := preload("res://assets/tiles/rock_1.png")
const PROP_WIND := preload("res://shaders/prop_wind.gdshader")

@export var seed_value: int = 11
@export var tree_count: int = 10
@export var board_tree_cap: int = 4
@export var tree_scale_min: float = 1.05
@export var tree_scale_max: float = 1.7
@export var rock_count: int = 3
@export var rock_scale_min: float = 0.7
@export var rock_scale_max: float = 1.35
@export var map_rock_count: int = 8
@export var map_rock_scale_min: float = 0.55
@export var map_rock_scale_max: float = 1.1
@export var tree_brighten: Color = Color(1.08, 1.04, 0.98, 1.0)
@export var fade_alpha: float = 0.08
@export var fade_speed: float = 5.0
@export var touch_padding: float = 28.0

var _board_rect := Rect2()
var _view_size := Vector2(960, 640)
var _rng := RandomNumberGenerator.new()
var _props: Node2D
var _map_rocks: Node2D
var _fade_sprites: Array[Sprite2D] = []
var _fade_base_alpha: Array[float] = []
var _blocked_points: Array[Vector2] = []
var _blocked_radius := 36.0
var _level_seed := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0
	_map_rocks = Node2D.new()
	_map_rocks.name = "MapRocks"
	_map_rocks.y_sort_enabled = true
	add_child(_map_rocks)
	_props = Node2D.new()
	_props.name = "Props"
	_props.y_sort_enabled = true
	add_child(_props)

func rebuild(
	host_offset: Vector2,
	board_size: Vector2,
	view_size: Vector2,
	level_index: int = 0,
	blocked_points: Array = [],
	blocked_radius: float = 36.0,
) -> void:
	if _props == null or _map_rocks == null:
		return
	_board_rect = Rect2(host_offset, board_size)
	_view_size = view_size
	_level_seed = seed_value + level_index * 131
	_blocked_points.clear()
	for point in blocked_points:
		if point is Vector2:
			_blocked_points.append(point)
	_blocked_radius = blocked_radius
	_fade_sprites.clear()
	_fade_base_alpha.clear()
	_rebuild_map_rocks()
	_rebuild_props()

func update_tree_fade(you_pieces: Array, host_offset: Vector2, delta: float) -> void:
	if _fade_sprites.is_empty():
		return
	var you_points: Array[Vector2] = []
	for piece in you_pieces:
		if piece == null or not is_instance_valid(piece):
			continue
		you_points.append(host_offset + piece.position)

	for i in _fade_sprites.size():
		var spr := _fade_sprites[i]
		if spr == null or not is_instance_valid(spr):
			continue
		var base_a := _fade_base_alpha[i] if i < _fade_base_alpha.size() else 1.0
		var radius := float(spr.texture.get_width()) * absf(spr.scale.x) * 0.42 + touch_padding
		var touching := false
		for point in you_points:
			if point.distance_to(spr.position) <= radius:
				touching = true
				break
		var target := fade_alpha if touching else base_a
		var c := spr.modulate
		c.a = move_toward(c.a, target, fade_speed * delta)
		spr.modulate = c

func _rebuild_map_rocks() -> void:
	for child in _map_rocks.get_children():
		child.queue_free()
	if _board_rect.size == Vector2.ZERO:
		return
	_rng.seed = _level_seed + 17
	var pad := 40.0
	var zone := _board_rect.grow(-pad)
	if zone.size.x <= 8.0 or zone.size.y <= 8.0:
		zone = _board_rect
	var rock_zones: Array[Rect2] = []
	rock_zones.append(zone)
	_place_rocks(
		_map_rocks,
		rock_zones,
		map_rock_count,
		map_rock_scale_min,
		map_rock_scale_max,
		72.0,
		false,
	)

func _rebuild_props() -> void:
	for child in _props.get_children():
		child.queue_free()

	var outside := _outside_zones()
	var board_zones: Array[Rect2] = []
	if _board_rect.size != Vector2.ZERO:
		board_zones.append(_board_rect)

	# Most trees around the edges; only a few in the puzzle middle.
	_rng.seed = _level_seed + 42
	var edge_count := maxi(tree_count - board_tree_cap, 0)
	_place_trees(outside, edge_count, tree_scale_min, tree_scale_max, 130.0, false)
	_rng.seed = _level_seed + 55
	_place_trees(board_zones, board_tree_cap, tree_scale_min * 0.9, tree_scale_max * 0.9, 150.0, true)

	_rng.seed = _level_seed + 99
	_place_rocks(_props, outside, rock_count, rock_scale_min, rock_scale_max, 80.0, true)

func _place_trees(
	zones: Array[Rect2],
	count: int,
	scale_min: float,
	scale_max: float,
	min_sep: float,
	on_board: bool,
) -> void:
	if zones.is_empty() or count <= 0:
		return
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 80:
		attempts += 1
		var tex: Texture2D = TREES[_rng.randi_range(0, TREES.size() - 1)]
		var zone: Rect2 = zones[_rng.randi_range(0, zones.size() - 1)]
		if zone.size.x <= 1.0 or zone.size.y <= 1.0:
			continue
		var pos := Vector2(
			_rng.randf_range(zone.position.x, zone.end.x),
			_rng.randf_range(zone.position.y, zone.end.y),
		)
		if on_board and not _board_rect.has_point(pos):
			continue
		if not on_board and _board_rect.has_point(pos):
			continue
		var s := _rng.randf_range(scale_min, scale_max)
		if on_board:
			s *= 0.85
		var radius := float(tex.get_width()) * s * 0.5
		if _too_close(_props, pos, radius, min_sep):
			continue
		if _blocked_by_tiles(pos, radius + _blocked_radius):
			continue
		var base_a := 0.72 if on_board else 1.0
		var color := tree_brighten
		color.a = base_a
		var spr := _make_sprite(tex, pos, s, color, true)
		_props.add_child(spr)
		_fade_sprites.append(spr)
		_fade_base_alpha.append(base_a)
		placed += 1

func _place_rocks(
	parent: Node2D,
	zones: Array[Rect2],
	count: int,
	scale_min: float,
	scale_max: float,
	min_sep: float,
	avoid_board_interior: bool,
) -> void:
	if zones.is_empty() or count <= 0:
		return
	var placed := 0
	var attempts := 0
	var tex_w := float(ROCK.get_width())
	while placed < count and attempts < count * 40:
		attempts += 1
		var zone: Rect2 = zones[_rng.randi_range(0, zones.size() - 1)]
		if zone.size.x <= 1.0 or zone.size.y <= 1.0:
			continue
		var s := _rng.randf_range(scale_min, scale_max)
		var radius := tex_w * s * 0.45
		var pos := Vector2(
			_rng.randf_range(zone.position.x, zone.end.x),
			_rng.randf_range(zone.position.y, zone.end.y),
		)
		if avoid_board_interior and _board_rect.grow(-8.0).has_point(pos):
			continue
		if _too_close(parent, pos, radius, min_sep):
			continue
		if _blocked_by_tiles(pos, radius + _blocked_radius * 0.5):
			continue
		var base_a := 0.8 if _board_rect.has_point(pos) else 1.0
		var color := Color(1, 1, 1, base_a)
		var spr := _make_sprite(ROCK, pos, s, color, true, true)
		parent.add_child(spr)
		_fade_sprites.append(spr)
		_fade_base_alpha.append(base_a)
		placed += 1

func _blocked_by_tiles(pos: Vector2, clear_radius: float) -> bool:
	for point in _blocked_points:
		if pos.distance_to(point) < clear_radius:
			return true
	return false

func _too_close(parent: Node2D, pos: Vector2, radius: float, min_sep: float) -> bool:
	for child in parent.get_children():
		if not child is Sprite2D:
			continue
		var other: Sprite2D = child
		var other_r := float(other.texture.get_width()) * absf(other.scale.x) * 0.45
		if other.position.distance_to(pos) < maxf(min_sep, radius + other_r):
			return true
	return false

func _make_sprite(
	tex: Texture2D,
	pos: Vector2,
	s: float,
	modulate: Color,
	apply_wind: bool,
	is_rock: bool = false,
) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2(s, s)
	spr.flip_h = _rng.randf() > 0.5
	spr.modulate = modulate
	# Platformer-style depth: lower on screen draws in front.
	spr.z_as_relative = false
	var foot_y := pos.y + float(tex.get_height()) * s * 0.45
	spr.z_index = int(foot_y)
	if apply_wind:
		var mat := ShaderMaterial.new()
		mat.shader = PROP_WIND
		mat.set_shader_parameter("phase", _rng.randf() * TAU)
		if is_rock:
			mat.set_shader_parameter("wind_speed", _rng.randf_range(0.5, 0.9))
			mat.set_shader_parameter("wind_strength", _rng.randf_range(0.035, 0.06))
			mat.set_shader_parameter("height_power", 0.35)
			mat.set_shader_parameter("gust_scale", _rng.randf_range(1.8, 3.2))
		else:
			mat.set_shader_parameter("wind_speed", _rng.randf_range(0.65, 1.15))
			mat.set_shader_parameter("wind_strength", _rng.randf_range(0.06, 0.11))
			mat.set_shader_parameter("height_power", 1.15)
			mat.set_shader_parameter("gust_scale", _rng.randf_range(2.0, 3.6))
		spr.material = mat
	return spr

func _outside_zones() -> Array[Rect2]:
	var pads: Array[Rect2] = []
	var b := _board_rect
	var inset := 24.0
	if b.position.y > 4.0:
		pads.append(Rect2(0.0, 0.0, _view_size.x, b.position.y + inset))
	if b.end.y < _view_size.y - 4.0:
		pads.append(Rect2(0.0, b.end.y - inset, _view_size.x, _view_size.y - b.end.y + inset))
	if b.position.x > 4.0:
		pads.append(Rect2(0.0, b.position.y, b.position.x + inset, b.size.y))
	if b.end.x < _view_size.x - 4.0:
		pads.append(Rect2(b.end.x - inset, b.position.y, _view_size.x - b.end.x + inset, b.size.y))

	if pads.is_empty():
		var peek := 140.0
		pads.append(Rect2(-peek * 0.15, -peek * 0.35, _view_size.x + peek * 0.3, peek * 0.85))
		pads.append(Rect2(-peek * 0.15, _view_size.y - peek * 0.25, _view_size.x + peek * 0.3, peek * 0.85))
		pads.append(Rect2(-peek * 0.45, 0.0, peek * 0.85, _view_size.y))
		pads.append(Rect2(_view_size.x - peek * 0.4, 0.0, peek * 0.85, _view_size.y))
	return pads
