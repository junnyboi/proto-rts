class_name IsoProjection
extends RefCounted

const TILE_WIDTH := 96.0
const TILE_HEIGHT := 48.0


static func project(cell_position: Vector2) -> Vector2:
	return Vector2(
		(cell_position.x - cell_position.y) * TILE_WIDTH * 0.5,
		(cell_position.x + cell_position.y) * TILE_HEIGHT * 0.5,
	)


static func unproject(local_position: Vector2) -> Vector2:
	var horizontal := local_position.x / (TILE_WIDTH * 0.5)
	var vertical := local_position.y / (TILE_HEIGHT * 0.5)
	return Vector2((horizontal + vertical) * 0.5, (vertical - horizontal) * 0.5)


static func cell_at(local_position: Vector2) -> Vector2i:
	var point := unproject(local_position)
	var snapped := (point * 2.0).round() * 0.5
	if point.distance_to(snapped) < 0.0001:
		point = snapped
	return Vector2i(point.floor())


static func cell_center(cell: Vector2i) -> Vector2:
	return project(Vector2(cell) + Vector2(0.5, 0.5))


static func position_center(cell_position: Vector2) -> Vector2:
	return project(cell_position + Vector2(0.5, 0.5))


static func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var origin := Vector2(cell)
	return PackedVector2Array([
		project(origin),
		project(origin + Vector2(1.0, 0.0)),
		project(origin + Vector2(1.0, 1.0)),
		project(origin + Vector2(0.0, 1.0)),
	])


static func transformed_polygon(
	cell: Vector2i,
	scale: float,
	offset: Vector2,
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in cell_polygon(cell):
		result.append(point * scale + offset)
	return result


static func depth(cell_position: Vector2) -> float:
	return cell_position.x + cell_position.y


static func map_bounds(size: Vector2i) -> Rect2:
	var points := PackedVector2Array([
		project(Vector2.ZERO),
		project(Vector2(size.x, 0.0)),
		project(Vector2(size)),
		project(Vector2(0.0, size.y)),
	])
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result
