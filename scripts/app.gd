extends Node

const CURSOR := preload("res://assets/mouse.png")
const MUSIC_STREAM := preload("res://assets/spring-wild-horseradish-jam.mp3")
const CURSOR_SCALE := 3

var _music: AudioStreamPlayer
var _cursor_normal: Texture2D
var _cursor_inverted: Texture2D
var _hotspot := Vector2(1, 1)
var _cursor_pressed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor_normal = _scale_cursor(CURSOR, CURSOR_SCALE)
	_cursor_inverted = _make_inverted_cursor(_cursor_normal)
	_hotspot = Vector2(CURSOR_SCALE, CURSOR_SCALE)
	_apply_cursor(false)

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = MUSIC_STREAM
	_music.volume_db = -6.0
	if _music.stream is AudioStreamMP3:
		(_music.stream as AudioStreamMP3).loop = true
	add_child(_music)
	_music.play()

func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed == _cursor_pressed:
		return
	_cursor_pressed = pressed
	_apply_cursor(pressed)

func ensure_music() -> void:
	if _music and not _music.playing:
		_music.play()

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
