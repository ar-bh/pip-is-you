class_name Board
extends Node2D

## The play field. Every object sits on a cell; pixels are only for drawing.

@export var columns: int = 15
@export var rows: int = 10
@export var cell_size: int = 64

const _COLOR_A := Color(0.11, 0.11, 0.17)
const _COLOR_B := Color(0.15, 0.15, 0.23)


#func _draw() -> void:
	#for y in rows:
		#for x in columns:
			#var color := _COLOR_A if (x + y) % 2 == 0 else _COLOR_B
			#draw_rect(Rect2(x * cell_size, y * cell_size, cell_size, cell_size), color)


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
