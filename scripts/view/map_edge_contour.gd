extends RefCounted

## Generates continuous map-space perimeter strips. The strips cover the exact
## rectangular boundary with a gently varying inner contour, avoiding seams
## between individually generated edge tiles.

const SAMPLE_STEP_CELLS := 0.5

var map_size: Vector2


func _init(value_map_size: Vector2i) -> void:
	map_size = Vector2(value_map_size)


func band_polygons(maximum_depth_cells: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	result.append(_horizontal_band(0, maximum_depth_cells))
	result.append(_vertical_band(1, maximum_depth_cells))
	result.append(_horizontal_band(2, maximum_depth_cells))
	result.append(_vertical_band(3, maximum_depth_cells))
	return result


func _horizontal_band(side: int, maximum_depth_cells: float) -> PackedVector2Array:
	var inner := PackedVector2Array()
	var sample_count := ceili(map_size.x / SAMPLE_STEP_CELLS)
	for index in range(sample_count + 1):
		var x := minf(float(index) * SAMPLE_STEP_CELLS, map_size.x)
		var depth := _edge_depth(x, side, maximum_depth_cells)
		var y := depth if side == 0 else map_size.y - depth
		inner.append(Vector2(x, y))
	var polygon := PackedVector2Array()
	if side == 0:
		polygon.append(Vector2.ZERO)
		polygon.append(Vector2(map_size.x, 0.0))
		for index in range(inner.size() - 1, -1, -1):
			polygon.append(inner[index])
	else:
		polygon.append(map_size)
		polygon.append(Vector2(0.0, map_size.y))
		for point in inner:
			polygon.append(point)
	return polygon


func _vertical_band(side: int, maximum_depth_cells: float) -> PackedVector2Array:
	var inner := PackedVector2Array()
	var sample_count := ceili(map_size.y / SAMPLE_STEP_CELLS)
	for index in range(sample_count + 1):
		var y := minf(float(index) * SAMPLE_STEP_CELLS, map_size.y)
		var depth := _edge_depth(y, side, maximum_depth_cells)
		var x := map_size.x - depth if side == 1 else depth
		inner.append(Vector2(x, y))
	var polygon := PackedVector2Array()
	if side == 1:
		polygon.append(Vector2(map_size.x, 0.0))
		polygon.append(map_size)
		for index in range(inner.size() - 1, -1, -1):
			polygon.append(inner[index])
	else:
		polygon.append(Vector2(0.0, map_size.y))
		polygon.append(Vector2.ZERO)
		for point in inner:
			polygon.append(point)
	return polygon


func _edge_depth(distance: float, side: int, maximum_depth_cells: float) -> float:
	var phase := float(side) * 1.913
	var broad := sin(distance * 0.31 + phase) * 0.16
	var detail := sin(distance * 0.83 + phase * 1.71) * 0.08
	var drift := sin(distance * 0.11 + phase * 0.63) * 0.07
	var factor := clampf(1.0 + broad + detail + drift, 0.68, 1.31)
	return minf(maximum_depth_cells * factor, minf(map_size.x, map_size.y) * 0.25)
