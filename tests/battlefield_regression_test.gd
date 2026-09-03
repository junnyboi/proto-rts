extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	root.add_child(battlefield)
	battlefield.set_simulation(simulation)
	battlefield.set_fog_enabled(false)
	await process_frame
	for faction in FactionCatalog.ORDER:
		for kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS:
			var texture: Texture2D = battlefield.call("_entity_texture", faction, kind)
			var authored_footprint := FactionCatalog.stats(kind, faction).get("footprint", Vector2i.ONE) as Vector2i
			var content_rect: Rect2i = battlefield.call("_texture_content_rect", texture)
			var orientations: Array[StringName] = [&"y"]
			if kind in [&"wall", &"gate"]:
				orientations = [&"x", &"y"]
			for orientation in orientations:
				var footprint := authored_footprint
				if kind == &"gate" and orientation == &"x":
					footprint = Vector2i(authored_footprint.y, authored_footprint.x)
				var display_size: Vector2 = battlefield.call(
					"_structure_display_size",
					kind,
					footprint,
					texture,
				)
				var bottom_margin := float(texture.get_height() - content_rect.end.y)
				var content_center_x := float(content_rect.position.x) + float(content_rect.size.x) * 0.5
				var texture_rect: Rect2 = battlefield.call(
					"_world_texture_rect",
					texture,
					display_size,
					bottom_margin,
					content_center_x,
				)
				var scale_x := display_size.x / float(texture.get_width())
				var scale_y := display_size.y / float(texture.get_height())
				var visible_left := texture_rect.position.x + float(content_rect.position.x) * scale_x
				var visible_right := texture_rect.position.x + float(content_rect.end.x) * scale_x
				var visible_bottom := texture_rect.position.y + float(content_rect.end.y) * scale_y
				var footprint_width := (
					float(footprint.x + footprint.y)
					* IsoProjection.TILE_WIDTH
					* 0.5
				)
				var target_content_width := (
					IsoProjection.TILE_WIDTH * 0.5 * Battlefield.WALL_SPRITE_SCALE
					if kind == &"wall"
					else (
						float(maxi(footprint.x, footprint.y))
						* IsoProjection.TILE_WIDTH
						* 0.5
						* float(battlefield.call("_gate_sprite_scale", texture))
					)
					if kind == &"gate"
					else footprint_width
				)
				var flip_h := bool(battlefield.call(
					"_structure_sprite_flipped",
					kind,
					orientation,
					footprint,
					texture,
				))
				var axis_skew := float(battlefield.call(
					"_structure_sprite_axis_skew",
					kind,
					orientation,
					footprint,
					texture,
					display_size,
					flip_h,
				))
				var source_slope := float(battlefield.call("_texture_ground_axis_slope", texture))
				source_slope *= scale_y / scale_x
				var horizontal_scale := -1.0 if flip_h else 1.0
				var fitted_slope := (source_slope + axis_skew) / horizontal_scale
				var target_slope := float(battlefield.call(
					"_fortification_target_axis_slope",
					kind,
					orientation,
					footprint,
				))
				var expected_slope := 0.0
				if kind in [&"wall", &"gate"]:
					expected_slope = (
						IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH
						if orientation == &"x"
						else -IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH
					)
				var label := "%s %s %s" % [faction, orientation, kind]
				_expect(content_rect.has_area(), "%s texture has no visible content" % label, failures)
				_expect(
					is_equal_approx(visible_right - visible_left, target_content_width),
					"%s sprite does not match its projected tile-axis span" % label,
					failures,
				)
				_expect(
					visible_left >= -footprint_width * 0.5 - 0.001
						and visible_right <= footprint_width * 0.5 + 0.001,
					"%s sprite overflows its projected footprint width" % label,
					failures,
				)
				_expect(
					absf(visible_bottom) <= 0.001,
					"%s sprite is not grounded at its footprint edge" % label,
					failures,
				)
				_expect(
					is_equal_approx(fitted_slope, target_slope),
					"%s sprite ground axis does not match its projected tile axis" % label,
					failures,
				)
				_expect(
					is_equal_approx(target_slope, expected_slope),
					"%s target does not use the exact isometric tile-edge angle" % label,
					failures,
				)
				if kind == &"gate":
					var expected_gate_scale := (
						1.30
						if faction in [&"demon", &"beast"]
						else 1.20
						if faction == &"celestial"
						else 1.00
					)
					_expect(
						is_equal_approx(
							float(battlefield.call("_gate_sprite_scale", texture)),
							expected_gate_scale,
						),
						"%s gate did not use its configured sprite stretch" % faction,
						failures,
					)
					var axis_offset := battlefield.call(
						"_gate_sprite_axis_anchor_offset",
						orientation,
						texture,
						display_size,
					) as Vector2
					var transformed_left := axis_offset.x + horizontal_scale * visible_left
					var transformed_right := axis_offset.x + horizontal_scale * visible_right
					var anchor_ratio := float(battlefield.call(
						"_gate_sprite_anchor_ratio",
						texture,
					))
					var expected_left := (
						-target_content_width * (0.5 + anchor_ratio)
						if orientation == &"x"
						else target_content_width * (anchor_ratio - 0.5)
					)
					var expected_right := (
						target_content_width * (0.5 - anchor_ratio)
						if orientation == &"x"
						else target_content_width * (0.5 + anchor_ratio)
					)
					_expect(
						is_equal_approx(minf(transformed_left, transformed_right), expected_left)
							and is_equal_approx(maxf(transformed_left, transformed_right), expected_right),
						"%s sprite axis endpoints miss its front long footprint edge" % label,
						failures,
					)
					var nominal_edge_width := (
						float(maxi(footprint.x, footprint.y))
						* IsoProjection.TILE_WIDTH
						* 0.5
					)
					var ground_anchor_from_bottom_vertex_x := (
						-nominal_edge_width * 0.25
						if orientation == &"x"
						else nominal_edge_width * 0.25
					)
					var footprint_left := (
						-nominal_edge_width if orientation == &"x" else 0.0
					)
					var footprint_right := (
						0.0 if orientation == &"x" else nominal_edge_width
					)
					var sprite_left := ground_anchor_from_bottom_vertex_x + expected_left
					var sprite_right := ground_anchor_from_bottom_vertex_x + expected_right
					if faction == &"human":
						_expect(
							is_equal_approx(sprite_left, footprint_left)
								and is_equal_approx(sprite_right, footprint_right),
							"%s sprite did not stop exactly at both tile-edge endpoints" % label,
							failures,
						)
					else:
						_expect(
							sprite_left < footprint_left and sprite_right > footprint_right,
							"%s sprite did not overlap both adjacent wall seams" % label,
							failures,
						)
						var negative_overlap := footprint_left - sprite_left
						var positive_overlap := sprite_right - footprint_right
						_expect(
							negative_overlap > positive_overlap
							if orientation == &"x"
							else positive_overlap > negative_overlap,
							"%s sprite overlap was not biased %s" % [
								label,
								"NW" if orientation == &"x" else "NE",
							],
							failures,
						)
				elif kind == &"wall":
					var axis_offset := battlefield.call(
						"_wall_sprite_axis_anchor_offset",
						orientation,
				) as Vector2
					var nominal_edge_width := IsoProjection.TILE_WIDTH * 0.5
					var seam_overlap := (target_content_width - nominal_edge_width) * 0.5
					var transformed_left := axis_offset.x + horizontal_scale * visible_left
					var transformed_right := axis_offset.x + horizontal_scale * visible_right
					var expected_left := (
						-nominal_edge_width - seam_overlap
						if orientation == &"x"
						else -seam_overlap
					)
					var expected_right := (
						seam_overlap
						if orientation == &"x"
						else nominal_edge_width + seam_overlap
					)
					_expect(
						is_equal_approx(axis_offset.x, -nominal_edge_width * 0.5)
							if orientation == &"x"
							else is_equal_approx(axis_offset.x, nominal_edge_width * 0.5),
						"%s sprite did not shift toward its tile-edge midpoint" % label,
						failures,
					)
					_expect(
						is_equal_approx(minf(transformed_left, transformed_right), expected_left)
							and is_equal_approx(maxf(transformed_left, transformed_right), expected_right),
						"%s sprite does not overlap its tile edge symmetrically" % label,
						failures,
					)

	for team in range(simulation.players.size()):
		var faction := simulation.players[team]["faction"] as StringName
		var tower_id := simulation._spawn_structure(
			team,
			&"sentry_tower",
			Vector2i(-100 - team * 4, -100),
			true,
		)
		var first_unit_id := simulation._spawn_unit(
			team,
			&"mystic",
			Vector2i(-100 - team * 4, -98),
		)
		var second_unit_id := simulation._spawn_unit(
			team,
			&"mystic",
			Vector2i(-100 - team * 4, -97),
		)
		var tower := simulation.entity(tower_id)
		simulation._enter_garrison(tower, simulation.entity(first_unit_id))
		simulation._enter_garrison(tower, simulation.entity(second_unit_id))
		var tower_center: Vector2 = battlefield.call("_grounded_sprite_screen_position", tower)
		var draw_data: Array = battlefield.call(
			"_tower_occupant_draw_data",
			tower,
			tower_center,
		)
		_expect(
			draw_data.size() == 2,
			"%s tower did not project both live garrison occupants" % faction,
			failures,
		)
		if draw_data.size() == 2:
			var first_center := (draw_data[0] as Dictionary)["center"] as Vector2
			var second_center := (draw_data[1] as Dictionary)["center"] as Vector2
			_expect(
				not first_center.is_equal_approx(second_center),
				"%s tower projected both occupants into the same rooftop slot" % faction,
				failures,
			)
			_expect(
				first_center.y < tower_center.y and second_center.y < tower_center.y,
				"%s tower projected an occupant below its rooftop" % faction,
				failures,
			)

	var resource_id := -1
	var enemy_worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])[0]
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") == &"resource" and entity_state.get("resource_kind") == &"jade":
			resource_id = int(entity_state["id"])
			break
	_expect(resource_id >= 0, "no neutral resource was available for inspection", failures)
	if resource_id >= 0:
		var resource_screen := battlefield.entity_screen_position(simulation.entity(resource_id))
		battlefield.call("_handle_left_press", resource_screen)
		battlefield.call("_handle_left_release", resource_screen)
		_expect(battlefield.selected_ids == [resource_id], "left-click could not inspect a neutral resource", failures)
		_expect(battlefield.selected_commandable_units().is_empty(), "neutral resource became commandable", failures)

	var enemy_screen := battlefield.entity_screen_position(simulation.entity(enemy_worker_id))
	battlefield.call("_handle_left_press", enemy_screen)
	battlefield.call("_handle_left_release", enemy_screen)
	_expect(battlefield.selected_ids == [enemy_worker_id], "left-click could not inspect a visible enemy unit", failures)
	_expect(battlefield.selected_commandable_units().is_empty(), "inspected enemy unit became commandable", failures)

	var player_worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([player_worker_id])
	var selection_changes := [0]
	battlefield.selection_changed.connect(func(_ids: Array) -> void: selection_changes[0] += 1)
	simulation.entity(player_worker_id)["alive"] = false
	battlefield.call("_process", 0.01)
	_expect(battlefield.selected_ids.is_empty(), "dead entity remained selected", failures)
	_expect(selection_changes[0] == 1, "selection pruning did not emit exactly one state update", failures)

	var replacement_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", MapCatalog.PLAYER_WORKERS[0])
	battlefield.select_entities([replacement_id])
	var replacement := simulation.entity(replacement_id)
	var position_before := replacement["position"] as Vector2
	var order_before := replacement.get("order") as StringName
	var feedback_messages: Array[String] = []
	battlefield.feedback.connect(func(message: String, _is_error: bool) -> void: feedback_messages.append(message))
	var off_map_screen := battlefield.camera_offset + IsoProjection.cell_center(Vector2i(-20, -20)) * battlefield.camera_scale
	battlefield.call("_handle_right_click", off_map_screen)
	_expect(replacement.get("order") == order_before, "off-map right-click changed the unit order", failures)
	_expect((replacement["position"] as Vector2).is_equal_approx(position_before), "off-map right-click moved the unit", failures)
	_expect(not feedback_messages.is_empty() and "beyond" in feedback_messages[-1], "off-map right-click did not report an error", failures)
	var invalid_pulse_found := false
	for pulse in battlefield._effect_director.pulses:
		if pulse.get("kind") == &"invalid":
			invalid_pulse_found = true
			break
	_expect(invalid_pulse_found, "off-map right-click did not create invalid-action feedback", failures)

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS battlefield_regression_test: fortification fitting, multi-occupant tower projection, resource/enemy inspection, ownership, stale selection, bounds rejection")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
