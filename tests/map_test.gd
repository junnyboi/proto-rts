extends SceneTree

const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for validation_error in MapCatalog.validation_errors():
		failures.append("startup validation: %s" % validation_error)
	if MapCatalog.SIZE != Vector2i(80, 80):
		failures.append("expected an 80 x 80 four-player map, got %s" % MapCatalog.SIZE)
	if MapCatalog.STARTS.size() != 4:
		failures.append("expected four corner starts")
	if MapCatalog.TERRAIN_ROWS.size() != MapCatalog.AUTHORED_SIZE.y:
		failures.append("terrain row count does not match authored height")
	for row_index in range(MapCatalog.TERRAIN_ROWS.size()):
		if MapCatalog.TERRAIN_ROWS[row_index].length() != MapCatalog.AUTHORED_SIZE.x:
			failures.append("terrain row %d does not match authored width" % row_index)

	var terrain_counts := {&"water": 0, &"bridge": 0, &"road": 0, &"ridge": 0}
	var bridge_cells: Dictionary = {}
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var terrain := MapCatalog.terrain_at(cell)
			if terrain_counts.has(terrain):
				terrain_counts[terrain] = int(terrain_counts[terrain]) + 1
			if terrain == &"bridge":
				bridge_cells[cell] = true
			var horizontal := Vector2i(MapCatalog.SIZE.x - 1 - x, y)
			var vertical := Vector2i(x, MapCatalog.SIZE.y - 1 - y)
			if terrain != MapCatalog.terrain_at(horizontal) or terrain != MapCatalog.terrain_at(vertical):
				failures.append("terrain is not fourfold symmetric at %s" % cell)
	if int(terrain_counts[&"water"]) < 2500:
		failures.append("the archipelago does not contain enough separating water")
	if int(terrain_counts[&"bridge"]) != 80:
		failures.append("expected 80 gameplay bridge cells across four crossings")
	var bridge_components := _components(bridge_cells)
	if bridge_components.size() != 4:
		failures.append("expected four disconnected Moon Bridge components, found %d" % bridge_components.size())
	for component in bridge_components:
		if (component as Array).size() != 20:
			failures.append("each bridge must contain 20 gameplay cells")

	var trees := MapCatalog.tree_definitions()
	var tree_cells: Dictionary = {}
	var variants: Dictionary = {}
	for tree in trees:
		var cell := tree["cell"] as Vector2i
		if tree_cells.has(cell):
			failures.append("duplicate tree at %s" % cell)
		tree_cells[cell] = true
		var variant := tree.get("variant", &"") as StringName
		variants[variant] = int(variants.get(variant, 0)) + 1
		if float(tree.get("amount", 0.0)) != MapCatalog.TREE_YIELD or not MapCatalog.is_buildable(cell):
			failures.append("invalid harvestable tree at %s" % cell)
	if trees.size() < 200:
		failures.append("central and island groves are not dense enough")
	for variant in [&"lumber_pine", &"lumber_cedar", &"lumber_fir", &"lumber_juniper"]:
		if int(variants.get(variant, 0)) <= 0:
			failures.append("missing tree variant %s" % String(variant))

	if MapCatalog.RESOURCES.size() != 24:
		failures.append("expected 24 Jade and Essence sources")
	var island_resources := 0
	for resource in MapCatalog.RESOURCES:
		var cell := resource["cell"] as Vector2i
		if not MapCatalog.is_static_walkable(cell) or tree_cells.has(cell):
			failures.append("resource is blocked at %s" % cell)
		if cell.x < 18 or cell.x > 61 or cell.y < 18 or cell.y > 61:
			island_resources += 1
		for counterpart in [Vector2i(MapCatalog.SIZE.x - 1 - cell.x, cell.y), Vector2i(cell.x, MapCatalog.SIZE.y - 1 - cell.y)]:
			if not _has_matching_resource(resource, counterpart):
				failures.append("resource at %s lacks a symmetric counterpart at %s" % [cell, counterpart])
	if island_resources != 8:
		failures.append("each island must have exactly one Jade and one Essence source")

	if MapCatalog.CAVES.size() != 4:
		failures.append("expected four Yaoguai Dens on the central continent")
	for cave in MapCatalog.CAVES:
		var cell := cave["cell"] as Vector2i
		for footprint_cell in MapCatalog.footprint_cells(cell, Vector2i(2, 2)):
			if not MapCatalog.is_buildable(footprint_cell) or tree_cells.has(footprint_cell):
				failures.append("Yaoguai Den footprint is blocked at %s" % footprint_cell)

	if MapCatalog.WILDLIFE_HERDS.size() != 20:
		failures.append("expected 20 fourfold-symmetric wildlife herds")
	var herd_species_counts: Dictionary = {}
	var animal_count := 0
	for herd in MapCatalog.WILDLIFE_HERDS:
		var kind := herd["kind"] as StringName
		herd_species_counts[kind] = int(herd_species_counts.get(kind, 0)) + 1
		animal_count += int(herd["count"])
		var center := herd["center"] as Vector2i
		if not MapCatalog.is_static_walkable(center) or tree_cells.has(center):
			failures.append("wildlife herd center is blocked at %s" % center)
	for kind in FactionCatalog.WILDLIFE_KINDS:
		if int(herd_species_counts.get(kind, 0)) != 4:
			failures.append("expected four %s herds" % String(kind))
	if animal_count != 68:
		failures.append("expected 68 wildlife members, found %d" % animal_count)

	if MapCatalog.SHENLONG_EGG_CELL != MapCatalog.SIZE / 2:
		failures.append("the Dragon Egg is not at the exact map center")
	if not MapCatalog.is_buildable(MapCatalog.SHENLONG_CELL) or not MapCatalog.is_buildable(MapCatalog.SHENLONG_EGG_CELL):
		failures.append("the Shenlong objective is not on central meadow")
	if tree_cells.has(MapCatalog.SHENLONG_CELL) or tree_cells.has(MapCatalog.SHENLONG_EGG_CELL):
		failures.append("trees overlap the Shenlong objective")

	var static_blockers := tree_cells.duplicate()
	for resource in MapCatalog.RESOURCES:
		static_blockers[resource["cell"] as Vector2i] = true
	for cave in MapCatalog.CAVES:
		for cell in MapCatalog.footprint_cells(cave["cell"] as Vector2i, Vector2i(2, 2)):
			static_blockers[cell] = true
	static_blockers[MapCatalog.SHENLONG_EGG_CELL] = true
	for team in range(MapCatalog.STARTS.size()):
		var start := MapCatalog.start_definition(team)
		var workers := start["workers"] as Array
		var origin := workers[0] as Vector2i
		var center_approach := MapCatalog.SHENLONG_EGG_CELL + Vector2i(0, 2)
		if not _reachable(origin, center_approach, static_blockers, true):
			failures.append("team %d cannot reach the central continent" % team)
		if _reachable(origin, center_approach, static_blockers, false):
			failures.append("team %d island remains connected after removing its bridge" % team)
		var hold := start["stronghold"] as Vector2i
		if not (hold.x < 20 or hold.x > 59) or not (hold.y < 20 or hold.y > 59):
			failures.append("team %d Stronghold is not on a corner island" % team)
		if (start["workers"] as Array).size() != 3:
			failures.append("team %d does not have three starting Workers" % team)

	if failures.is_empty():
		print("PASS map_test: four islands, four bridges, central continent, symmetric economy, caves, wildlife, groves, and connectivity")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _components(cells: Dictionary) -> Array[Array]:
	var remaining := cells.duplicate()
	var result: Array[Array] = []
	while not remaining.is_empty():
		var seed := remaining.keys()[0] as Vector2i
		remaining.erase(seed)
		var frontier: Array[Vector2i] = [seed]
		var component: Array = []
		while not frontier.is_empty():
			var current := frontier.pop_back() as Vector2i
			component.append(current)
			for direction in CARDINALS:
				var neighbor := current + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					frontier.append(neighbor)
		result.append(component)
	return result


func _has_matching_resource(source: Dictionary, cell: Vector2i) -> bool:
	for candidate in MapCatalog.RESOURCES:
		if (
			(candidate["cell"] as Vector2i) == cell
			and candidate.get("kind") == source.get("kind")
			and is_equal_approx(float(candidate.get("amount", 0.0)), float(source.get("amount", 0.0)))
		):
			return true
	return false


func _reachable(origin: Vector2i, destination: Vector2i, blockers: Dictionary, include_bridges: bool) -> bool:
	var frontier: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: true}
	while not frontier.is_empty():
		var current := frontier.pop_front() as Vector2i
		if current == destination:
			return true
		for direction in CARDINALS:
			var neighbor := current + direction
			if visited.has(neighbor) or blockers.has(neighbor) or not MapCatalog.is_static_walkable(neighbor):
				continue
			if not include_bridges and MapCatalog.terrain_at(neighbor) == &"bridge":
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return false
