extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	_test_terrain(failures)
	_test_wall_lookup(failures)
	_test_minimap(failures)
	_test_presentation(failures)
	_test_picking(failures)
	if failures.is_empty():
		print("PASS view_cache_test: terrain draw-data equivalence, wall lifecycle/order, minimap pixel equivalence, exact presentation timers, picking ambiguity")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_terrain(failures: Array[String]) -> void:
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield._ensure_terrain_blocks()
	var cells: Array[Vector2i] = []
	# Original terrain traversal, independent of the cached records.
	for depth in range(MapCatalog.AUTHORED_SIZE.x + MapCatalog.AUTHORED_SIZE.y - 1):
		for macro_y in range(MapCatalog.AUTHORED_SIZE.y):
			var macro_x := depth - macro_y
			if macro_x >= 0 and macro_x < MapCatalog.AUTHORED_SIZE.x:
				cells.append(Vector2i(macro_x, macro_y) * MapCatalog.CELL_SCALE)
	_expect(battlefield._terrain_blocks.size() == cells.size(), "terrain cache changed tile count", failures)
	var first_block := battlefield._terrain_blocks[0]
	battlefield._ensure_terrain_blocks()
	_expect(first_block == battlefield._terrain_blocks[0], "static terrain cache rebuilt without a map change", failures)
	for camera in [Vector3(0.15, 400.0, -40.0), Vector3(0.62, 500.0, -900.0), Vector3(1.3, -121.25, -2030.5)]:
		battlefield.camera_scale = camera.x
		battlefield.camera_offset = Vector2(camera.y, camera.z)
		for index in range(cells.size()):
			var block := battlefield._terrain_blocks[index]
			var cell := cells[index]
			_expect(block.cell == cell, "terrain cache changed painter order", failures)
			_expect(block.terrain == MapCatalog.terrain_at(cell), "terrain cache changed tile kind", failures)
			_expect(
				battlefield._terrain_block_polygon(block) == battlefield._transformed_block_polygon(cell, MapCatalog.CELL_SCALE),
				"cached terrain changed projected vertices at %s" % cell, failures,
			)
			_expect(
				battlefield._is_terrain_block_on_screen(block) == battlefield._is_block_on_screen(cell, MapCatalog.CELL_SCALE),
				"cached terrain changed viewport inclusion at %s" % cell, failures,
			)
			for time in [0.0, 1.25, 253.755]:
				battlefield._water_animation_time = time
				var tint := _legacy_terrain_tint(cell, block.terrain, time)
				_expect(
					battlefield._terrain_block_colors(block) == PackedColorArray([tint, tint, tint, tint]),
					"cached terrain changed animated color at %s" % cell, failures,
				)
				var offset: Vector2 = Battlefield.WATER_FLOW_SPEED * time if block.terrain == &"water" else Vector2.ZERO
				_expect(
					battlefield._terrain_block_uvs(block) == battlefield._terrain_uvs(cell, offset, MapCatalog.CELL_SCALE),
					"cached terrain changed UV arithmetic at %s" % cell, failures,
				)
	battlefield.free()


func _legacy_terrain_tint(cell: Vector2i, terrain: StringName, time: float) -> Color:
	match terrain:
		&"ridge": return Color(0.82, 0.87, 0.85, 1.0)
		&"water":
			var current := sin(float(cell.x + cell.y) * 0.72 - time * 2.0)
			var brightness := 0.96 + current * 0.035
			return Color(0.74 * brightness, 0.96 * brightness, brightness, 0.95)
		&"forest": return Color(0.82, 0.94, 0.83, 1.0)
		&"road": return Color(1.0, 0.97, 0.86, 1.0)
		&"bridge": return Color(0.95, 1.0, 0.96, 1.0)
	var macro_cell := cell / MapCatalog.CELL_SCALE
	var variation := 0.92 + float(posmod(macro_cell.x * 17 + macro_cell.y * 29, 7)) * 0.018
	return Color(variation, variation, variation * 0.98, 1.0)


func _test_wall_lookup(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	var battlefield := Battlefield.new()
	battlefield.simulation = simulation
	simulation.entities = {
		1: {"id": 1, "kind": &"wall", "team": 0, "cell": Vector2i(4, 4), "alive": true, "complete": 1.0, "orientation": &"x"},
		2: {"id": 2, "kind": &"wall", "team": 0, "cell": Vector2i(4, 4), "alive": true, "complete": 1.0, "orientation": &"y"},
		3: {"id": 3, "kind": &"gate", "team": 0, "cell": Vector2i(4, 4), "alive": true, "complete": 0.5, "orientation": &"y", "footprint": Vector2i(2, 4)},
	}
	_assert_wall_oracle(battlefield, failures)
	_assert_wall_oracle(battlefield, failures)
	simulation.entities[3]["complete"] = 1.0
	_assert_wall_oracle(battlefield, failures)
	simulation.entities[3]["footprint"] = Vector2i(4, 2)
	simulation.entities[3]["orientation"] = &"x"
	_assert_wall_oracle(battlefield, failures)
	simulation.entities[1]["team"] = 1
	simulation.entities[2]["cell"] = Vector2i(5, 4)
	_assert_wall_oracle(battlefield, failures)
	simulation.entities[1]["alive"] = false
	_assert_wall_oracle(battlefield, failures)
	simulation.entities[4] = simulation.entities[2].duplicate(true)
	simulation.entities[4]["id"] = 4
	_assert_wall_oracle(battlefield, failures)
	var moved: Dictionary = simulation.entities[2]
	simulation.entities.erase(2)
	simulation.entities[2] = moved
	_assert_wall_oracle(battlefield, failures)
	simulation.entities.clear()
	_assert_wall_oracle(battlefield, failures)
	battlefield.free()


func _assert_wall_oracle(battlefield: Battlefield, failures: Array[String]) -> void:
	var walls: Dictionary = {}
	var gates: Dictionary = {}
	# Original unconditional rebuild is the reference for all cache invalidation.
	for entity: Dictionary in battlefield.simulation.entities.values():
		if not bool(entity.get("alive", false)) or float(entity.get("complete", 0.0)) < 1.0:
			continue
		var cell := entity.get("cell", Vector2i(-1, -1)) as Vector2i
		var team := int(entity.get("team", RtsSimulation.TEAM_NEUTRAL))
		if entity.get("kind") == &"gate":
			var bottom_corner := cell + (entity.get("footprint", Vector2i.ONE) as Vector2i) - Vector2i.ONE
			gates[Vector3i(team, bottom_corner.x, bottom_corner.y)] = entity
		elif entity.get("kind") == &"wall":
			var key := Vector3i(team, cell.x, cell.y)
			var orientations := walls.get(key, {}) as Dictionary
			orientations[entity.get("orientation", &"y")] = entity
			walls[key] = orientations
	battlefield._rebuild_wall_render_lookup()
	_expect(battlefield._wall_render_lookup == walls, "wall signature missed a lifecycle/order mutation", failures)
	_expect(battlefield._gate_bottom_corner_render_lookup == gates, "gate signature missed a lifecycle/rotation mutation", failures)


func _test_minimap(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.entities = {
		1: {"id": 1, "kind": &"worker", "category": &"unit", "team": 0, "position": Vector2(3.1, 4.1), "alive": true},
		2: {"id": 2, "kind": &"gate", "category": &"structure", "team": 1, "position": Vector2(2, 3), "footprint": Vector2i(2, 4), "alive": true},
		3: {"id": 3, "kind": &"lumber_pine", "resource_kind": &"lumber", "category": &"resource", "team": -1, "position": Vector2(0, 0), "alive": true},
		4: {"id": 4, "kind": &"bear", "category": &"wildlife", "team": -1, "position": Vector2(79, 79), "alive": true},
		5: {"id": 5, "kind": &"shenlong_egg", "category": &"objective", "team": -1, "position": Vector2(10, 10), "alive": true},
	}
	var battlefield := Battlefield.new()
	battlefield.simulation = simulation
	battlefield.fog_enabled = false
	var minimap := BattlefieldMinimap.new()
	minimap.set_battlefield(battlefield)
	minimap._ensure_image_caches()
	_expect(minimap._refresh_entity_overlay(), "first minimap overlay was not initialized", failures)
	_assert_minimap_markers(minimap, failures)
	_expect(not minimap._refresh_entity_overlay(), "unchanged minimap overlay was repainted", failures)
	simulation.entities[1]["position"] = Vector2(3.9, 4.9)
	_expect(not minimap._refresh_entity_overlay(), "sub-cell movement repainted identical minimap pixels", failures)
	simulation.entities[1]["position"] = Vector2(4.1, 4.9)
	_assert_minimap_markers(minimap, failures)
	simulation.entities[1]["garrisoned_in"] = 2
	simulation.entities[2]["team"] = 3
	simulation.entities[3]["alive"] = false
	_assert_minimap_markers(minimap, failures)
	simulation.entities[5]["position"] = Vector2(79, 79)
	_assert_minimap_markers(minimap, failures)
	battlefield.set_fog_enabled(true)
	battlefield._visible_cells = {Vector2i(4, 4): true, Vector2i(79, 79): true}
	battlefield._explored_cells = {Vector2i(4, 4): true, Vector2i(4, 5): true, Vector2i(10, 10): true}
	battlefield._fog_visibility_revision += 1
	_assert_minimap_markers(minimap, failures)
	_assert_minimap_fog(minimap, failures)
	_expect(not minimap._refresh_fog_overlay(), "unchanged minimap fog was repainted", failures)
	battlefield._visible_cells.clear()
	battlefield._fog_visibility_revision += 1
	_assert_minimap_fog(minimap, failures)
	# A replacement view can have the same revision number and different fog.
	var replacement := Battlefield.new()
	replacement.simulation = simulation
	replacement._fog_visibility_revision = battlefield._fog_visibility_revision
	replacement._visible_cells = {Vector2i.ZERO: true}
	minimap.set_battlefield(replacement)
	_assert_minimap_fog(minimap, failures)
	simulation.entities.clear()
	_assert_minimap_markers(minimap, failures)
	minimap.free()
	replacement.free()
	battlefield.free()


func _assert_minimap_markers(minimap: BattlefieldMinimap, failures: Array[String]) -> void:
	var expected := Image.create(minimap._image_size().x, minimap._image_size().y, false, Image.FORMAT_RGBA8)
	expected.fill(Color.TRANSPARENT)
	# Reference paints directly from entities, without the cached command stream.
	for entity: Dictionary in minimap.battlefield.simulation.entities.values():
		if int(entity.get("garrisoned_in", -1)) >= 0 or not minimap.battlefield.should_render_entity(entity):
			continue
		var cell := Vector2i((entity["position"] as Vector2).floor())
		var category := entity.get("category") as StringName
		var team := int(entity.get("team", -1))
		var color := BattlefieldMinimap.TREE_COLOR if entity.get("resource_kind") == &"lumber" else BattlefieldMinimap.RESOURCE_COLOR
		match entity.get("kind"):
			&"yaoguai_den": color = BattlefieldMinimap.CAVE_COLOR
			&"shenlong": color = BattlefieldMinimap.SHENLONG_COLOR
			&"shenlong_egg": color = BattlefieldMinimap.EGG_COLOR
			&"jadeclaw":
				if team == -1:
					color = BattlefieldMinimap.MONSTER_COLOR
		if category == &"wildlife":
			color = BattlefieldMinimap.WILDLIFE_COLOR
		if team >= 0:
			color = [BattlefieldMinimap.PLAYER_COLOR, BattlefieldMinimap.ENEMY_COLOR, BattlefieldMinimap.RIVAL_TWO_COLOR, BattlefieldMinimap.RIVAL_THREE_COLOR][team]
		if category == &"structure":
			for footprint_cell in MapCatalog.footprint_cells(cell, entity.get("footprint", Vector2i.ONE)):
				_reference_minimap_pixel(expected, footprint_cell, color)
		elif category in [&"unit", &"wildlife", &"objective"]:
			for y in range(cell.y - 1, cell.y + 2):
				for x in range(cell.x - 1, cell.x + 2):
					_reference_minimap_pixel(expected, Vector2i(x, y), color)
		else:
			_reference_minimap_pixel(expected, cell, color)
	minimap._refresh_entity_overlay()
	_expect(minimap._entity_image.get_data() == expected.get_data(), "cached minimap markers differ from original pixel painter", failures)


func _assert_minimap_fog(minimap: BattlefieldMinimap, failures: Array[String]) -> void:
	var expected := Image.create(minimap._image_size().x, minimap._image_size().y, false, Image.FORMAT_RGBA8)
	expected.fill(Color.TRANSPARENT)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			if minimap.battlefield.is_cell_visible(cell):
				continue
			var color := Color(0.015, 0.045, 0.05, 0.55) if minimap.battlefield.is_cell_explored(cell) else Color(0.0, 0.012, 0.016, 0.94)
			_reference_minimap_pixel(expected, cell, color)
	minimap._refresh_fog_overlay()
	_expect(minimap._fog_image.get_data() == expected.get_data(), "cached minimap fog differs from original pixel painter", failures)


func _reference_minimap_pixel(image: Image, cell: Vector2i, color: Color) -> void:
	if MapCatalog.in_bounds(cell):
		image.set_pixel(cell.x - cell.y + MapCatalog.SIZE.y - 1, floori(float(cell.x + cell.y) * 0.5), color)


func _test_presentation(failures: Array[String]) -> void:
	var presentation := PresentationState.new()
	var entities := {1: {"id": 1, "hp": 80.0}, 2: {"id": 2, "hp": 60.0}, 3: {"id": 3, "hp": 300.0}}
	presentation.synchronize(entities)
	_expect(presentation._active_records.is_empty(), "settled entities entered the animation update set", failures)
	presentation.consume_event({"type": &"attack", "attacker_id": 1, "target_id": 2, "from": Vector2.ZERO, "to": Vector2(1, 1)})
	presentation.set_hover(1)
	presentation.note_selection([2])
	entities[2]["hp"] = 30.0
	presentation.synchronize(entities)
	var reference: Dictionary = presentation.records.duplicate(true)
	for delta in [0.0, 0.016, 0.041, 0.1, 0.016, 0.4, 0.75]:
		for record: Dictionary in reference.values():
			# Original full-record update, including exact health interpolation.
			record["attack_elapsed"] = minf(PresentationState.ATTACK_DURATION, float(record["attack_elapsed"]) + delta)
			record["hit_elapsed"] = minf(PresentationState.HIT_DURATION, float(record["hit_elapsed"]) + delta)
			record["selection_elapsed"] = minf(1.0, float(record["selection_elapsed"]) + delta * 5.0)
			record["hover_elapsed"] = minf(1.0, float(record["hover_elapsed"]) + delta * 7.0)
			record["display_hp"] = lerpf(float(record["display_hp"]), float(record["target_hp"]), clampf(delta * PresentationState.HEALTH_SETTLE_SPEED, 0.0, 1.0))
		presentation.advance(delta)
		_expect(presentation.records == reference, "sparse presentation changed live animation/health values", failures)
	_expect(presentation._active_records.is_empty(), "finished animations remained in the active set", failures)
	entities[1]["alive"] = false
	presentation.synchronize(entities)
	_expect(not presentation.records.has(1), "dead entity retained presentation bookkeeping", failures)
	_expect(presentation.records.has(2) and presentation.records.has(3), "death cleanup removed a living presentation record", failures)
	entities.erase(2)
	presentation.synchronize(entities)
	_expect(not presentation.records.has(2), "removed entity retained presentation bookkeeping", failures)
	presentation.clear()
	_expect(presentation._active_records.is_empty() and presentation.records.is_empty(), "rematch retained presentation state", failures)


class PickingFixture extends Battlefield:
	var hit_ids: Array[int] = []
	var checked := 0

	func _entity_sprite_contains_screen_point(entity_state: Dictionary, _position: Vector2) -> bool:
		checked += 1
		return hit_ids.has(int(entity_state["id"]))


func _test_picking(failures: Array[String]) -> void:
	var battlefield := PickingFixture.new()
	battlefield.simulation = RtsSimulation.new()
	battlefield.fog_enabled = false
	for id in range(1, 6):
		battlefield.simulation.entities[id] = {"id": id, "alive": true, "category": &"unit", "kind": &"worker", "team": 0, "position": Vector2(3, 3)}
	var point := battlefield.entity_screen_position(battlefield.simulation.entities[1])
	battlefield.hit_ids = [2]
	_expect(battlefield.command_target_at_screen(point, false) == 2, "single sprite hit changed", failures)
	battlefield.hit_ids = []
	_expect(battlefield.command_target_at_screen(point, false) == -1, "empty silhouette hit unexpectedly used tile fallback", failures)
	battlefield.hit_ids = [1, 2, 4]
	battlefield.checked = 0
	_expect(battlefield.command_target_at_screen(point, false) == battlefield._tile_entity_at_screen(point, false), "ambiguous sprites changed tile-anchor fallback", failures)
	_expect(battlefield.checked == 2, "ambiguous picking continued redundant silhouette work", failures)
	battlefield.free()
