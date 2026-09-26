class_name AutumnScenery
extends Node2D

const GRASS := preload("res://tiles/grass.png")
const TREE := preload("res://tiles/tree_1.png")
const ROCK := preload("res://tiles/rock_1.png")

@export var tile_pixel_size: int = 64
@export var seed_value: int = 11
@export var tree_count: int = 7
@export var tree_scale: float = 2.4
@export var rock_count: int = 14
@export var rock_scale: float = 2.8

var _board_rect := Rect2()
var _view_size := Vector2(960, 640)
var _floor_cols := 0
var _floor_rows := 0
var _rng := RandomNumberGenerator.new()
var _props: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2
	_props = Node2D.new()
	_props.name = "Props"
	_props.z_index = 1
	add_child(_props)

func rebuild(host_offset: Vector2, board_size: Vector2, view_size: Vector2) -> void:
	_board_rect = Rect2(host_offset, board_size)
	_view_size = view_size
	var ts := float(tile_pixel_size)
	_floor_cols = int(ceil(_view_size.x / ts)) + 1
	_floor_rows = int(ceil(_view_size.y / ts)) + 1
	_rebuild_props()
	queue_redraw()

func _rebuild_props() -> void:
	for child in _props.get_children():
		child.queue_free()

	var zones := _outside_zones()
	if zones.is_empty():
		return

	_rng.seed = seed_value + 42
	_place_props(TREE, zones, tree_count, tree_scale, 110.0)
	_rng.seed = seed_value + 99
	_place_props(ROCK, zones, rock_count, rock_scale, 36.0)

func _place_props(tex: Texture2D, zones: Array[Rect2], count: int, base_scale: float, min_sep: float) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var zone: Rect2 = zones[_rng.randi_range(0, zones.size() - 1)]
		var pos := Vector2(
			_rng.randf_range(zone.position.x, zone.end.x),
			_rng.randf_range(zone.position.y, zone.end.y),
		)
		if _board_rect.grow(20.0).has_point(pos):
			continue
		var too_close := false
		for child in _props.get_children():
			if child.position.distance_to(pos) < min_sep:
				too_close = true
				break
		if too_close:
			continue

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = pos
		var s := base_scale * _rng.randf_range(0.85, 1.25)
		spr.scale = Vector2(s, s)
		spr.flip_h = _rng.randf() > 0.5
		spr.z_index = int(pos.y)
		_props.add_child(spr)
		placed += 1

func _outside_zones() -> Array[Rect2]:
	var pads: Array[Rect2] = []
	var b := _board_rect
	if b.position.y > 4.0:
		pads.append(Rect2(0.0, 0.0, _view_size.x, b.position.y))
	if b.end.y < _view_size.y - 4.0:
		pads.append(Rect2(0.0, b.end.y, _view_size.x, _view_size.y - b.end.y))
	if b.position.x > 4.0:
		pads.append(Rect2(0.0, b.position.y, b.position.x, b.size.y))
	if b.end.x < _view_size.x - 4.0:
		pads.append(Rect2(b.end.x, b.position.y, _view_size.x - b.end.x, b.size.y))

	if pads.is_empty():
		var peek := 120.0
		pads.append(Rect2(-peek * 0.35, -peek, _view_size.x + peek * 0.7, peek))
		pads.append(Rect2(-peek * 0.35, _view_size.y, _view_size.x + peek * 0.7, peek))
		pads.append(Rect2(-peek, 0.0, peek, _view_size.y))
		pads.append(Rect2(_view_size.x, 0.0, peek, _view_size.y))
	return pads

func _draw() -> void:
	var ts := float(tile_pixel_size)
	var src := Rect2(Vector2.ZERO, GRASS.get_size())
	for y in _floor_rows:
		for x in _floor_cols:
			var dest := Rect2(Vector2(x, y) * ts, Vector2(ts, ts))
			draw_texture_rect_region(GRASS, dest, src)
