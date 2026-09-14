extends RefCounted

# One map cell is larger than the separation radius. A possible contact is
# therefore always in the same bucket or one of its eight neighbors.
const CELL_SIZE := 1.0

var _buckets: Dictionary = {}


func rebuild(unit_ids: Array[int], entities: Dictionary) -> void:
	_buckets.clear()
	for unit_id in unit_ids:
		var unit: Dictionary = entities[unit_id]
		var cell := _bucket_cell(unit["position"] as Vector2)
		if not _buckets.has(cell):
			_buckets[cell] = []
		(_buckets[cell] as Array).append(unit_id)


func later_neighbors(unit_id: int, position: Vector2) -> Array[int]:
	var result: Array[int] = []
	var origin := _bucket_cell(position)
	for y in range(origin.y - 1, origin.y + 2):
		for x in range(origin.x - 1, origin.x + 2):
			for candidate in _buckets.get(Vector2i(x, y), []):
				if int(candidate) > unit_id:
					result.append(int(candidate))
	# Match the original nested ID loops, including floating-point summation
	# order for every pair that can contribute a displacement.
	result.sort()
	return result


func _bucket_cell(position: Vector2) -> Vector2i:
	return Vector2i((position / CELL_SIZE).floor())
