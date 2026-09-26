class_name Board
extends Node2D

@export var columns: int = 15
@export var rows: int = 10
@export var cell_size: int = 64

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows

func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

func sync_from_rect(rect: Rect2i) -> void:
	columns = maxi(rect.size.x, 1)
	rows = maxi(rect.size.y, 1)
