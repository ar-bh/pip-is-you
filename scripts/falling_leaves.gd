extends Node2D

@export var leaf_count: int = 26
@export var min_scale: float = 0.18
@export var max_scale: float = 0.38
@export var min_fall_speed: float = 28.0
@export var max_fall_speed: float = 72.0
@export var sway_strength: float = 36.0

var _leaves: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_load_textures()
	for i in leaf_count:
		_spawn_leaf(true)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _process(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	for leaf in _leaves:
		var spr: Sprite2D = leaf.sprite
		leaf.phase += delta * leaf.spin
		leaf.age += delta
		spr.position.y += leaf.fall * delta
		spr.position.x += sin(leaf.age * leaf.sway_freq + leaf.phase) * sway_strength * delta
		spr.rotation = sin(leaf.age * leaf.spin * 0.35 + leaf.phase) * 0.7
		var pulse := 1.0 + sin(leaf.age * 2.1 + leaf.phase) * 0.04
		spr.scale = Vector2.ONE * leaf.base_scale * pulse
		if spr.position.y > view.y + 48.0:
			_reset_leaf(leaf, view, true)

func _load_textures() -> void:
	for i in 12:
		var path := "res://assets/tiles/autumn/leaves/leaf_%02d.png" % i
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			_textures.append(tex)
	if _textures.is_empty():
		push_warning("No leaf textures found under assets/tiles/autumn/leaves/")

func _spawn_leaf(scattered: bool) -> void:
	if _textures.is_empty():
		return
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.z_index = _rng.randi_range(-1, 2)
	add_child(spr)
	var leaf := {
		"sprite": spr,
		"fall": 0.0,
		"spin": 0.0,
		"sway_freq": 0.0,
		"phase": 0.0,
		"age": 0.0,
		"base_scale": 1.0,
	}
	_leaves.append(leaf)
	_reset_leaf(leaf, get_viewport().get_visible_rect().size, not scattered)

func _reset_leaf(leaf: Dictionary, view: Vector2, from_top: bool) -> void:
	var spr: Sprite2D = leaf.sprite
	spr.texture = _textures[_rng.randi_range(0, _textures.size() - 1)]
	leaf.base_scale = _rng.randf_range(min_scale, max_scale)
	leaf.fall = _rng.randf_range(min_fall_speed, max_fall_speed)
	leaf.spin = _rng.randf_range(0.6, 1.8) * (1.0 if _rng.randf() > 0.5 else -1.0)
	leaf.sway_freq = _rng.randf_range(0.7, 1.6)
	leaf.phase = _rng.randf() * TAU
	leaf.age = _rng.randf() * 10.0
	spr.modulate = Color(1, 1, 1, _rng.randf_range(0.55, 0.9))
	spr.scale = Vector2.ONE * leaf.base_scale
	spr.position.x = _rng.randf_range(-40.0, view.x + 40.0)
	if from_top:
		spr.position.y = _rng.randf_range(-120.0, -20.0)
	else:
		spr.position.y = _rng.randf_range(-80.0, view.y)

func _on_viewport_resized() -> void:
	var view := get_viewport().get_visible_rect().size
	for leaf in _leaves:
		var spr: Sprite2D = leaf.sprite
		spr.position.x = clampf(spr.position.x, -40.0, view.x + 40.0)
