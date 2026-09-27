extends Node

const CURSOR := preload("res://assets/mouse.png")
const MUSIC_STREAM := preload("res://assets/spring-wild-horseradish-jam.mp3")
const SETTINGS_ICON := preload("res://assets/settings.png")
const SOUND_TEXT := preload("res://assets/sound_text.png")
const CURSOR_SCALE := 3
const SETTINGS_BTN_SIZE := 48.0

var _music: AudioStreamPlayer
var _cursor_normal: Texture2D
var _cursor_inverted: Texture2D
var _hotspot := Vector2(1, 1)
var _cursor_pressed := false

var _ui_layer: CanvasLayer
var _settings_btn: TextureButton
var _panel: PanelContainer
var _slider: HSlider
var _volume := 0.75
var _panel_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor_normal = _scale_cursor(CURSOR, CURSOR_SCALE)
	_cursor_inverted = _make_inverted_cursor(_cursor_normal)
	_hotspot = Vector2(CURSOR_SCALE, CURSOR_SCALE)
	_apply_cursor(false)

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = MUSIC_STREAM
	_music.bus = &"Master"
	if _music.stream is AudioStreamMP3:
		(_music.stream as AudioStreamMP3).loop = true
	add_child(_music)
	_apply_volume()
	_music.play()

	_build_settings_ui()
	get_viewport().size_changed.connect(_fit_settings_ui)
	call_deferred("_fit_settings_ui")

func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed != _cursor_pressed:
		_cursor_pressed = pressed
		_apply_cursor(pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	):
		_toggle_panel()
		get_viewport().set_input_as_handled()

func ensure_music() -> void:
	if _music and not _music.playing:
		_music.play()

func get_volume() -> float:
	return _volume

func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply_volume()
	if _slider and not is_equal_approx(_slider.value, _volume):
		_slider.value = _volume

func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if _volume <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(_volume))
	if _music:
		_music.volume_db = -6.0

func _build_settings_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "SettingsUI"
	_ui_layer.layer = 100
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_settings_btn = TextureButton.new()
	_settings_btn.name = "SettingsButton"
	_settings_btn.texture_normal = SETTINGS_ICON
	_settings_btn.ignore_texture_size = true
	_settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_settings_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_settings_btn.custom_minimum_size = Vector2(SETTINGS_BTN_SIZE, SETTINGS_BTN_SIZE)
	_settings_btn.size = Vector2(SETTINGS_BTN_SIZE, SETTINGS_BTN_SIZE)
	_settings_btn.pressed.connect(_toggle_panel)
	_ui_layer.add_child(_settings_btn)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.93, 0.86, 0.96)
	style.border_color = Color(0.35, 0.22, 0.16, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 16

	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var sound_label := TextureRect.new()
	sound_label.texture = SOUND_TEXT
	sound_label.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sound_label.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sound_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sound_label.custom_minimum_size = Vector2(140, 40)
	sound_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sound_label)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.value = _volume
	_slider.custom_minimum_size = Vector2(180, 24)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(set_volume)
	vbox.add_child(_slider)

func _fit_settings_ui() -> void:
	if _settings_btn == null:
		return
	var view := get_viewport().get_visible_rect().size
	var margin := 16.0
	_settings_btn.position = Vector2(view.x - SETTINGS_BTN_SIZE - margin, margin)
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size.x < 200.0:
		panel_size.x = 220.0
	_panel.size = panel_size
	_panel.position = Vector2(
		view.x - panel_size.x - margin,
		margin + SETTINGS_BTN_SIZE + 8.0,
	)

func _toggle_panel() -> void:
	_panel_open = not _panel_open
	_panel.visible = _panel_open
	if _panel_open:
		_fit_settings_ui()

func _apply_cursor(pressed: bool) -> void:
	Input.set_custom_mouse_cursor(
		_cursor_inverted if pressed else _cursor_normal,
		Input.CURSOR_ARROW,
		_hotspot,
	)

func _scale_cursor(tex: Texture2D, scale: int) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/mouse.png"))
	else:
		img = img.duplicate()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func _make_inverted_cursor(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			img.set_pixel(x, y, Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b, c.a))
	return ImageTexture.create_from_image(img)
