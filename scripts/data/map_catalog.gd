class_name MapCatalog
extends RefCounted

const SIZE := Vector2i(20, 16)
const TERRAIN_ROWS: Array[String] = [
	"....................",
	".......######.......",
	"....................",
	"..##............##..",
	"..##....~~~~....##..",
	"........~~~~........",
	"....##........##....",
	"....##........##....",
	"....##........##....",
	"....##........##....",
	"........~~~~........",
	"..##....~~~~....##..",
	"..##............##..",
	"....................",
	".......######.......",
	"....................",
]

const PLAYER_STRONGHOLD := Vector2i(1, 14)
const ENEMY_STRONGHOLD := Vector2i(17, 0)

const PLAYER_WORKERS: Array[Vector2i] = [
	Vector2i(3, 14),
	Vector2i(3, 15),
	Vector2i(2, 13),
]
const ENEMY_WORKERS: Array[Vector2i] = [
	Vector2i(16, 0),
	Vector2i(16, 1),
	Vector2i(17, 2),
]

const RESOURCES: Array[Dictionary] = [
	{"kind": &"jade", "cell": Vector2i(4, 13), "amount": 1300.0},
	{"kind": &"essence", "cell": Vector2i(5, 15), "amount": 900.0},
	{"kind": &"jade", "cell": Vector2i(15, 2), "amount": 1300.0},
	{"kind": &"essence", "cell": Vector2i(14, 0), "amount": 900.0},
	{"kind": &"jade", "cell": Vector2i(8, 7), "amount": 1700.0},
	{"kind": &"jade", "cell": Vector2i(11, 8), "amount": 1700.0},
	{"kind": &"essence", "cell": Vector2i(7, 9), "amount": 1200.0},
	{"kind": &"essence", "cell": Vector2i(12, 6), "amount": 1200.0},
]


static func terrain_at(cell: Vector2i) -> StringName:
	if not in_bounds(cell):
		return &"void"
	match TERRAIN_ROWS[cell.y].substr(cell.x, 1):
		"#":
			return &"ridge"
		"~":
			return &"water"
		_:
			return &"meadow"


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func is_static_walkable(cell: Vector2i) -> bool:
	return terrain_at(cell) == &"meadow"


static func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			result.append(origin + Vector2i(x, y))
	return result


static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if TERRAIN_ROWS.size() != SIZE.y:
		errors.append("terrain row count must equal map height")
	for row_index in range(TERRAIN_ROWS.size()):
		if TERRAIN_ROWS[row_index].length() != SIZE.x:
			errors.append("terrain row %d must contain %d cells" % [row_index, SIZE.x])
	var occupied := {}
	_validate_footprint("player Stronghold", PLAYER_STRONGHOLD, Vector2i(2, 2), occupied, errors)
	_validate_footprint("enemy Stronghold", ENEMY_STRONGHOLD, Vector2i(2, 2), occupied, errors)
	for index in range(PLAYER_WORKERS.size()):
		_validate_cell("player Worker %d" % index, PLAYER_WORKERS[index], occupied, errors)
	for index in range(ENEMY_WORKERS.size()):
		_validate_cell("enemy Worker %d" % index, ENEMY_WORKERS[index], occupied, errors)
	for index in range(RESOURCES.size()):
		var definition := RESOURCES[index]
		var kind := definition.get("kind", &"") as StringName
		if kind not in [&"jade", &"essence"]:
			errors.append("resource %d has unsupported kind %s" % [index, String(kind)])
		if float(definition.get("amount", 0.0)) <= 0.0:
			errors.append("resource %d must have a positive amount" % index)
		_validate_cell("resource %d" % index, definition.get("cell", Vector2i(-1, -1)) as Vector2i, occupied, errors)
	return errors


static func _validate_footprint(
	label: String,
	origin: Vector2i,
	footprint: Vector2i,
	occupied: Dictionary,
	errors: Array[String],
) -> void:
	for cell in footprint_cells(origin, footprint):
		_validate_cell(label, cell, occupied, errors)


static func _validate_cell(label: String, cell: Vector2i, occupied: Dictionary, errors: Array[String]) -> void:
	if not in_bounds(cell):
		errors.append("%s is out of bounds at %s" % [label, cell])
		return
	if not is_static_walkable(cell):
		errors.append("%s is not on walkable terrain at %s" % [label, cell])
	if occupied.has(cell):
		errors.append("%s overlaps %s at %s" % [label, occupied[cell], cell])
	else:
		occupied[cell] = label
