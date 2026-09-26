extends Sprite2D

## One press moves one cell. Further cells happen only while that key stays held.

@export var board: Board
@export var grid_pos: Vector2i = Vector2i(7, 4)
@export var step_duration: float = 0.12
@export var hold_repeat_delay: float = 0.28

const DIRECTIONS := {
	&"move_right": Vector2i.RIGHT,
	&"move_left": Vector2i.LEFT,
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
}

var _held: Array[StringName] = []
var _repeat_clock := 0.0
var _step_when_idle := false
var _moving := false


func _ready() -> void:
	_fit_to_cell()
	position = board.cell_center(grid_pos)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	for action: StringName in DIRECTIONS:
		if not event.is_action(action):
			continue
		_held.erase(action)
		if event.pressed:
			_held.append(action)
			_repeat_clock = 0.0
			if _moving:
				_step_when_idle = true
			else:
				_step_when_idle = false
				try_step(DIRECTIONS[action])
		elif _held.is_empty():
			_step_when_idle = false
		get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	if _moving:
		return
	var direction := _held_direction()
	if direction == Vector2i.ZERO:
		_repeat_clock = 0.0
		_step_when_idle = false
		return
	if _step_when_idle:
		_step_when_idle = false
		_repeat_clock = 0.0
		try_step(direction)
		return
	_repeat_clock += delta
	if _repeat_clock >= hold_repeat_delay:
		_repeat_clock = 0.0
		try_step(direction)


func try_step(direction: Vector2i) -> bool:
	if _moving or direction == Vector2i.ZERO:
		return false
	var next := grid_pos + direction
	if not board.contains(next):
		return false
	grid_pos = next
	_moving = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", board.cell_center(grid_pos), step_duration)
	tween.finished.connect(_finish_step)
	return true


func _finish_step() -> void:
	position = board.cell_center(grid_pos)
	_moving = false


func _held_direction() -> Vector2i:
	for i in range(_held.size() - 1, -1, -1):
		var action := _held[i]
		if Input.is_action_pressed(action):
			return DIRECTIONS[action]
		_held.remove_at(i)
	return Vector2i.ZERO


func _fit_to_cell() -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return
	var scale_factor := board.cell_size * 0.72 / longest
	scale = Vector2(scale_factor, scale_factor)
