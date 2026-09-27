class_name Level
extends Node2D

signal won
signal rules_changed(text: String)

const PieceScene := preload("res://scenes/piece.tscn")
const STEP_DURATION := 0.12
const HOLD_REPEAT_DELAY := 0.28

@onready var board: Board = $Board
@onready var tile_map: TileMapLayer = $TileMap
@onready var pieces_root: Node2D = $Pieces

@export var move_trail_enabled: bool = true
@export var move_trail_fade_enabled: bool = true
@export_multiline var hint_text: String = ""
## Always-visible tip at the bottom of the screen.
@export_multiline var guide_text: String = ""

var rules := RuleBook.new()
var pieces: Array[Piece] = []
var _held: Array[StringName] = []
var _repeat_clock := 0.0
var _step_when_idle := false
var _busy := false
var _won := false
var _history: Array = []
var _origin := Vector2i.ZERO
var _move_trail: MoveTrail

const DIRECTIONS := {
	&"move_right": Vector2i.RIGHT,
	&"move_left": Vector2i.LEFT,
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
}

func _ready() -> void:
	pieces_root.y_sort_enabled = true
	_move_trail = MoveTrail.new()
	add_child(_move_trail)
	move_child(_move_trail, 0)
	_move_trail.setup(self)
	_move_trail.set_trail_enabled(move_trail_enabled)
	_move_trail.set_fade_enabled(move_trail_fade_enabled)
	_build_from_tilemap()
	_refresh_rules()
	rules_changed.emit(rules.describe())

func is_busy() -> bool:
	return _busy

func has_won() -> bool:
	return _won

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("undo"):
		_undo()
		return true
	if _won or _busy:
		return false
	if not event is InputEventKey or event.echo:
		return false
	for action: StringName in DIRECTIONS:
		if not event.is_action(action):
			continue
		_held.erase(action)
		if event.pressed:
			_held.append(action)
			_repeat_clock = 0.0
			if _busy:
				_step_when_idle = true
			else:
				_step_when_idle = false
				_try_turn(DIRECTIONS[action])
		elif _held.is_empty():
			_step_when_idle = false
		return true
	return false

func tick(delta: float) -> void:
	if _won or _busy:
		return
	var direction := _held_direction()
	if direction == Vector2i.ZERO:
		_repeat_clock = 0.0
		_step_when_idle = false
		return
	if _step_when_idle:
		_step_when_idle = false
		_repeat_clock = 0.0
		_try_turn(direction)
		return
	_repeat_clock += delta
	if _repeat_clock >= HOLD_REPEAT_DELAY:
		_repeat_clock = 0.0
		_try_turn(direction)

func _build_from_tilemap() -> void:
	for piece in pieces:
		piece.queue_free()
	pieces.clear()

	tile_map.visible = false
	var used := tile_map.get_used_rect()
	if used.size == Vector2i.ZERO:
		_origin = Vector2i.ZERO
		board.columns = 1
		board.rows = 1
		return

	_origin = used.position
	board.sync_from_rect(Rect2i(Vector2i.ZERO, used.size))

	for cell in tile_map.get_used_cells():
		var source_id := tile_map.get_cell_source_id(cell)
		if source_id == -1:
			continue
		var atlas := tile_map.get_cell_atlas_coords(cell)
		var alt := tile_map.get_cell_alternative_tile(cell)
		var source := tile_map.tile_set.get_source(source_id)
		if not source is TileSetAtlasSource:
			continue
		var tile_data: TileData = (source as TileSetAtlasSource).get_tile_data(atlas, alt)
		if tile_data == null:
			continue
		var piece_id: StringName = tile_data.get_custom_data("piece_id")
		var is_text: bool = bool(tile_data.get_custom_data("is_text"))
		if piece_id == &"":
			continue
		_spawn(cell - _origin, is_text, piece_id)

func _try_turn(direction: Vector2i) -> void:
	if _busy or _won or direction == Vector2i.ZERO:
		return
	var yous := _yous()
	if yous.is_empty():
		return

	# Front-most in the move direction first, so a blocked YOU still occupies its cell
	# for the ones behind (no stacking into walls / each other).
	yous.sort_custom(func(a: Piece, b: Piece) -> bool:
		return a.cell.x * direction.x + a.cell.y * direction.y > b.cell.x * direction.x + b.cell.y * direction.y
	)

	var planned: Dictionary = {} # Piece -> Vector2i destination
	for you in yous:
		var dest := you.cell + direction
		if _destination_taken(planned, dest):
			continue
		var chain = _push_chain(dest, direction, planned)
		if chain == null:
			continue
		var tentative: Dictionary = {you: dest}
		var ok := true
		for pushed: Piece in chain:
			var push_to: Vector2i = pushed.cell + direction
			if _destination_taken(planned, push_to) or _destination_taken(tentative, push_to):
				ok = false
				break
			tentative[pushed] = push_to
		if not ok:
			continue
		for piece: Piece in tentative.keys():
			planned[piece] = tentative[piece]

	if planned.is_empty():
		return

	_busy = true
	_history.append(_snapshot())
	var you_set: Dictionary = {}
	for you in yous:
		you_set[you] = true
	for piece: Piece in planned.keys():
		piece.cell = planned[piece]
		if you_set.has(piece):
			piece.set_facing(direction)
		piece.animate_to_cell(STEP_DURATION)
	await get_tree().create_timer(STEP_DURATION).timeout
	_busy = false
	_refresh_rules()
	rules_changed.emit(rules.describe())
	_check_win()

func _destination_taken(planned: Dictionary, dest: Vector2i) -> bool:
	for piece: Piece in planned.keys():
		if planned[piece] == dest:
			return true
	return false

func _push_chain(start: Vector2i, direction: Vector2i, planned: Dictionary = {}) -> Variant:
	var chain: Array[Piece] = []
	var cell := start
	while true:
		var here := _pieces_at(cell)
		# Ignore pieces that are already leaving this cell this turn.
		here = here.filter(func(piece: Piece) -> bool:
			return not (planned.has(piece) and planned[piece] != piece.cell)
		)
		if here.is_empty():
			return chain

		var pushables: Array[Piece] = []
		var softs: Array[Piece] = []
		var solid_stop := false
		for piece in here:
			# Other YOU that aren't leaving act as solid (prevents stacking).
			if rules.piece_has(piece, &"you"):
				solid_stop = true
				continue
			if rules.piece_has(piece, &"push"):
				pushables.append(piece)
			elif rules.piece_has(piece, &"stop"):
				solid_stop = true
			else:
				softs.append(piece)

		if solid_stop and pushables.is_empty():
			return null

		if not pushables.is_empty():
			chain.append_array(pushables)
			chain.append_array(softs)
			cell += direction
			continue

		if softs.is_empty():
			return chain

		if chain.is_empty():
			# Soft-only tile with no push: YOU can step onto/through it.
			return chain

		chain.append_array(softs)
		cell += direction
	return null

func _pieces_at(cell: Vector2i) -> Array[Piece]:
	var found: Array[Piece] = []
	for piece in pieces:
		if piece.cell == cell:
			found.append(piece)
	return found

func get_you_pieces() -> Array[Piece]:
	return _yous()

func has_you() -> bool:
	return not _yous().is_empty()

func _yous() -> Array[Piece]:
	var found: Array[Piece] = []
	for piece in pieces:
		if rules.piece_has(piece, &"you"):
			found.append(piece)
	return found

func _refresh_rules() -> void:
	rules.rebuild(pieces)

func _check_win() -> void:
	# Pip must stand next to an acorn (YOU no longer matters for winning).
	var dirs: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	]
	for piece in pieces:
		if piece.is_text or piece.id != &"pip":
			continue
		for dir in dirs:
			for other in _pieces_at(piece.cell + dir):
				if not other.is_text and other.id == &"acorn":
					_won = true
					won.emit()
					return

func _snapshot() -> Array:
	var cells: Array[Vector2i] = []
	for piece in pieces:
		cells.append(piece.cell)
	return cells

func _undo() -> void:
	if _history.is_empty() or _busy:
		return
	_busy = true
	_won = false
	var previous: Array = _history.pop_back()
	var moving := false
	for i in pieces.size():
		if i >= previous.size():
			break
		var target: Vector2i = previous[i]
		if pieces[i].cell == target:
			continue
		pieces[i].cell = target
		pieces[i].animate_to_cell(STEP_DURATION, true)
		moving = true
	if moving:
		await get_tree().create_timer(STEP_DURATION).timeout
	_busy = false
	_refresh_rules()
	rules_changed.emit(rules.describe())

func undo() -> void:
	_undo()

func _spawn(cell: Vector2i, is_text: bool, id: StringName) -> Piece:
	var piece: Piece = PieceScene.instantiate()
	pieces_root.add_child(piece)
	piece.setup(board, cell, is_text, id)
	pieces.append(piece)
	return piece

func _held_direction() -> Vector2i:
	for i in range(_held.size() - 1, -1, -1):
		var action := _held[i]
		if Input.is_action_pressed(action):
			return DIRECTIONS[action]
		_held.remove_at(i)
	return Vector2i.ZERO
