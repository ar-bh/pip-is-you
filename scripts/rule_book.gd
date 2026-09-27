class_name RuleBook
extends RefCounted

var properties: Dictionary = {}

func clear() -> void:
	properties.clear()

func set_property(noun: StringName, property: StringName) -> void:
	if not properties.has(noun):
		properties[noun] = {}
	properties[noun][property] = true

func has_property(noun: StringName, property: StringName) -> bool:
	return properties.has(noun) and properties[noun].has(property)

func piece_has(piece: Piece, property: StringName) -> bool:
	if piece.is_text:
		return property == &"push"
	if piece.id == &"acorn" and property == &"push" and not has_property(&"acorn", &"you"):
		return true
	# Bushes are pushable unless BUSH IS STOP (or YOU) is active.
	if piece.id == &"bush" and property == &"push" and not has_property(&"bush", &"you") and not has_property(&"bush", &"stop"):
		return true
	# Walls are solid unless WALL IS PUSH (or YOU) is active.
	if piece.id == &"wall" and property == &"stop" and not has_property(&"wall", &"you") and not has_property(&"wall", &"push"):
		return true
	return has_property(piece.id, property)

func rebuild(pieces: Array) -> void:
	clear()
	var by_cell: Dictionary = {}
	for piece in pieces:
		if not piece.is_text:
			continue
		var key: Vector2i = piece.cell
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(piece)

	# Straight lines only — both directions on each axis (no facing required).
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		_scan_noun_is_property(by_cell, step)
		_scan_property_is_noun(by_cell, step)

func _scan_noun_is_property(by_cell: Dictionary, step: Vector2i) -> void:
	for cell: Vector2i in by_cell.keys():
		var noun := _noun_at(by_cell, cell)
		if noun == null:
			continue
		if _word_at(by_cell, cell + step, &"is") == null:
			continue
		var property := _property_at(by_cell, cell + step * 2)
		if property == null:
			continue
		set_property(noun.id, property.id)

func _scan_property_is_noun(by_cell: Dictionary, step: Vector2i) -> void:
	# e.g. GOAL IS ACORN / YOU IS PIP — same as noun IS property, just reversed order.
	for cell: Vector2i in by_cell.keys():
		var property := _property_at(by_cell, cell)
		if property == null:
			continue
		if _word_at(by_cell, cell + step, &"is") == null:
			continue
		var noun := _noun_at(by_cell, cell + step * 2)
		if noun == null:
			continue
		set_property(noun.id, property.id)

func _noun_at(by_cell: Dictionary, cell: Vector2i) -> Piece:
	if not by_cell.has(cell):
		return null
	for piece: Piece in by_cell[cell]:
		if piece.id in [&"pip", &"acorn", &"bush", &"leaf", &"wall"]:
			return piece
	return null

func _word_at(by_cell: Dictionary, cell: Vector2i, word: StringName) -> Piece:
	if not by_cell.has(cell):
		return null
	for piece: Piece in by_cell[cell]:
		if piece.id == word:
			return piece
	return null

func _property_at(by_cell: Dictionary, cell: Vector2i) -> Piece:
	if not by_cell.has(cell):
		return null
	for piece: Piece in by_cell[cell]:
		if piece.id in [&"you", &"win", &"stop", &"push"]:
			return piece
	return null

func describe() -> String:
	var lines: PackedStringArray = []
	for noun: StringName in properties:
		for property: StringName in properties[noun]:
			lines.append("%s IS %s" % [String(noun).to_upper(), String(property).to_upper()])
	lines.sort()
	return "\n".join(lines)
