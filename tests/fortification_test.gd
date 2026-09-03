extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _find_wall_line(
	simulation: RtsSimulation,
	length: int,
	along_x: bool = true,
) -> Array[Vector2i]:
	var maximum_x := MapCatalog.SIZE.x - (length if along_x else 1) - 4
	var maximum_y := MapCatalog.SIZE.y - (1 if along_x else length) - 4
	for y in range(4, maximum_y):
		for x in range(4, maximum_x):
			var start := Vector2i(x, y)
			var finish := start + (Vector2i(length - 1, 0) if along_x else Vector2i(0, length - 1))
			if simulation.can_place_wall_line(RtsSimulation.TEAM_PLAYER, start, finish):
				return simulation.wall_line_cells(start, finish)
	return []


func _find_structure_site(
	simulation: RtsSimulation,
	kind: StringName,
	orientation: StringName = &"y",
) -> Vector2i:
	for y in range(5, MapCatalog.SIZE.y - 10):
		for x in range(5, MapCatalog.SIZE.x - 10):
			var cell := Vector2i(x, y)
			if simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, kind, cell, orientation):
				return cell
	return Vector2i(-1, -1)


func _find_non_grass_land_site(
	simulation: RtsSimulation,
	kind: StringName,
	orientation: StringName = &"y",
) -> Vector2i:
	var footprint := simulation.structure_footprint(
		RtsSimulation.TEAM_PLAYER,
		kind,
		orientation,
	)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var has_non_grass := false
			var all_walkable := true
			for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
				if not MapCatalog.is_static_walkable(footprint_cell):
					all_walkable = false
					break
				if MapCatalog.terrain_at(footprint_cell) != &"meadow":
					has_non_grass = true
			if (
				all_walkable
				and has_non_grass
				and simulation.can_place_structure(
					RtsSimulation.TEAM_PLAYER,
					kind,
					cell,
					orientation,
				)
			):
				return cell
	return Vector2i(-1, -1)


func _test_non_grass_land_placement(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var definitions := [
		[&"wall", &"y"],
		[&"gate", &"x"],
		[&"sentry_tower", &"y"],
	]
	var wall_site := Vector2i(-1, -1)
	for definition in definitions:
		var kind := definition[0] as StringName
		var orientation := definition[1] as StringName
		var site := _find_non_grass_land_site(simulation, kind, orientation)
		if site.x < 0:
			failures.append("%s had no valid empty non-grass land placement" % String(kind))
			continue
		if kind == &"wall":
			wall_site = site
		if not simulation.can_place_structure(
			RtsSimulation.TEAM_PLAYER,
			kind,
			site,
			orientation,
		):
			failures.append("%s rejected empty walkable non-grass terrain" % String(kind))
	if wall_site.x >= 0 and simulation.can_place_structure(
		RtsSimulation.TEAM_PLAYER,
		&"war_camp",
		wall_site,
	):
		failures.append("ordinary War Camp incorrectly inherited fortification terrain placement")
	var water_cell := Vector2i(-1, -1)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var candidate := Vector2i(x, y)
			if MapCatalog.terrain_at(candidate) == &"water":
				water_cell = candidate
				break
		if water_cell.x >= 0:
			break
	for kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS:
		if simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, kind, water_cell):
			failures.append("%s was allowed on non-walkable water" % String(kind))


func _test_footprints_and_wall_drag(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
	if simulation.structure_footprint(RtsSimulation.TEAM_PLAYER, &"wall") != Vector2i.ONE:
		failures.append("Wood Wall did not expose a 1x1 footprint")
	if simulation.structure_footprint(RtsSimulation.TEAM_PLAYER, &"sentry_tower") != Vector2i(2, 2):
		failures.append("Sentry Tower did not expose a 2x2 footprint")
	if simulation.structure_footprint(RtsSimulation.TEAM_PLAYER, &"gate", &"y") != Vector2i(2, 4):
		failures.append("vertical Wood Gate did not expose a 2x4 footprint")
	if simulation.structure_footprint(RtsSimulation.TEAM_PLAYER, &"gate", &"x") != Vector2i(4, 2):
		failures.append("horizontal Wood Gate did not rotate to a 4x2 footprint")
	var camp_site := _find_structure_site(simulation, &"war_camp", &"x")
	if camp_site.x < 0:
		failures.append("no rotated generic building test site was available")
	else:
		var camp_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"war_camp",
			camp_site,
			true,
			&"x",
		)
		if simulation.entity(camp_id).get("orientation") != &"x":
			failures.append("non-gate building orientation was not stored authoritatively")

	var snapped := simulation.wall_line_cells(Vector2i(10, 10), Vector2i(14, 12))
	if snapped.size() != 5 or snapped.back() != Vector2i(14, 10):
		failures.append("wall drag did not snap to its dominant linear axis")
	var cells := _find_wall_line(simulation, 5)
	if cells.is_empty():
		failures.append("no clear five-cell wall test site was available")
		return
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	var wall_ids := simulation.command_build_wall_line(
		RtsSimulation.TEAM_PLAYER,
		worker_id,
		cells.front(),
		cells.back(),
		&"x",
	)
	if wall_ids.size() != 5:
		failures.append("valid five-cell wall drag did not create five foundations")
	var expected_lumber := lumber_before - 5 * int(FactionCatalog.stats(&"wall", &"human")["lumber_cost"])
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != expected_lumber:
		failures.append("wall line did not charge exactly one Wood Wall cost per cell")
	for index in range(wall_ids.size()):
		var wall := simulation.entity(wall_ids[index])
		if (
			wall.get("kind") != &"wall"
			or wall.get("cell") != cells[index]
			or wall.get("footprint") != Vector2i.ONE
			or wall.get("orientation") != &"x"
		):
			failures.append("wall line foundation state diverged from its snapped cells")
			break
	var entity_count := simulation.entities.size()
	var lumber_after := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	if not simulation.command_build_wall_line(
		RtsSimulation.TEAM_PLAYER,
		worker_id,
		cells.front(),
		cells.back(),
	).is_empty():
		failures.append("blocked wall drag was not rejected atomically")
	if simulation.entities.size() != entity_count or int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_after:
		failures.append("rejected wall drag partially created foundations or spent Lumber")


func _test_wall_gate_corner_overlap(failures: Array[String]) -> void:
	for orientation in [&"y", &"x"]:
		var simulation := RtsSimulation.new()
		simulation.setup(&"human", false)
		simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
		var gate_cell := _find_structure_site(simulation, &"gate", orientation)
		if gate_cell.x < 0:
			failures.append("no %s gate overlap test site was available" % orientation)
			continue
		var gate_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"gate",
			gate_cell,
			true,
			orientation,
		)
		var gate := simulation.entity(gate_id)
		var footprint := gate.get("footprint", Vector2i.ONE) as Vector2i
		var corner_cells: Array[Vector2i] = [
			gate_cell,
			gate_cell + Vector2i(footprint.x - 1, 0),
			gate_cell + Vector2i(0, footprint.y - 1),
			gate_cell + footprint - Vector2i.ONE,
		]
		for corner_cell in corner_cells:
			if not simulation.can_place_structure(
				RtsSimulation.TEAM_PLAYER,
				&"wall",
				corner_cell,
			):
				failures.append("%s gate rejected an allied wall on corner %s" % [orientation, corner_cell])
		for footprint_cell in MapCatalog.footprint_cells(gate_cell, footprint):
			if (
				footprint_cell not in corner_cells
				and simulation.can_place_structure(
					RtsSimulation.TEAM_PLAYER,
					&"wall",
					footprint_cell,
				)
			):
				failures.append("%s gate accepted a wall on non-corner tile %s" % [orientation, footprint_cell])
		if simulation.can_place_structure(
			RtsSimulation.TEAM_ENEMY,
			&"wall",
			corner_cells[0],
		):
			failures.append("%s gate accepted an enemy wall on its corner" % orientation)
		if simulation.can_place_structure(
			RtsSimulation.TEAM_PLAYER,
			&"sentry_tower",
			corner_cells[0],
		):
			failures.append("%s gate incorrectly shared its corner with a Sentry Tower" % orientation)

		var worker_id := simulation.team_entity_ids(
			RtsSimulation.TEAM_PLAYER,
			[&"worker"],
		)[0]
		var wall_ids := simulation.command_build_wall_line(
			RtsSimulation.TEAM_PLAYER,
			worker_id,
			corner_cells[0],
			corner_cells[0],
			orientation,
		)
		if wall_ids.size() != 1:
			failures.append("%s gate corner wall could not be built" % orientation)
			continue
		if simulation.can_place_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			corner_cells[0],
		):
			failures.append("%s gate corner accepted a second overlapping wall" % orientation)

		var gate_only_cell := gate_cell + (
			Vector2i(0, 1) if footprint.y > footprint.x else Vector2i(1, 0)
		)
		simulation._set_friendly_structures_solid(RtsSimulation.TEAM_PLAYER, false)
		if not simulation._astar.is_point_solid(corner_cells[0]):
			failures.append("%s gate opening made its overlapping allied wall passable" % orientation)
		if simulation._astar.is_point_solid(gate_only_cell):
			failures.append("%s gate did not remain passable away from its corner wall" % orientation)
		simulation._set_friendly_structures_solid(RtsSimulation.TEAM_PLAYER, true)


func _test_gate_sprite_facing(failures: Array[String]) -> void:
	var battlefield := Battlefield.new()
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	battlefield.simulation = simulation
	for kind in [&"wall", &"gate"]:
		var reference_sign := 0.0
		for faction in FactionCatalog.ORDER:
			var texture := load(FactionCatalog.entity_art_path(faction, kind)) as Texture2D
			var source_slope := float(battlefield.call("_texture_ground_axis_slope", texture))
			var source_sign := signf(source_slope)
			if is_zero_approx(source_sign):
				failures.append("%s %s runtime sprite has no measurable default axis" % [faction, kind])
			elif is_zero_approx(reference_sign):
				reference_sign = source_sign
			elif source_sign != reference_sign:
				failures.append("%s %s runtime sprite has a different default facing" % [faction, kind])
	if bool(battlefield.call("_gate_sprite_flipped_for_footprint", Vector2i(4, 2))):
		failures.append("4x2 Wood Gate sprite was incorrectly mirrored after the 90-degree correction")
	if not bool(battlefield.call("_gate_sprite_flipped_for_footprint", Vector2i(2, 4))):
		failures.append("2x4 Wood Gate sprite did not turn onto its footprint axis")
	for faction in FactionCatalog.ORDER:
		var gate_texture := load(FactionCatalog.entity_art_path(faction, &"gate")) as Texture2D
		for orientation in [&"x", &"y"]:
			var footprint := simulation.structure_footprint(
				RtsSimulation.TEAM_PLAYER,
				&"gate",
				orientation,
			)
			var source_slope := float(battlefield.call("_texture_ground_axis_slope", gate_texture))
			var target_slope := float(battlefield.call(
				"_fortification_target_axis_slope",
				&"gate",
				orientation,
				footprint,
			))
			var corrected_flip := bool(battlefield.call(
				"_structure_sprite_flipped",
				&"gate",
				orientation,
				footprint,
				gate_texture,
			))
			var display_size := battlefield.call(
				"_structure_display_size",
				&"gate",
				footprint,
				gate_texture,
			) as Vector2
			var content_rect := battlefield.call("_texture_content_rect", gate_texture) as Rect2i
			var visible_content_width := (
				float(content_rect.size.x)
				* display_size.x
				/ float(gate_texture.get_width())
			)
			var expected_content_width := (
				float(maxi(footprint.x, footprint.y))
				* IsoProjection.TILE_WIDTH
				* 0.5
				* float(battlefield.call("_gate_sprite_scale", gate_texture))
			)
			if not is_equal_approx(visible_content_width, expected_content_width):
				failures.append("%s gate %s sprite did not include its configured seam overlap" % [faction, orientation])
			var axis_offset := battlefield.call(
				"_gate_sprite_axis_anchor_offset",
				orientation,
				gate_texture,
				display_size,
			) as Vector2
			var expected_anchor_ratio := float(battlefield.call(
				"_gate_sprite_anchor_ratio",
				gate_texture,
			))
			var expected_offset_x := (
				-expected_content_width * expected_anchor_ratio
				if orientation == &"x"
				else expected_content_width * expected_anchor_ratio
			)
			if not is_equal_approx(axis_offset.x, expected_offset_x):
				failures.append("%s gate %s sprite was not centered on its front long tile edge" % [faction, orientation])
			var axis_skew := float(battlefield.call(
				"_structure_sprite_axis_skew",
				&"gate",
				orientation,
				footprint,
				gate_texture,
				display_size,
				corrected_flip,
			))
			var source_scale_x := display_size.x / float(gate_texture.get_width())
			var source_scale_y := display_size.y / float(gate_texture.get_height())
			var scaled_source_slope := source_slope * source_scale_y / source_scale_x
			var horizontal_scale := -1.0 if corrected_flip else 1.0
			var displayed_slope := (scaled_source_slope + axis_skew) / horizontal_scale
			var expected_slope := (
				IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH
				if orientation == &"x"
				else -IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH
			)
			if not is_equal_approx(target_slope, expected_slope):
				failures.append("%s gate %s target did not match the exact tile axis" % [faction, orientation])
			if not is_equal_approx(displayed_slope, expected_slope):
				failures.append("%s gate sprite did not align exactly to its rotated %s tile axis" % [faction, orientation])
			var previous_flip := source_slope * -target_slope < 0.0
			if not is_zero_approx(source_slope) and corrected_flip == previous_flip:
				failures.append("%s gate sprite did not swap its previous %s facing" % [faction, orientation])
	if bool(battlefield.call("_structure_sprite_flipped", &"wall", &"y", Vector2i.ONE)):
		failures.append("default Wood Wall art was unexpectedly mirrored")
	if not bool(battlefield.call("_structure_sprite_flipped", &"wall", &"x", Vector2i.ONE)):
		failures.append("rotated Wood Wall art was not mirrored onto its alternate isometric axis")
	var nominal_wall_horizontal_span := IsoProjection.TILE_WIDTH * 0.5
	var expected_wall_horizontal_span := (
		nominal_wall_horizontal_span * Battlefield.WALL_SPRITE_SCALE
	)
	var expected_wall_axis_length := Vector2(
		expected_wall_horizontal_span,
		expected_wall_horizontal_span * IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH,
	).length()
	for faction in FactionCatalog.ORDER:
		var wall_texture := load(FactionCatalog.entity_art_path(faction, &"wall")) as Texture2D
		var content_rect := battlefield.call("_texture_content_rect", wall_texture) as Rect2i
		var display_size := battlefield.call(
			"_structure_display_size",
			&"wall",
			Vector2i.ONE,
			wall_texture,
		) as Vector2
		var displayed_horizontal_span := (
			float(content_rect.size.x)
			* display_size.x
			/ float(wall_texture.get_width())
		)
		if not is_equal_approx(displayed_horizontal_span, expected_wall_horizontal_span):
			failures.append(
				"%s wall spans %.3f px horizontally instead of one %.3f px tile edge"
				% [faction, displayed_horizontal_span, expected_wall_horizontal_span]
			)
		for orientation in [&"x", &"y"]:
			var axis_offset := battlefield.call(
				"_wall_sprite_axis_anchor_offset",
				orientation,
			) as Vector2
			var expected_offset_x := (
				-nominal_wall_horizontal_span * 0.5
				if orientation == &"x"
				else nominal_wall_horizontal_span * 0.5
			)
			if not is_equal_approx(axis_offset.x, expected_offset_x):
				failures.append(
					"%s wall %s was not centered toward its tile edge"
					% [faction, orientation]
				)
			var target_slope := float(battlefield.call(
				"_fortification_target_axis_slope",
				&"wall",
				orientation,
				Vector2i.ONE,
			))
			var corrected_flip := bool(battlefield.call(
				"_structure_sprite_flipped",
				&"wall",
				orientation,
				Vector2i.ONE,
				wall_texture,
			))
			var axis_skew := float(battlefield.call(
				"_structure_sprite_axis_skew",
				&"wall",
				orientation,
				Vector2i.ONE,
				wall_texture,
				display_size,
				corrected_flip,
			))
			var source_slope := float(battlefield.call(
				"_texture_ground_axis_slope",
				wall_texture,
			))
			var source_scale_x := display_size.x / float(wall_texture.get_width())
			var source_scale_y := display_size.y / float(wall_texture.get_height())
			var scaled_source_slope := source_slope * source_scale_y / source_scale_x
			var horizontal_scale := -1.0 if corrected_flip else 1.0
			var displayed_slope := (scaled_source_slope + axis_skew) / horizontal_scale
			var displayed_axis_length := Vector2(
				displayed_horizontal_span,
				displayed_horizontal_span * displayed_slope,
			).length()
			if not is_equal_approx(displayed_slope, target_slope):
				failures.append(
					"%s wall %s sprite did not align exactly to its tile edge"
					% [faction, orientation]
				)
			if not is_equal_approx(displayed_axis_length, expected_wall_axis_length):
				failures.append(
					"%s wall %s length %.3f px did not equal the %.3f px tile edge"
					% [faction, orientation, displayed_axis_length, expected_wall_axis_length]
				)
	battlefield.placement_kind = &"wall"
	if battlefield.call(
		"_automatic_drag_orientation",
		Vector2i(10, 10),
		Vector2i(12, 12),
	) != &"x":
		failures.append("diagonal wall drag orientation diverged from its map-X snap tie-break")
	battlefield.free()


func _test_wall_corner_topology(failures: Array[String]) -> void:
	var battlefield := Battlefield.new()
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	battlefield.simulation = simulation
	var corner_definitions := [
		{"name": "top", "directions": [&"bottom_left", &"bottom_right"]},
		{"name": "bottom", "directions": [&"top_left", &"top_right"]},
		{"name": "left", "directions": [&"top_right", &"bottom_right"]},
		{"name": "right", "directions": [&"top_left", &"bottom_left"]},
		{
			"name": "T-junction",
			"directions": [&"top_left", &"top_right", &"bottom_left"],
		},
		{
			"name": "crossing",
			"directions": [
				&"top_left",
				&"top_right",
				&"bottom_left",
				&"bottom_right",
			],
		},
	]
	var first_corner_neighbor_ids: Array[int] = []
	var first_corner_center_id := -1
	for definition_index in range(corner_definitions.size()):
		var definition := corner_definitions[definition_index] as Dictionary
		var center_cell := Vector2i(-100 - definition_index * 10, -100)
		var center_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			center_cell,
			true,
			&"x",
		)
		if definition_index == 0:
			first_corner_center_id = center_id
		for raw_direction in definition["directions"]:
			var direction := raw_direction as StringName
			var neighbor_orientation := battlefield.call(
				"_wall_corner_direction_orientation",
				direction,
			) as StringName
			var neighbor_id := simulation._spawn_structure(
				RtsSimulation.TEAM_PLAYER,
				&"wall",
				center_cell + Battlefield.WALL_CORNER_NEIGHBOR_OFFSETS[direction],
				true,
				neighbor_orientation,
			)
			if definition_index == 0:
				first_corner_neighbor_ids.append(neighbor_id)
		battlefield.call("_rebuild_wall_render_lookup")
		var actual := battlefield.call(
			"_wall_corner_directions",
			simulation.entity(center_id),
		) as Array
		var expected := definition["directions"] as Array
		if actual != expected:
			failures.append(
				"%s wall corner resolved %s instead of %s"
				% [definition["name"], actual, expected]
			)

	# Parallel opposite neighbors are a straight run, not a corner.
	var straight_cell := Vector2i(-200, -100)
	var straight_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		straight_cell,
		true,
		&"x",
	)
	for direction in [&"top_left", &"bottom_right"]:
		simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			straight_cell + Battlefield.WALL_CORNER_NEIGHBOR_OFFSETS[direction],
			true,
			&"x",
		)
	battlefield.call("_rebuild_wall_render_lookup")
	if not (battlefield.call(
		"_wall_corner_directions",
		simulation.entity(straight_id),
	) as Array).is_empty():
		failures.append("straight wall run was incorrectly rendered as a corner")

	# Foundations and enemy walls must not visually connect to a completed ally.
	var pending_cell := Vector2i(-220, -100)
	var pending_center_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		pending_cell,
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		pending_cell + Vector2i(-1, 0),
		true,
		&"x",
	)
	var pending_neighbor_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		pending_cell + Vector2i(0, -1),
		false,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if not (battlefield.call(
		"_wall_corner_directions",
		simulation.entity(pending_center_id),
	) as Array).is_empty():
		failures.append("unfinished neighboring wall formed a completed corner")
	simulation.entity(pending_neighbor_id)["complete"] = 1.0
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_corner_directions",
		simulation.entity(pending_center_id),
	) as Array) != [&"top_left", &"top_right"]:
		failures.append("corner did not appear when its neighboring wall completed")

	var contested_cell := Vector2i(-240, -100)
	var contested_center_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		contested_cell,
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		contested_cell + Vector2i(-1, 0),
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"wall",
		contested_cell + Vector2i(0, -1),
		true,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if not (battlefield.call(
		"_wall_corner_directions",
		simulation.entity(contested_center_id),
	) as Array).is_empty():
		failures.append("enemy wall incorrectly completed an allied wall corner")

	# Removing either axis must remove the derived corner on the next draw lookup.
	simulation.entity(first_corner_neighbor_ids[1])["alive"] = false
	battlefield.call("_rebuild_wall_render_lookup")
	var first_center := simulation.entity(first_corner_center_id)
	if not (battlefield.call("_wall_corner_directions", first_center) as Array).is_empty():
		failures.append("destroyed neighboring wall left a stale corner sprite")

	var bottom_left_offset := battlefield.call(
		"_wall_corner_direction_anchor_offset",
		&"bottom_left",
	) as Vector2
	var bottom_right_offset := battlefield.call(
		"_wall_corner_direction_anchor_offset",
		&"bottom_right",
	) as Vector2
	if bottom_left_offset != -IsoProjection.project(Vector2(1.0, 0.0)):
		failures.append("upper-left corner arm did not move flush onto its tile edge")
	if bottom_right_offset != -IsoProjection.project(Vector2(0.0, 1.0)):
		failures.append("upper-right corner arm did not move flush onto its tile edge")
	battlefield.free()


func _test_wall_joint_topology(failures: Array[String]) -> void:
	var battlefield := Battlefield.new()
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	battlefield.simulation = simulation
	var turn_cases := [
		{
			"name": "north",
			"y_offset": Vector2i(0, -1),
			"x_render": [&"x", &"y"],
			"y_render": [&"y"],
		},
		{
			"name": "south",
			"y_offset": Vector2i(0, 1),
			"x_render": [&"x"],
			"y_render": [&"y"],
		},
		{
			"name": "west",
			"y_offset": Vector2i(-1, 0),
			"x_render": [&"x"],
			"y_render": [&"y"],
		},
		{
			"name": "east",
			"y_offset": Vector2i(1, 0),
			"x_render": [&"x"],
			"y_render": [&"y", &"x"],
		},
	]
	for case_index in range(turn_cases.size()):
		var turn_case := turn_cases[case_index] as Dictionary
		var base_cell := Vector2i(-300 - case_index * 10, -200)
		var x_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			base_cell,
			true,
			&"x",
		)
		var y_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			base_cell + (turn_case["y_offset"] as Vector2i),
			true,
			&"y",
		)
		battlefield.call("_rebuild_wall_render_lookup")
		var x_render := battlefield.call(
			"_wall_render_orientations",
			simulation.entity(x_id),
		) as Array
		var y_render := battlefield.call(
			"_wall_render_orientations",
			simulation.entity(y_id),
		) as Array
		if x_render != (turn_case["x_render"] as Array):
			failures.append(
				"%s turn X wall rendered %s instead of %s"
				% [turn_case["name"], x_render, turn_case["x_render"]]
			)
		if y_render != (turn_case["y_render"] as Array):
			failures.append(
				"%s turn Y wall rendered %s instead of %s"
				% [turn_case["name"], y_render, turn_case["y_render"]]
			)
		if x_render.size() + y_render.size() > 3:
			failures.append("%s turn produced more than one connector sprite" % turn_case["name"])

	var pending_cell := Vector2i(-360, -200)
	var pending_x_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		pending_cell,
		true,
		&"x",
	)
	var pending_y_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		pending_cell + Vector2i(0, -1),
		false,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(pending_x_id),
	) as Array) != [&"x"]:
		failures.append("unfinished wall created a connector sprite")
	simulation.entity(pending_y_id)["complete"] = 1.0
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(pending_x_id),
	) as Array) != [&"x", &"y"]:
		failures.append("completed wall did not create its missing connector")
	simulation.entity(pending_y_id)["alive"] = false
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(pending_x_id),
	) as Array) != [&"x"]:
		failures.append("destroyed wall left a stray connector sprite")

	var enemy_cell := Vector2i(-380, -200)
	var allied_x_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		enemy_cell,
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"wall",
		enemy_cell + Vector2i(0, -1),
		true,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(allied_x_id),
	) as Array) != [&"x"]:
		failures.append("enemy wall created a stray allied connector sprite")
	battlefield.free()


func _test_wall_corner_segment_ownership(failures: Array[String]) -> void:
	var battlefield := Battlefield.new()
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	battlefield.simulation = simulation
	var corner_cases := [
		{
			"name": "top",
			"x_neighbor": Vector2i(1, 0),
			"y_neighbor": Vector2i(0, 1),
			"expected": [],
		},
		{
			"name": "right",
			"x_neighbor": Vector2i(-1, 0),
			"y_neighbor": Vector2i(0, 1),
			"expected": [&"x"],
		},
		{
			"name": "left",
			"x_neighbor": Vector2i(1, 0),
			"y_neighbor": Vector2i(0, -1),
			"expected": [&"y"],
		},
		{
			"name": "bottom",
			"x_neighbor": Vector2i(-1, 0),
			"y_neighbor": Vector2i(0, -1),
			"expected": [&"x", &"y"],
		},
	]
	for case_index in range(corner_cases.size()):
		var corner_case := corner_cases[case_index] as Dictionary
		var center_cell := Vector2i(-420 - case_index * 10, -240)
		var center_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			center_cell,
			true,
			&"x",
		)
		simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			center_cell + (corner_case["x_neighbor"] as Vector2i),
			true,
			&"x",
		)
		simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"wall",
			center_cell + (corner_case["y_neighbor"] as Vector2i),
			true,
			&"y",
		)
		battlefield.call("_rebuild_wall_render_lookup")
		var actual := battlefield.call(
			"_wall_render_orientations",
			simulation.entity(center_id),
		) as Array
		if actual != (corner_case["expected"] as Array):
			failures.append(
				"%s corner owned %s wall segments instead of %s"
				% [corner_case["name"], actual, corner_case["expected"]]
			)

	var lifecycle_cell := Vector2i(-480, -240)
	var lifecycle_center_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		lifecycle_cell,
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		lifecycle_cell + Vector2i(-1, 0),
		true,
		&"x",
	)
	var lifecycle_y_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		lifecycle_cell + Vector2i(0, -1),
		false,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(lifecycle_center_id),
	) as Array) != [&"x"]:
		failures.append("unfinished neighbor suppressed or extended a wall corner")
	simulation.entity(lifecycle_y_id)["complete"] = 1.0
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(lifecycle_center_id),
	) as Array) != [&"x", &"y"]:
		failures.append("completed bottom corner did not own both required segments")
	simulation.entity(lifecycle_y_id)["alive"] = false
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(lifecycle_center_id),
	) as Array) != [&"x"]:
		failures.append("destroyed neighbor left a jutting wall segment")

	var enemy_cell := Vector2i(-500, -240)
	var enemy_center_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		enemy_cell,
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"wall",
		enemy_cell + Vector2i(-1, 0),
		true,
		&"x",
	)
	simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"wall",
		enemy_cell + Vector2i(0, -1),
		true,
		&"y",
	)
	battlefield.call("_rebuild_wall_render_lookup")
	if (battlefield.call(
		"_wall_render_orientations",
		simulation.entity(enemy_center_id),
	) as Array) != [&"x"]:
		failures.append("enemy neighbor suppressed or extended an allied corner")
	battlefield.free()


func _test_gate_pathing(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var gate_cell := _find_structure_site(simulation, &"gate")
	if gate_cell.x < 0:
		failures.append("fortification pathing sites were unavailable")
		return
	var gate_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"gate", gate_cell, true)
	var wall_cell := _find_structure_site(simulation, &"wall")
	if wall_cell.x < 0:
		failures.append("fortification pathing sites were unavailable")
		return
	var wall_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"wall", wall_cell, true)
	simulation._rebuild_pathfinding()
	simulation._set_friendly_structures_solid(RtsSimulation.TEAM_PLAYER, false)
	if simulation._astar.is_point_solid(gate_cell):
		failures.append("friendly Wood Gate did not open for owner pathfinding")
	if not simulation._astar.is_point_solid(wall_cell):
		failures.append("friendly Wood Wall became passable during owner pathfinding")
	simulation._set_friendly_structures_solid(RtsSimulation.TEAM_PLAYER, true)
	if not simulation._astar.is_point_solid(gate_cell):
		failures.append("Wood Gate did not restore collision for rival pathfinding")
	if simulation.entity(gate_id).get("footprint") != Vector2i(2, 4) or simulation.entity(wall_id).get("footprint") != Vector2i.ONE:
		failures.append("spawned gate or wall footprint was incorrect")


func _test_drag_placement_input(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
	var wall_cells := _find_wall_line(simulation, 4)
	if wall_cells.is_empty():
		failures.append("no wall input test site was available")
		return
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	battlefield.set_fog_enabled(false)
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([worker_id])
	battlefield.begin_structure_placement(&"wall")
	var start_screen := battlefield.camera_offset + IsoProjection.cell_center(wall_cells.front()) * battlefield.camera_scale
	var finish_screen := battlefield.camera_offset + IsoProjection.cell_center(wall_cells.back()) * battlefield.camera_scale
	var entities_before := simulation.entities.size()
	battlefield.call("_handle_left_press", start_screen)
	battlefield.placement_orientation = battlefield.call(
		"_automatic_drag_orientation",
		wall_cells.front(),
		wall_cells.back(),
	) as StringName
	var expected_preview_flip := bool(battlefield.call(
		"_structure_sprite_flipped",
		&"wall",
		battlefield.placement_orientation,
		Vector2i.ONE,
	))
	battlefield.call("_handle_left_release", finish_screen)
	if simulation.entities.size() != entities_before + 4:
		failures.append("battlefield wall drag-and-drop did not commit its snapped four-cell line")
	for cell in wall_cells:
		var found_wall := false
		for raw_entity in simulation.entities.values():
			var entity_state := raw_entity as Dictionary
			if entity_state.get("kind") == &"wall" and entity_state.get("cell") == cell:
				found_wall = true
				if entity_state.get("orientation") != &"x":
					failures.append("map-X wall drag did not use the swapped wall facing")
				var foundation_flip := bool(battlefield.call(
					"_structure_sprite_flipped",
					&"wall",
					entity_state.get("orientation", &"y") as StringName,
					entity_state.get("footprint", Vector2i.ONE) as Vector2i,
				))
				entity_state["complete"] = 1.0
				var completed_flip := bool(battlefield.call(
					"_structure_sprite_flipped",
					&"wall",
					entity_state.get("orientation", &"y") as StringName,
					entity_state.get("footprint", Vector2i.ONE) as Vector2i,
				))
				if foundation_flip != expected_preview_flip or completed_flip != expected_preview_flip:
					failures.append("wall preview, foundation, and completed sprite orientations diverged")
				break
		if not found_wall:
			failures.append("wall drag omitted a snapped map-X cell")
	if battlefield.placement_kind != &"wall" or battlefield.placement_worker_id != worker_id:
		failures.append("successful wall drag did not preserve rapid placement mode")

	var cross_axis_cells := _find_wall_line(simulation, 3, false)
	if cross_axis_cells.is_empty():
		failures.append("no alternate-axis wall input test site was available")
	else:
		start_screen = battlefield.camera_offset + IsoProjection.cell_center(cross_axis_cells.front()) * battlefield.camera_scale
		finish_screen = battlefield.camera_offset + IsoProjection.cell_center(cross_axis_cells.back()) * battlefield.camera_scale
		battlefield.call("_handle_left_press", start_screen)
		battlefield.call("_handle_left_release", finish_screen)
		for cell in cross_axis_cells:
			for raw_entity in simulation.entities.values():
				var entity_state := raw_entity as Dictionary
				if entity_state.get("kind") == &"wall" and entity_state.get("cell") == cell:
					if entity_state.get("orientation") != &"y":
						failures.append("alternate-axis wall drag did not rotate its tile and sprite state")
					break

	battlefield.placement_orientation = &"y"
	if not battlefield.rotate_structure_placement() or battlefield.placement_orientation != &"x":
		failures.append("R-facing placement API did not rotate an armed Wood Wall by 90 degrees")
	battlefield.cancel_modes()

	var farm_site := _find_structure_site(simulation, &"rice_farm", &"x")
	if farm_site.x < 0:
		failures.append("no rotated generic building input test site was available")
	else:
		battlefield.select_entities([worker_id])
		battlefield.begin_structure_placement(&"rice_farm")
		battlefield.rotate_structure_placement()
		var farm_screen := battlefield.camera_offset + IsoProjection.cell_center(farm_site) * battlefield.camera_scale
		battlefield.call("_handle_left_press", farm_screen)
		battlefield.call("_handle_left_release", farm_screen)
		var farm_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"rice_farm")
		if farm_id < 0 or simulation.entity(farm_id).get("orientation") != &"x":
			failures.append("rotated generic building placement did not commit its sprite/tile direction")
		battlefield.cancel_modes()

	var gate_site := _find_structure_site(simulation, &"gate", &"x")
	if gate_site.x < 0:
		failures.append("no horizontal gate input test site was available")
		battlefield.queue_free()
		return
	battlefield.select_entities([worker_id])
	battlefield.begin_structure_placement(&"gate")
	start_screen = battlefield.camera_offset + IsoProjection.cell_center(gate_site) * battlefield.camera_scale
	finish_screen = battlefield.camera_offset + IsoProjection.cell_center(gate_site + Vector2i(3, 0)) * battlefield.camera_scale
	battlefield.call("_handle_left_press", start_screen)
	battlefield.placement_orientation = battlefield.call(
		"_automatic_drag_orientation",
		gate_site,
		gate_site + Vector2i(3, 0),
	) as StringName
	var gate_footprint := simulation.structure_footprint(
		RtsSimulation.TEAM_PLAYER,
		&"gate",
		battlefield.placement_orientation,
	)
	var gate_texture := load(FactionCatalog.entity_art_path(&"human", &"gate")) as Texture2D
	var expected_gate_preview_flip := bool(battlefield.call(
		"_structure_sprite_flipped",
		&"gate",
		battlefield.placement_orientation,
		gate_footprint,
		gate_texture,
	))
	battlefield.call("_handle_left_release", finish_screen)
	var gate_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"gate")
	if gate_id < 0 or simulation.entity(gate_id).get("orientation") != &"x" or simulation.entity(gate_id).get("footprint") != Vector2i(4, 2):
		failures.append("horizontal gate drag did not create a rotated 4x2 foundation")
	elif expected_gate_preview_flip:
		failures.append("rotated 4x2 gate designation incorrectly previewed the map-Y facing")
	else:
		var gate := simulation.entity(gate_id)
		var foundation_flip := bool(battlefield.call(
			"_structure_sprite_flipped",
			&"gate",
			gate.get("orientation", &"y") as StringName,
			gate.get("footprint", Vector2i.ONE) as Vector2i,
			gate_texture,
		))
		gate["complete"] = 1.0
		var completed_flip := bool(battlefield.call(
			"_structure_sprite_flipped",
			&"gate",
			gate.get("orientation", &"y") as StringName,
			gate.get("footprint", Vector2i.ONE) as Vector2i,
			gate_texture,
		))
		if foundation_flip != expected_gate_preview_flip or completed_flip != expected_gate_preview_flip:
			failures.append("gate preview, foundation, and completed sprite orientations diverged")
	battlefield.queue_free()


func _test_tower_garrison(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var tower_cell := _find_structure_site(simulation, &"sentry_tower")
	if tower_cell.x < 0:
		failures.append("no Sentry Tower test site was available")
		return
	var tower_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"sentry_tower", tower_cell, true)
	simulation._rebuild_pathfinding()
	var hunter_cell := simulation._nearest_walkable_around(tower_cell, 4)
	var hunter_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"hunter", hunter_cell)
	var mystic_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"mystic", hunter_cell)
	var overflow_hunter_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"hunter", hunter_cell)
	var vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", hunter_cell)
	if simulation.command_garrison(RtsSimulation.TEAM_PLAYER, [vanguard_id], tower_id):
		failures.append("non-ranged Vanguard was allowed to garrison a Sentry Tower")
	if not simulation.command_garrison(
		RtsSimulation.TEAM_PLAYER,
		[hunter_id, mystic_id, overflow_hunter_id],
		tower_id,
	):
		failures.append("two-unit ranged garrison command was rejected")
		return
	var hunter := simulation.entity(hunter_id)
	var mystic := simulation.entity(mystic_id)
	for occupant in [hunter, mystic]:
		occupant["position"] = Vector2(hunter_cell)
		occupant["cell"] = hunter_cell
		simulation._advance_garrison_order(occupant)
	if int(hunter.get("garrisoned_in", -1)) != tower_id or hunter.get("order") != &"garrisoned":
		failures.append("Hunter did not become static inside the tower")
		return
	if int(mystic.get("garrisoned_in", -1)) != tower_id or mystic.get("order") != &"garrisoned":
		failures.append("Mystic did not become static in the tower's second slot")
		return
	var tower := simulation.entity(tower_id)
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	if int(tower.get("garrison_capacity", 0)) != 2:
		failures.append("Sentry Tower did not expose a two-unit garrison capacity")
	if occupants.size() != 2 or hunter_id not in occupants or mystic_id not in occupants:
		failures.append("tower did not authoritatively record both ranged occupants")
	if simulation.command_garrison(RtsSimulation.TEAM_PLAYER, [overflow_hunter_id], tower_id):
		failures.append("full Sentry Tower accepted a third ranged occupant")

	var enemy_cell := Vector2i(-1, -1)
	for radius in range(6, 9):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
			var candidate: Vector2i = Vector2i(simulation.entity_center(tower_id).round()) + (offset as Vector2i)
			var candidate_target := {
				"id": -999,
				"position": Vector2(candidate),
				"footprint": Vector2i.ONE,
			}
			if (
				MapCatalog.in_bounds(candidate)
				and not simulation._astar.is_point_solid(candidate)
				and simulation._has_line_of_sight(hunter, candidate_target, [tower_id])
			):
				enemy_cell = candidate
				break
		if enemy_cell.x >= 0:
			break
	if enemy_cell.x < 0:
		failures.append("no double-range tower target site was available")
		return
	var enemy_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", enemy_cell)
	var enemy := simulation.entity(enemy_id)
	simulation._refresh_visibility()
	var normal_range := float(hunter["range"])
	if simulation._combat_distance(hunter, enemy) <= normal_range:
		failures.append("tower target was not outside the Hunter's normal range")
	var hp_before := float(enemy["hp"])
	hunter["target_id"] = enemy_id
	simulation._advance_garrisoned_combat(hunter)
	var damage_dealt := hp_before - float(enemy["hp"])
	if not is_equal_approx(damage_dealt, float(hunter["damage"])):
		failures.append(
			"garrisoned Hunter did not deal unchanged base damage at double range (damage %.1f, distance %.1f, visible %s, LoS %s)"
			% [
				damage_dealt,
				simulation._combat_distance(hunter, enemy),
				simulation.is_entity_visible_to_team(RtsSimulation.TEAM_PLAYER, enemy),
				simulation._has_line_of_sight(hunter, enemy, [tower_id]),
			],
		)
	if not simulation.command_ungarrison(RtsSimulation.TEAM_PLAYER, tower_id, hunter_id):
		failures.append("tower HUD ungarrison command contract was rejected")
	elif int(hunter.get("garrisoned_in", -1)) >= 0 or hunter.get("order") != &"idle":
		failures.append("ungarrisoned Hunter did not return to an idle ground state")
	elif simulation._astar.is_point_solid(hunter["cell"] as Vector2i):
		failures.append("ungarrisoned Hunter appeared on a blocked tower cell")

	simulation.command_garrison(RtsSimulation.TEAM_PLAYER, [hunter_id], tower_id)
	hunter["position"] = Vector2(hunter_cell)
	hunter["cell"] = hunter_cell
	simulation._advance_garrison_order(hunter)
	simulation._kill(tower, enemy)
	if (
		int(hunter.get("garrisoned_in", -1)) >= 0
		or int(mystic.get("garrisoned_in", -1)) >= 0
		or not bool(hunter.get("alive", false))
		or not bool(mystic.get("alive", false))
	):
		failures.append("destroyed tower did not safely eject both surviving occupants")


func _run() -> void:
	var failures: Array[String] = []
	_test_non_grass_land_placement(failures)
	_test_footprints_and_wall_drag(failures)
	_test_wall_gate_corner_overlap(failures)
	_test_gate_sprite_facing(failures)
	_test_wall_corner_segment_ownership(failures)
	_test_gate_pathing(failures)
	_test_drag_placement_input(failures)
	_test_tower_garrison(failures)
	if failures.is_empty():
		print("PASS fortification_test: terrain, rotation, wall snapping, gate-corner overlap, corners, footprints, gates, garrison combat and ejection")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
