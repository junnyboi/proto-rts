extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for validation_error in MapCatalog.validation_errors():
		failures.append("startup validation: %s" % validation_error)
	if MapCatalog.SIZE != Vector2i(80, 64):
		failures.append("expected an 80 x 64 map, got %s" % MapCatalog.SIZE)
	if MapCatalog.SIZE.x * MapCatalog.SIZE.y != 5120:
		failures.append("map area is not exactly four times the prior 1,280 cells")
	if MapCatalog.TERRAIN_ROWS.size() != MapCatalog.AUTHORED_SIZE.y:
		failures.append("terrain row count does not match authored map height")
	for row_index in range(MapCatalog.TERRAIN_ROWS.size()):
		if MapCatalog.TERRAIN_ROWS[row_index].length() != MapCatalog.AUTHORED_SIZE.x:
			failures.append("terrain row %d does not match authored map width" % row_index)
	if MapCatalog.TREE_ROWS.size() != MapCatalog.AUTHORED_SIZE.y:
		failures.append("tree row count does not match authored map height")
	for row_index in range(MapCatalog.TREE_ROWS.size()):
		if MapCatalog.TREE_ROWS[row_index].length() != MapCatalog.AUTHORED_SIZE.x:
			failures.append("tree row %d does not match authored map width" % row_index)

	var terrain_counts := {
		&"forest": 0,
		&"water": 0,
		&"bridge": 0,
		&"road": 0,
	}
	var bridge_rows: Dictionary = {}
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var terrain := MapCatalog.terrain_at(cell)
			if terrain_counts.has(terrain):
				terrain_counts[terrain] = int(terrain_counts[terrain]) + 1
			if terrain == &"bridge":
				bridge_rows[y] = true
			if terrain != MapCatalog.terrain_at(MapCatalog.SIZE - Vector2i.ONE - cell):
				failures.append("terrain is not rotationally symmetric at %s" % cell)
				y = MapCatalog.SIZE.y
				break
	if int(terrain_counts[&"forest"]) != 0:
		failures.append("painted forest still creates permanent unclearable blockers")
	if int(terrain_counts[&"water"]) < 280:
		failures.append("river does not form a substantial player separator")
	if int(terrain_counts[&"bridge"]) != 48:
		failures.append("expected 48 bridge cells across two scaled outer crossings")
	for expected_row in [10, 11, 12, 13, 50, 51, 52, 53]:
		if not bridge_rows.has(expected_row):
			failures.append("crossing is missing bridge row %d" % expected_row)
	for removed_row in [30, 31, 32, 33]:
		if bridge_rows.has(removed_row):
			failures.append("removed central crossing still has a bridge on row %d" % removed_row)

	var trees := MapCatalog.tree_definitions()
	var tree_cells: Dictionary = {}
	var expected_tree_variants := {
		&"lumber_pine": 688,
		&"lumber_cedar": 496,
		&"lumber_fir": 520,
		&"lumber_juniper": 520,
	}
	var tree_variant_counts: Dictionary = {}
	var perimeter_tree_counts := {"top": 0, "bottom": 0, "left": 0, "right": 0}
	for tree in trees:
		var tree_cell := tree["cell"] as Vector2i
		var tree_variant := tree.get("variant", &"") as StringName
		if tree_cells.has(tree_cell):
			failures.append("duplicate tree at %s" % tree_cell)
		tree_cells[tree_cell] = tree
		if not expected_tree_variants.has(tree_variant):
			failures.append("tree at %s uses unsupported variant %s" % [tree_cell, tree_variant])
		tree_variant_counts[tree_variant] = int(tree_variant_counts.get(tree_variant, 0)) + 1
		if tree.get("kind") != &"lumber" or float(tree.get("amount", 0.0)) != MapCatalog.TREE_YIELD:
			failures.append("tree at %s has invalid Lumber data" % tree_cell)
		if not MapCatalog.is_buildable(tree_cell):
			failures.append("harvestable tree is not rooted in meadow at %s" % tree_cell)
		if tree_cell.y < 6:
			perimeter_tree_counts["top"] += 1
		if tree_cell.y >= MapCatalog.SIZE.y - 6:
			perimeter_tree_counts["bottom"] += 1
		if tree_cell.x < 6:
			perimeter_tree_counts["left"] += 1
		if tree_cell.x >= MapCatalog.SIZE.x - 6:
			perimeter_tree_counts["right"] += 1
	if trees.size() != 2224:
		failures.append("expected 2,224 trees across the groves and organic perimeter woodland")
	for side in perimeter_tree_counts:
		var minimum := 300 if side in ["top", "bottom"] else 250
		if int(perimeter_tree_counts[side]) < minimum:
			failures.append("%s map side does not have a dense tree perimeter" % side)
	for variant in expected_tree_variants:
		if int(tree_variant_counts.get(variant, 0)) != int(expected_tree_variants[variant]):
			failures.append(
				"expected %d %s trees, found %d"
				% [expected_tree_variants[variant], variant, tree_variant_counts.get(variant, 0)]
			)
	for tree in trees:
		var tree_cell := tree["cell"] as Vector2i
		var counterpart := MapCatalog.SIZE - Vector2i.ONE - tree_cell
		if not tree_cells.has(counterpart):
			failures.append("tree at %s has no rotational counterpart" % tree_cell)
		elif tree_cells[counterpart].get("variant") != tree.get("variant"):
			failures.append("tree variants are not symmetric at %s" % tree_cell)

	if MapCatalog.WILDLIFE_HERDS.size() != 10:
		failures.append("expected ten mirrored wildlife herds")
	var herd_species_counts: Dictionary = {}
	var animal_count := 0
	var total_food := 0
	for herd in MapCatalog.WILDLIFE_HERDS:
		var herd_kind := herd.get("kind", &"") as StringName
		var herd_center := herd["center"] as Vector2i
		var herd_count := int(herd.get("count", 0))
		var herd_radius := float(herd.get("radius", 0.0))
		herd_species_counts[herd_kind] = int(herd_species_counts.get(herd_kind, 0)) + 1
		animal_count += herd_count
		total_food += herd_count * int(FactionCatalog.stats(herd_kind, &"neutral").get("food_bounty", 0))
		if herd_kind not in FactionCatalog.WILDLIFE_KINDS:
			failures.append("unsupported wildlife herd kind %s" % herd_kind)
		if not MapCatalog.is_static_walkable(herd_center) or tree_cells.has(herd_center):
			failures.append("wildlife herd center is blocked at %s" % herd_center)
		if herd_count <= 0 or herd_radius <= 0.0:
			failures.append("wildlife herd at %s has invalid size or radius" % herd_center)
		var counterpart_center := MapCatalog.SIZE - Vector2i.ONE - herd_center
		var found_herd_counterpart := false
		for candidate in MapCatalog.WILDLIFE_HERDS:
			if (
				candidate.get("kind") == herd_kind
				and (candidate["center"] as Vector2i) == counterpart_center
				and int(candidate.get("count", 0)) == herd_count
				and is_equal_approx(float(candidate.get("radius", 0.0)), herd_radius)
			):
				found_herd_counterpart = true
				break
		if not found_herd_counterpart:
			failures.append("wildlife herd at %s has no matching counterpart" % herd_center)
	if animal_count != 34:
		failures.append("expected 34 wildlife members, found %d" % animal_count)
	if total_food != 1448:
		failures.append("wildlife roster contains %d Food instead of 1,448" % total_food)
	for wildlife_kind in FactionCatalog.WILDLIFE_KINDS:
		if int(herd_species_counts.get(wildlife_kind, 0)) != 2:
			failures.append("expected two mirrored %s herds" % wildlife_kind)

	for origin in [MapCatalog.PLAYER_STRONGHOLD, MapCatalog.ENEMY_STRONGHOLD]:
		for cell in MapCatalog.footprint_cells(origin, Vector2i(2, 2)):
			if not MapCatalog.is_buildable(cell):
				failures.append("stronghold footprint is not on buildable meadow at %s" % cell)
			if tree_cells.has(cell):
				failures.append("tree overlaps a stronghold footprint at %s" % cell)
	for resource in MapCatalog.RESOURCES:
		var resource_cell := resource["cell"] as Vector2i
		if not MapCatalog.is_static_walkable(resource_cell):
			failures.append("resource glade is not reachable at %s" % resource_cell)
		if tree_cells.has(resource_cell):
			failures.append("tree overlaps an expansion resource at %s" % resource_cell)
	if MapCatalog.CAVES.size() != 2:
		failures.append("expected two mirrored Yaoguai Dens")
	for cave in MapCatalog.CAVES:
		var cave_cell := cave["cell"] as Vector2i
		var counterpart_cell := MapCatalog.SIZE - Vector2i(2, 2) - cave_cell
		var found_counterpart := false
		for candidate in MapCatalog.CAVES:
			if candidate["cell"] as Vector2i == counterpart_cell:
				found_counterpart = true
				break
		if not found_counterpart:
			failures.append("Yaoguai Den at %s has no rotational counterpart" % cave_cell)
		for cave_footprint_cell in MapCatalog.footprint_cells(cave_cell, Vector2i(2, 2)):
			if not MapCatalog.is_buildable(cave_footprint_cell):
				failures.append("Yaoguai Den footprint is not on meadow at %s" % cave_footprint_cell)
			if tree_cells.has(cave_footprint_cell):
				failures.append("tree overlaps Yaoguai Den footprint at %s" % cave_footprint_cell)
		for raw_guardian_cell in cave["guardians"] as Array:
			var guardian_cell := raw_guardian_cell as Vector2i
			if not MapCatalog.is_static_walkable(guardian_cell) or tree_cells.has(guardian_cell):
				failures.append("Yaoguai guardian cannot stand at %s" % guardian_cell)
	if MapCatalog.is_buildable(Vector2i(8, 58)):
		failures.append("Meridian roads must remain non-buildable")
	if not MapCatalog.is_static_walkable(Vector2i(16, 10)) or MapCatalog.is_buildable(Vector2i(16, 10)):
		failures.append("outer bridge must be walkable but non-buildable")
	if MapCatalog.terrain_at(Vector2i(38, 30)) != &"water":
		failures.append("central Moon Gate must be water after bridge removal")

	var start := MapCatalog.PLAYER_WORKERS[0]
	var destination := MapCatalog.ENEMY_WORKERS[0]
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not frontier.is_empty():
		var current := frontier.pop_front() as Vector2i
		for direction in directions:
			var neighbor: Vector2i = current + direction
			if (
				MapCatalog.is_static_walkable(neighbor)
				and not tree_cells.has(neighbor)
				and not visited.has(neighbor)
			):
				visited[neighbor] = true
				frontier.append(neighbor)
	if not visited.has(destination):
		failures.append("the river and tree groves disconnect the two starting armies")

	if failures.is_empty():
		print("PASS map_test: size, symmetry, river crossings, clearable groves, wildlife, economy, connectivity")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
