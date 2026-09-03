class_name MapCatalog
extends RefCounted

# The Fourfold Mandate is authored as a 40 x 40 macro-grid. Every authored
# cell expands to a 2 x 2 gameplay block, producing an 80 x 80 battlefield.
# Four small corner islands connect to one large central continent through one
# Moon Bridge each. The layout is symmetric across both map axes.
const AUTHORED_SIZE := Vector2i(40, 40)
const CELL_SCALE := 2
const SIZE := AUTHORED_SIZE * CELL_SCALE
const TERRAIN_ROWS: Array[String] = [
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~.......~~~~~~~~~~~~~~~~~~~~.......~~~",
	"~~.........~~~~~~~~~~~~~~~~~~.........~~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~......++...~~~~~~~~~~~~~~~~...++......~",
	"~.......++..~~~~~~~~~~~~~~~~..++.......~",
	"~........+=.~..............~.=+........~",
	"~~........==.......##.......==........~~",
	"~~~.......~==..............==~.......~~~",
	"~~~~~~~~~~....................~~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~..........++..........~~~~~~~~~",
	"~~~~~~~~~........++..++........~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~.#.....+......+.....#.~~~~~~~~~",
	"~~~~~~~~~.#.....+......+.....#.~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~........++..++........~~~~~~~~~",
	"~~~~~~~~~..........++..........~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~......................~~~~~~~~~",
	"~~~~~~~~~~....................~~~~~~~~~~",
	"~~~.......~==..............==~.......~~~",
	"~~........==.......##.......==........~~",
	"~........+=.~..............~.=+........~",
	"~.......++..~~~~~~~~~~~~~~~~..++.......~",
	"~......++...~~~~~~~~~~~~~~~~...++......~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~...........~~~~~~~~~~~~~~~~...........~",
	"~~.........~~~~~~~~~~~~~~~~~~.........~~",
	"~~~.......~~~~~~~~~~~~~~~~~~~~.......~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]

const PLAYER_STRONGHOLD := Vector2i(8, 68)
const ENEMY_STRONGHOLD := Vector2i(70, 8)
const RIVAL_TWO_STRONGHOLD := Vector2i(8, 8)
const RIVAL_THREE_STRONGHOLD := Vector2i(70, 68)
const ENEMY_WAR_CAMP := Vector2i(66, 13)
const PLAYER_BUILD_TEST_SITE := Vector2i(12, 66)

const PLAYER_WORKERS: Array[Vector2i] = [Vector2i(11, 69), Vector2i(8, 72), Vector2i(6, 67)]
const ENEMY_WORKERS: Array[Vector2i] = [Vector2i(68, 11), Vector2i(72, 8), Vector2i(73, 6)]
const RIVAL_TWO_WORKERS: Array[Vector2i] = [Vector2i(11, 9), Vector2i(8, 12), Vector2i(6, 7)]
const RIVAL_THREE_WORKERS: Array[Vector2i] = [Vector2i(68, 71), Vector2i(72, 72), Vector2i(73, 66)]

const STARTS: Array[Dictionary] = [
	{"stronghold": PLAYER_STRONGHOLD, "workers": PLAYER_WORKERS, "war_camp": Vector2i(13, 68), "corner": &"southwest"},
	{"stronghold": ENEMY_STRONGHOLD, "workers": ENEMY_WORKERS, "war_camp": ENEMY_WAR_CAMP, "corner": &"northeast"},
	{"stronghold": RIVAL_TWO_STRONGHOLD, "workers": RIVAL_TWO_WORKERS, "war_camp": Vector2i(13, 8), "corner": &"northwest"},
	{"stronghold": RIVAL_THREE_STRONGHOLD, "workers": RIVAL_THREE_WORKERS, "war_camp": Vector2i(66, 68), "corner": &"southeast"},
]

const SHENLONG_CELL := Vector2i(40, 36)
const SHENLONG_EGG_CELL := Vector2i(40, 40)

# Four Yaoguai Dens form an outer objective ring on the central continent.
const CAVES: Array[Dictionary] = [
	{"cell": Vector2i(24, 24), "entrance": Vector2i(27, 26), "guardians": [Vector2i(28, 24), Vector2i(28, 27), Vector2i(26, 28)]},
	{"cell": Vector2i(54, 24), "entrance": Vector2i(52, 27), "guardians": [Vector2i(51, 24), Vector2i(51, 27), Vector2i(53, 28)]},
	{"cell": Vector2i(24, 54), "entrance": Vector2i(27, 53), "guardians": [Vector2i(28, 55), Vector2i(28, 52), Vector2i(26, 51)]},
	{"cell": Vector2i(54, 54), "entrance": Vector2i(52, 53), "guardians": [Vector2i(51, 55), Vector2i(51, 52), Vector2i(53, 51)]},
]

# Every island has one safe Jade and Essence source. The central continent adds
# four symmetric rings of richer deposits to force expansion and conflict.
const RESOURCES: Array[Dictionary] = [
	{"kind": &"jade", "cell": Vector2i(4, 14), "amount": 1200.0},
	{"kind": &"jade", "cell": Vector2i(75, 14), "amount": 1200.0},
	{"kind": &"jade", "cell": Vector2i(4, 65), "amount": 1200.0},
	{"kind": &"jade", "cell": Vector2i(75, 65), "amount": 1200.0},
	{"kind": &"essence", "cell": Vector2i(14, 4), "amount": 900.0},
	{"kind": &"essence", "cell": Vector2i(65, 4), "amount": 900.0},
	{"kind": &"essence", "cell": Vector2i(14, 75), "amount": 900.0},
	{"kind": &"essence", "cell": Vector2i(65, 75), "amount": 900.0},
	{"kind": &"jade", "cell": Vector2i(26, 34), "amount": 2200.0},
	{"kind": &"jade", "cell": Vector2i(53, 34), "amount": 2200.0},
	{"kind": &"jade", "cell": Vector2i(26, 45), "amount": 2200.0},
	{"kind": &"jade", "cell": Vector2i(53, 45), "amount": 2200.0},
	{"kind": &"essence", "cell": Vector2i(34, 26), "amount": 1800.0},
	{"kind": &"essence", "cell": Vector2i(45, 26), "amount": 1800.0},
	{"kind": &"essence", "cell": Vector2i(34, 53), "amount": 1800.0},
	{"kind": &"essence", "cell": Vector2i(45, 53), "amount": 1800.0},
	{"kind": &"jade", "cell": Vector2i(30, 21), "amount": 2600.0},
	{"kind": &"jade", "cell": Vector2i(49, 21), "amount": 2600.0},
	{"kind": &"jade", "cell": Vector2i(30, 58), "amount": 2600.0},
	{"kind": &"jade", "cell": Vector2i(49, 58), "amount": 2600.0},
	{"kind": &"essence", "cell": Vector2i(21, 30), "amount": 2100.0},
	{"kind": &"essence", "cell": Vector2i(58, 30), "amount": 2100.0},
	{"kind": &"essence", "cell": Vector2i(21, 49), "amount": 2100.0},
	{"kind": &"essence", "cell": Vector2i(58, 49), "amount": 2100.0},
]

# Five species appear in fourfold-symmetric herds. Chickens provision each
# starting island; the more valuable and dangerous species occupy the center.
const WILDLIFE_HERDS: Array[Dictionary] = [
	# One modest food herd per island keeps hunting economies viable before the
	# bridge opens into the far richer central wildlife grounds.
	{"kind": &"chicken", "center": Vector2i(9, 17), "count": 5, "radius": 3.0},
	{"kind": &"chicken", "center": Vector2i(70, 17), "count": 5, "radius": 3.0},
	{"kind": &"chicken", "center": Vector2i(9, 62), "count": 5, "radius": 3.0},
	{"kind": &"chicken", "center": Vector2i(70, 62), "count": 5, "radius": 3.0},
	{"kind": &"deer", "center": Vector2i(22, 38), "count": 4, "radius": 4.0},
	{"kind": &"deer", "center": Vector2i(57, 38), "count": 4, "radius": 4.0},
	{"kind": &"deer", "center": Vector2i(22, 41), "count": 4, "radius": 4.0},
	{"kind": &"deer", "center": Vector2i(57, 41), "count": 4, "radius": 4.0},
	{"kind": &"bison", "center": Vector2i(38, 22), "count": 3, "radius": 3.5},
	{"kind": &"bison", "center": Vector2i(41, 22), "count": 3, "radius": 3.5},
	{"kind": &"bison", "center": Vector2i(38, 57), "count": 3, "radius": 3.5},
	{"kind": &"bison", "center": Vector2i(41, 57), "count": 3, "radius": 3.5},
	{"kind": &"boar", "center": Vector2i(31, 29), "count": 3, "radius": 3.0},
	{"kind": &"boar", "center": Vector2i(48, 29), "count": 3, "radius": 3.0},
	{"kind": &"boar", "center": Vector2i(31, 50), "count": 3, "radius": 3.0},
	{"kind": &"boar", "center": Vector2i(48, 50), "count": 3, "radius": 3.0},
	{"kind": &"bear", "center": Vector2i(35, 32), "count": 2, "radius": 2.5},
	{"kind": &"bear", "center": Vector2i(44, 32), "count": 2, "radius": 2.5},
	{"kind": &"bear", "center": Vector2i(35, 47), "count": 2, "radius": 2.5},
	{"kind": &"bear", "center": Vector2i(44, 47), "count": 2, "radius": 2.5},
]

const TREE_YIELD := 300.0
const TREE_GROVES: Array[Dictionary] = [
	{"center": Vector2i(18, 34), "radius": 4, "variant": &"lumber_pine"},
	{"center": Vector2i(61, 34), "radius": 4, "variant": &"lumber_pine"},
	{"center": Vector2i(18, 45), "radius": 4, "variant": &"lumber_pine"},
	{"center": Vector2i(61, 45), "radius": 4, "variant": &"lumber_pine"},
	{"center": Vector2i(34, 18), "radius": 4, "variant": &"lumber_cedar"},
	{"center": Vector2i(45, 18), "radius": 4, "variant": &"lumber_cedar"},
	{"center": Vector2i(34, 61), "radius": 4, "variant": &"lumber_cedar"},
	{"center": Vector2i(45, 61), "radius": 4, "variant": &"lumber_cedar"},
	{"center": Vector2i(29, 39), "radius": 3, "variant": &"lumber_fir"},
	{"center": Vector2i(50, 39), "radius": 3, "variant": &"lumber_fir"},
	{"center": Vector2i(29, 40), "radius": 3, "variant": &"lumber_fir"},
	{"center": Vector2i(50, 40), "radius": 3, "variant": &"lumber_fir"},
	{"center": Vector2i(5, 5), "radius": 2, "variant": &"lumber_juniper"},
	{"center": Vector2i(74, 5), "radius": 2, "variant": &"lumber_juniper"},
	{"center": Vector2i(5, 74), "radius": 2, "variant": &"lumber_juniper"},
	{"center": Vector2i(74, 74), "radius": 2, "variant": &"lumber_juniper"},
]


static func terrain_at(cell: Vector2i) -> StringName:
	if not in_bounds(cell):
		return &"void"
	var authored_cell := Vector2i(floori(float(cell.x) / float(CELL_SCALE)), floori(float(cell.y) / float(CELL_SCALE)))
	match TERRAIN_ROWS[authored_cell.y].substr(authored_cell.x, 1):
		"#": return &"ridge"
		"~": return &"water"
		"=": return &"bridge"
		"+": return &"road"
		_: return &"meadow"


static func start_definition(team: int) -> Dictionary:
	if team < 0 or team >= STARTS.size():
		return {}
	return STARTS[team]


static func tree_definitions() -> Array[Dictionary]:
	var trees: Array[Dictionary] = []
	var occupied := _reserved_cells()
	for grove in TREE_GROVES:
		var center := grove["center"] as Vector2i
		var radius := int(grove["radius"])
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if not in_bounds(cell) or not is_buildable(cell) or occupied.has(cell):
					continue
				if cell.distance_squared_to(center) > radius * radius or posmod(x * 3 + y * 5, 4) == 0:
					continue
				trees.append({"kind": &"lumber", "variant": grove["variant"], "cell": cell, "amount": TREE_YIELD})
				occupied[cell] = true
	return trees


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


static func is_static_walkable(cell: Vector2i) -> bool:
	return terrain_at(cell) in [&"meadow", &"road", &"bridge"]


static func is_buildable(cell: Vector2i) -> bool:
	return terrain_at(cell) == &"meadow"


static func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(footprint.y):
		for x in range(footprint.x):
			result.append(origin + Vector2i(x, y))
	return result


static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if TERRAIN_ROWS.size() != AUTHORED_SIZE.y:
		errors.append("terrain row count must equal authored map height")
	for row_index in range(TERRAIN_ROWS.size()):
		if TERRAIN_ROWS[row_index].length() != AUTHORED_SIZE.x:
			errors.append("terrain row %d must contain %d cells" % [row_index, AUTHORED_SIZE.x])
	if STARTS.size() != 4:
		errors.append("the map must define exactly four player starts")
	var occupied := {}
	for team in range(STARTS.size()):
		var start := STARTS[team]
		_validate_footprint("team %d Stronghold" % team, start["stronghold"] as Vector2i, Vector2i(2, 2), occupied, errors)
		_validate_cell("team %d War Camp site" % team, start["war_camp"] as Vector2i, occupied, errors)
		var workers := start["workers"] as Array
		if workers.size() != 3:
			errors.append("team %d must start with three Workers" % team)
		for worker_index in range(workers.size()):
			_validate_cell("team %d Worker %d" % [team, worker_index], workers[worker_index] as Vector2i, occupied, errors)
	for index in range(RESOURCES.size()):
		var definition := RESOURCES[index]
		var kind := definition.get("kind", &"") as StringName
		if kind not in [&"jade", &"essence"]:
			errors.append("resource %d has unsupported kind %s" % [index, String(kind)])
		if float(definition.get("amount", 0.0)) <= 0.0:
			errors.append("resource %d must have a positive amount" % index)
		_validate_cell("resource %d" % index, definition.get("cell", Vector2i(-1, -1)) as Vector2i, occupied, errors)
	for index in range(CAVES.size()):
		var cave := CAVES[index]
		_validate_footprint("Yaoguai Den %d" % index, cave.get("cell", Vector2i(-1, -1)) as Vector2i, Vector2i(2, 2), occupied, errors)
		for guardian_index in range((cave.get("guardians", []) as Array).size()):
			_validate_cell("Yaoguai Den %d guardian %d" % [index, guardian_index], (cave["guardians"] as Array)[guardian_index] as Vector2i, occupied, errors)
	_validate_cell("Shenlong", SHENLONG_CELL, occupied, errors)
	_validate_cell("Shenlong egg", SHENLONG_EGG_CELL, occupied, errors)
	var trees := tree_definitions()
	for index in range(trees.size()):
		_validate_cell("tree %d" % index, trees[index]["cell"] as Vector2i, occupied, errors)
	for index in range(WILDLIFE_HERDS.size()):
		var herd := WILDLIFE_HERDS[index]
		var kind := herd.get("kind", &"") as StringName
		var center := herd.get("center", Vector2i(-1, -1)) as Vector2i
		if kind not in [&"chicken", &"deer", &"bison", &"boar", &"bear"]:
			errors.append("wildlife herd %d has unsupported kind %s" % [index, String(kind)])
		if int(herd.get("count", 0)) <= 0 or float(herd.get("radius", -1.0)) < 0.0:
			errors.append("wildlife herd %d has invalid size or radius" % index)
		if not in_bounds(center) or not is_static_walkable(center):
			errors.append("wildlife herd %d center is not walkable at %s" % [index, center])
	return errors


static func _reserved_cells() -> Dictionary:
	var reserved := {}
	for start in STARTS:
		for cell in footprint_cells(start["stronghold"] as Vector2i, Vector2i(2, 2)):
			reserved[cell] = true
		reserved[start["war_camp"] as Vector2i] = true
		for raw_worker in start["workers"] as Array:
			reserved[raw_worker as Vector2i] = true
	for resource in RESOURCES:
		reserved[resource["cell"] as Vector2i] = true
	for cave in CAVES:
		for cell in footprint_cells(cave["cell"] as Vector2i, Vector2i(2, 2)):
			reserved[cell] = true
		reserved[cave["entrance"] as Vector2i] = true
		for raw_guardian in cave["guardians"] as Array:
			reserved[raw_guardian as Vector2i] = true
	reserved[SHENLONG_CELL] = true
	reserved[SHENLONG_EGG_CELL] = true
	for herd in WILDLIFE_HERDS:
		var center := herd["center"] as Vector2i
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			reserved[center + offset] = true
	return reserved


static func _validate_footprint(label: String, origin: Vector2i, footprint: Vector2i, occupied: Dictionary, errors: Array[String]) -> void:
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
