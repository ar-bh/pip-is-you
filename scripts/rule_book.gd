class_name RuleBook
extends RefCounted

## Active sentences found on the board, like PIP IS YOU or BUSH IS STOP.

var properties: Dictionary = {} ## StringName noun -> Dictionary of StringName property -> true


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
		# Word blocks are always pushable, like Baba text.
		return property == &"push"
	# Physical acorn is pushable — unless it is YOU (then it walks itself).
	if piece.id == &"acorn" and property == &"push" and not has_property(&"acorn", &"you"):
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

	_scan_lines(by_cell, true)
	_scan_lines(by_cell, false)
	# L-shapes like YOU IS ACORN also count as controlling that noun.
	_scan_you_is_noun(by_cell, true)
	_scan_you_is_noun(by_cell, false)


func _scan_lines(by_cell: Dictionary, horizontal: bool) -> void:
	var cells: Array = by_cell.keys()
	for cell: Vector2i in cells:
		var first: Piece = _noun_at(by_cell, cell)
		if first == null:
			continue
		var second_cell := cell + (Vector2i.RIGHT if horizontal else Vector2i.DOWN)
		var is_word := _word_at(by_cell, second_cell, &"is")
		if is_word == null:
			continue
		var third_cell := second_cell + (Vector2i.RIGHT if horizontal else Vector2i.DOWN)
		var property := _property_at(by_cell, third_cell)
		if property == null:
			continue
		set_property(first.id, property.id)


func _scan_you_is_noun(by_cell: Dictionary, horizontal: bool) -> void:
	var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	for cell: Vector2i in by_cell.keys():
		if _word_at(by_cell, cell, &"you") == null:
			continue
		if _word_at(by_cell, cell + step, &"is") == null:
			continue
		var noun := _noun_at(by_cell, cell + step * 2)
		if noun == null:
			continue
		set_property(noun.id, &"you")


func _noun_at(by_cell: Dictionary, cell: Vector2i) -> Piece:
	if not by_cell.has(cell):
		return null
	for piece: Piece in by_cell[cell]:
		if piece.id in [&"pip", &"acorn", &"bush", &"leaf"]:
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
