extends RefCounted
## The playground's board geometry, read from the generated gameplay layout
## (scenes/swf/game.json `board`, tools/convert/layout.py): the board container's matrix,
## the excursion and the cell grid. Preload this script; it has no `class_name`.
##
## A stage point is a viewport point in the playground (700×510 at 1:1), so the same
## numbers place the inspector and the overlays over the drawn stage.

const SwfScreen := preload("res://scripts/ui/swf_screen.gd")
const DEFAULT_MATRIX := [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
const DEFAULT_EXCURSION := [0.0, 0.0]
const DEFAULT_GRID := 30.0


## The layout's `board` dictionary, or {} when the gameplay layout is missing.
static func board_layout() -> Dictionary:
	var layout = SwfScreen.layout_of(&"game")
	if layout is Dictionary and layout.get("board") is Dictionary:
		return layout.get("board")
	return {}


## The stage point of a cell's top-left corner.
static func cell_to_stage(board: Dictionary, cell: Vector2i) -> Vector2:
	return _local_to_stage(board, Vector2(cell))


## The stage point of a cell's centre.
static func cell_centre(board: Dictionary, cell: Vector2i) -> Vector2:
	return _local_to_stage(board, Vector2(cell) + Vector2(0.5, 0.5))


## The cell under a stage point (the affine inverse of `cell_to_stage`).
static func stage_to_cell(board: Dictionary, point: Vector2) -> Vector2i:
	var matrix := _matrix(board)
	var det := float(matrix[0]) * float(matrix[3]) - float(matrix[2]) * float(matrix[1])
	if is_zero_approx(det):
		return Vector2i.ZERO
	var dx := point.x - float(matrix[4])
	var dy := point.y - float(matrix[5])
	var local := Vector2((dx * float(matrix[3]) - dy * float(matrix[2])) / det,
		(-dx * float(matrix[1]) + dy * float(matrix[0])) / det)
	var excursion := _excursion(board)
	var grid := _grid(board)
	return Vector2i(floori((local.x - float(excursion[0])) / grid),
		floori((local.y - float(excursion[1])) / grid))


## The stage point of a snapshot `position` (cell units): the same transform with
## `grid * position` instead of a whole cell.
static func position_to_stage(board: Dictionary, position: Vector2) -> Vector2:
	return _local_to_stage(board, position)


static func _local_to_stage(board: Dictionary, local: Vector2) -> Vector2:
	var matrix := _matrix(board)
	var cell := Vector2(float(_excursion(board)[0]), float(_excursion(board)[1])) + local * _grid(board)
	return Vector2(float(matrix[4]) + float(matrix[0]) * cell.x + float(matrix[2]) * cell.y,
		float(matrix[5]) + float(matrix[1]) * cell.x + float(matrix[3]) * cell.y)


static func _matrix(board: Dictionary) -> Array:
	var value = board.get("container_matrix", DEFAULT_MATRIX)
	return value if value is Array and value.size() >= 6 else DEFAULT_MATRIX


static func _excursion(board: Dictionary) -> Array:
	var value = board.get("excursion", DEFAULT_EXCURSION)
	return value if value is Array and value.size() >= 2 else DEFAULT_EXCURSION


static func _grid(board: Dictionary) -> float:
	var value := float(board.get("grid", DEFAULT_GRID))
	return value if value > 0.0 else DEFAULT_GRID
