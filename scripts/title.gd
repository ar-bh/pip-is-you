extends Control

const COMIC_SCENE := "res://scenes/comic.tscn"
## Visible Pip region inside pip_title.png (full-height character, no empty sides).
const PIP_REGION := Rect2(10, 0, 177, 144)

@onready var pip: TextureRect = $PipTitle
@onready var start_btn: TextureButton = $RightColumn/StartButton

func _ready() -> void:
	App.ensure_music()
	_setup_pip_texture()
	start_btn.pressed.connect(_on_start)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_on_start()
		get_viewport().set_input_as_handled()

func _setup_pip_texture() -> void:
	var base: Texture2D = pip.texture
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = PIP_REGION
	atlas.filter_clip = true
	pip.texture = atlas

func _fit_layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var tex := pip.texture.get_size()
	if tex.y <= 0.0:
		return
	# Full-height Pip; shift left so the logo/start column never overlaps.
	var s := view.y / tex.y
	var pip_w := tex.x * s
	var text_w := maxf(220.0, view.x * 0.40)
	var gap := 28.0
	var text_x := view.x - text_w - 16.0
	var pip_x := minf(0.0, text_x - gap - pip_w)
	pip.size = Vector2(pip_w, view.y)
	pip.position = Vector2(pip_x, 0.0)
	pip.stretch_mode = TextureRect.STRETCH_SCALE

	$RightColumn.position = Vector2(text_x, 0.0)
	$RightColumn.size = Vector2(text_w, view.y)

func _on_start() -> void:
	App.ensure_music()
	get_tree().change_scene_to_file(COMIC_SCENE)
