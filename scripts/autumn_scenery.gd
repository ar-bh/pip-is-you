class_name AutumnScenery
extends Node2D

const TREES: Array[Texture2D] = [
	preload("res://assets/tiles/tree_1.png"),
	preload("res://assets/tiles/tree_2.png"),
]
const ROCK := preload("res://assets/tiles/rock_1.png")
const PROP_WIND := preload("res://shaders/prop_wind.gdshader")

@export var seed_value: int = 11
@export var tree_count: int = 4
@export var tree_scale_min: float = 1.2
@export var tree_scale_max: float = 1.85
@export var rock_count: int = 3
@export var rock_scale_min: float = 0.7
@export var rock_scale_max: float = 1.35
@export var map_rock_count: int = 8
@export var map_rock_scale_min: float = 0.55
@export var map_rock_scale_max: float = 1.1
@export var tree_brighten: Color = Color(1.35, 1.28, 1.12, 1.0)

var _board_rect := Rect2()
var _view_size := Vector2(960, 640)
var _rng := RandomNumberGenerator.new()
var _props: Node2D
var _map_rocks: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2
	_map_rocks = Node2D.new()
	_map_rocks.name = "MapRocks"
	_map_rocks.z_index = 0
	add_child(_map_rocks)
	_props = Node2D.new()
	_props.name = "Props"
	_props.z_index = 1
	add_child(_props)

func rebuild(host_offset: Vector2, board_size: Vector2, view_size: Vector2) -> void:
	_board_rect = Rect2(host_offset, board_size)
	_view_size = view_size
	_rebuild_map_rocks()
	_rebuild_props()

func _rebuild_map_rocks() -> void:
	for child in _map_rocks.get_children():
		child.queue_free()
	if _board_rect.size == Vector2.ZERO:
		return
	_rng.seed = seed_value + 17
	var pad := 40.0
	var zone := _board_rect.grow(-pad)
	if zone.size.x <= 8.0 or zone.size.y <= 8.0:
		zone = _board_rect
	_place_rocks(
		_map_rocks,
		[zone],
		map_rock_count,
		map_rock_scale_min,
		map_rock_scale_max,
		72.0,
		false,
	)

func _rebuild_props() -> void:
	for child in _props.get_children():
		child.queue_free()

	var zones := _outside_zones()
	if zones.is_empty():
		return

	_rng.seed = seed_value + 42
	_place_trees(zones, tree_count, tree_scale_min, tree_scale_max, 170.0)
	_rng.seed = seed_value + 99
	_place_rocks(_props, zones, rock_count, rock_scale_min, rock_scale_max, 80.0, true)

func _place_trees(
	zones: Array[Rect2],
	count: int,
	scale_min: float,
	scale_max: float,
	min_sep: float,
) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 40:
		attempts += 1
		var tex: Texture2D = TREES[_rng.randi_range(0, TREES.size() - 1)]
		var zone: Rect2 = zones[_rng.randi_range(0, zones.size() - 1)]
		var s := _rng.randf_range(scale_min, scale_max)
		var radius := float(tex.get_width()) * s * 0.45
		var pos := Vector2(
			_rng.randf_range(zone.position.x, zone.end.x),
			_rng.randf_range(zone.position.y, zone.end.y),
		)
		if _board_rect.grow(-8.0).has_point(pos):
			continue
		if _too_close(_props, pos, radius, min_sep):
			continue
		var spr := _make_sprite(tex, pos, s, tree_brighten, true)
		_props.add_child(spr)
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
	var placed := 0
	var attempts := 0
	var tex_w := float(ROCK.get_width())
	while placed < count and attempts < count * 40:
		attempts += 1
		var zone: Rect2 = zones[_rng.randi_range(0, zones.size() - 1)]
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
		var spr := _make_sprite(ROCK, pos, s, Color.WHITE, false)
		parent.add_child(spr)
		placed += 1

func _too_close(parent: Node2D, pos: Vector2, radius: float, min_sep: float) -> bool:
	for child in parent.get_children():
		if not child is Sprite2D:
			continue
		var other: Sprite2D = child
		var other_r := float(other.texture.get_width()) * absf(other.scale.x) * 0.45
		if other.position.distance_to(pos) < maxf(min_sep, radius + other_r):
			return true
	return false

func _make_sprite(tex: Texture2D, pos: Vector2, s: float, modulate: Color, apply_wind: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2(s, s)
	spr.flip_h = _rng.randf() > 0.5
	spr.modulate = modulate
	spr.z_index = int(pos.y * 0.01)
	if apply_wind:
		var mat := ShaderMaterial.new()
		mat.shader = PROP_WIND
		mat.set_shader_parameter("phase", _rng.randf() * TAU)
		mat.set_shader_parameter("wind_speed", _rng.randf_range(0.4, 0.75))
		mat.set_shader_parameter("wind_strength", _rng.randf_range(0.018, 0.034))
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
