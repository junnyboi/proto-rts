extends SceneTree

const OUTPUT := "res://captures"


class FortificationFacingAudit:
	extends Control

	var battlefield: Battlefield
	var structure_kind: StringName = &"gate"
	var textures: Array[Texture2D] = []
	var wall_corner_gallery := false
	var wall_polygon_gallery := false
	var polygon_renderer: Battlefield
	var polygon_panels: Array[Dictionary] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("071719"))
		var font := ThemeDB.fallback_font
		if wall_corner_gallery:
			_draw_wall_corner_gallery(font)
			return
		if wall_polygon_gallery:
			_draw_wall_polygon_gallery(font)
			return
		draw_string(
			font,
			Vector2(0.0, 34.0),
			(
				"WALL CHAIN CENTERING + 10% SEAM OVERLAP — 0° AND 90°"
				if structure_kind == &"wall"
				else "GATE TILE-AXIS ALIGNMENT — 0° AND 90°"
			),
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			20,
			Color("f4e3aa"),
		)
		var column_width := size.x / float(FactionCatalog.ORDER.size())
		var row_anchors := [Vector2(0.0, 330.0), Vector2(0.0, 625.0)]
		var orientations: Array[StringName] = [&"x", &"y"]
		var preview_scale := 1.4 if structure_kind == &"wall" else 0.72
		if textures.is_empty():
			for faction in FactionCatalog.ORDER:
				textures.append(
					load(FactionCatalog.entity_art_path(faction, structure_kind)) as Texture2D
				)
		for faction_index in range(FactionCatalog.ORDER.size()):
			var faction := FactionCatalog.ORDER[faction_index]
			var faction_name := String(FactionCatalog.DATA[faction]["name"])
			var column_center := column_width * (float(faction_index) + 0.5)
			if structure_kind == &"gate" and faction_index == 0:
				column_center += 28.0
			draw_string(
				font,
				Vector2(column_center - column_width * 0.5, 70.0),
				faction_name,
				HORIZONTAL_ALIGNMENT_CENTER,
				column_width,
				18,
				Color("fff0bf"),
			)
			var texture := textures[faction_index]
			for orientation_index in range(orientations.size()):
				var orientation := orientations[orientation_index]
				var footprint := (
					Vector2i.ONE
					if structure_kind == &"wall"
					else Vector2i(4, 2) if orientation == &"x" else Vector2i(2, 4)
				)
				var chain_length := 3 if structure_kind == &"wall" else 1
				var axis_step_cell := (
					Vector2i(1, 0) if orientation == &"x" else Vector2i(0, 1)
				)
				var axis_step := (
					IsoProjection.project(Vector2(axis_step_cell)) * preview_scale
				)
				var first_anchor := (
					Vector2(column_center, row_anchors[orientation_index].y)
					- axis_step * float(chain_length - 1) * 0.5
				)
				var anchors: Array[Vector2] = []
				for chain_index in range(chain_length):
					anchors.append(first_anchor + axis_step * float(chain_index))
				for anchor in anchors:
					_draw_footprint(anchor, footprint, preview_scale)
				for anchor in anchors:
					_draw_fortification(
						anchor,
						texture,
						orientation,
						footprint,
						preview_scale,
					)
		for orientation_index in range(orientations.size()):
			var label := "0° / MAP X" if orientation_index == 0 else "90° / MAP Y"
			var label_y := 106.0 if orientation_index == 0 else 406.0
			draw_string(
				font,
				Vector2(0.0, label_y),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				size.x,
				15,
				Color("91e7df"),
			)

	func _draw_wall_corner_gallery(font: Font) -> void:
		draw_string(
			font,
			Vector2(0.0, 34.0),
			"ALL-RACE WALL CORNERS — TOP / BOTTOM / LEFT / RIGHT",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			20,
			Color("f4e3aa"),
		)
		var column_width := size.x / float(FactionCatalog.ORDER.size())
		var corner_definitions := [
			{"label": "TOP", "directions": [&"bottom_left", &"bottom_right"]},
			{"label": "BOTTOM", "directions": [&"top_left", &"top_right"]},
			{"label": "LEFT", "directions": [&"top_right", &"bottom_right"]},
			{"label": "RIGHT", "directions": [&"top_left", &"bottom_left"]},
		]
		var preview_scale := 0.92
		if textures.is_empty():
			for faction in FactionCatalog.ORDER:
				textures.append(
					load(FactionCatalog.entity_art_path(faction, &"wall")) as Texture2D
				)
		for faction_index in range(FactionCatalog.ORDER.size()):
			var faction := FactionCatalog.ORDER[faction_index]
			var faction_name := String(FactionCatalog.DATA[faction]["name"])
			var column_center := column_width * (float(faction_index) + 0.5)
			draw_string(
				font,
				Vector2(column_center - column_width * 0.5, 70.0),
				faction_name,
				HORIZONTAL_ALIGNMENT_CENTER,
				column_width,
				18,
				Color("fff0bf"),
			)
			for corner_index in range(corner_definitions.size()):
				var definition := corner_definitions[corner_index] as Dictionary
				var local_column := corner_index % 2
				var local_row := corner_index / 2
				var anchor := Vector2(
					column_center + (-column_width * 0.24 if local_column == 0 else column_width * 0.24),
					260.0 + float(local_row) * 315.0,
				)
				draw_string(
					font,
					Vector2(anchor.x - column_width * 0.24, anchor.y - 115.0),
					definition["label"],
					HORIZONTAL_ALIGNMENT_CENTER,
					column_width * 0.48,
					14,
					Color("91e7df"),
				)
				_draw_footprint(anchor, Vector2i.ONE, preview_scale)
				for raw_direction in definition["directions"]:
					var direction := raw_direction as StringName
					var orientation := battlefield.call(
						"_wall_corner_direction_orientation",
						direction,
					) as StringName
					_draw_fortification(
						anchor,
						textures[faction_index],
						orientation,
						Vector2i.ONE,
						preview_scale,
						direction,
					)

	func _draw_wall_polygon_gallery(font: Font) -> void:
		_ensure_wall_polygon_data()
		draw_string(
			font,
			Vector2(0.0, 32.0),
			"NATIVE WALL POLYGON STRESS TEST — LIVE ADJACENCY CORNERS",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			20,
			Color("f4e3aa"),
		)
		if textures.is_empty():
			for faction in FactionCatalog.ORDER:
				textures.append(
					load(FactionCatalog.entity_art_path(faction, &"wall")) as Texture2D
				)
		var panel_size := Vector2(size.x * 0.5 - 24.0, size.y * 0.5 - 34.0)
		var preview_scale := 0.48
		for panel_index in range(polygon_panels.size()):
			var panel := polygon_panels[panel_index]
			var panel_column := panel_index % 2
			var panel_row := panel_index / 2
			var panel_position := Vector2(
				12.0 + float(panel_column) * (size.x * 0.5),
				48.0 + float(panel_row) * (size.y * 0.5 - 8.0),
			)
			var panel_rect := Rect2(panel_position, panel_size)
			draw_rect(panel_rect, Color("0b2224"), true)
			draw_rect(panel_rect, Color("285b5a"), false, 1.0)
			var faction := panel["faction"] as StringName
			var faction_name := String(FactionCatalog.DATA[faction]["name"])
			var walls := panel["walls"] as Array
			var resolved_turn_count := 0
			for raw_wall in walls:
				var corner_directions := polygon_renderer.call(
					"_wall_corner_directions",
					raw_wall as Dictionary,
				) as Array
				if not corner_directions.is_empty():
					resolved_turn_count += 1
			draw_string(
				font,
				panel_rect.position + Vector2(0.0, 27.0),
				"%s — SHAPE %d · %d RESOLVED TURNS"
					% [faction_name, panel_index + 1, resolved_turn_count],
				HORIZONTAL_ALIGNMENT_CENTER,
				panel_rect.size.x,
				16,
				Color("fff0bf"),
			)
			var base_cell := panel["base_cell"] as Vector2i
			var projected_min := Vector2(INF, INF)
			var projected_max := Vector2(-INF, -INF)
			for raw_wall in walls:
				var wall := raw_wall as Dictionary
				var local_cell := (wall["cell"] as Vector2i) - base_cell
				var projected := IsoProjection.project(Vector2(local_cell))
				projected_min = projected_min.min(projected)
				projected_max = projected_max.max(projected)
			var projected_center := (projected_min + projected_max) * 0.5
			var panel_center := panel_rect.get_center() + Vector2(0.0, 24.0)
			var origin := panel_center - projected_center * preview_scale
			for raw_wall in walls:
				var wall := raw_wall as Dictionary
				var local_cell := (wall["cell"] as Vector2i) - base_cell
				var anchor := origin + IsoProjection.project(Vector2(local_cell)) * preview_scale
				_draw_footprint(anchor, Vector2i.ONE, preview_scale)
			var ordered_walls := walls.duplicate()
			ordered_walls.sort_custom(Callable(polygon_renderer, "_entity_draws_before"))
			for raw_wall in ordered_walls:
				var wall := raw_wall as Dictionary
				var local_cell := (wall["cell"] as Vector2i) - base_cell
				var anchor := origin + IsoProjection.project(Vector2(local_cell)) * preview_scale
				var render_orientations := polygon_renderer.call(
					"_wall_render_orientations",
					wall,
				) as Array
				for raw_orientation in render_orientations:
					var orientation := raw_orientation as StringName
					_draw_fortification(
						anchor,
						textures[panel_index],
						orientation,
						Vector2i.ONE,
						preview_scale,
					)

	func _ensure_wall_polygon_data() -> void:
		if not polygon_panels.is_empty():
			return
		var polygon_simulation := RtsSimulation.new()
		polygon_simulation.setup(&"human", false)
		polygon_renderer = Battlefield.new()
		polygon_renderer.simulation = polygon_simulation
		var random := RandomNumberGenerator.new()
		random.seed = 0x57414C4C
		for faction_index in range(FactionCatalog.ORDER.size()):
			var faction := FactionCatalog.ORDER[faction_index]
			polygon_simulation.players[faction_index]["faction"] = faction
			var vertices := _random_wall_polygon_vertices(faction_index, random)
			var polygon_cells := _orthogonal_polygon_cells(vertices)
			var base_cell := Vector2i(-500 + faction_index * 30, -500)
			var walls: Array[Dictionary] = []
			for raw_cell in polygon_cells:
				var local_cell := raw_cell as Vector2i
				var orientation := polygon_cells[local_cell] as StringName
				var wall_id := polygon_simulation._spawn_structure(
					faction_index,
					&"wall",
					base_cell + local_cell,
					true,
					orientation,
				)
				walls.append(polygon_simulation.entity(wall_id))
			polygon_panels.append({
				"faction": faction,
				"base_cell": base_cell,
				"walls": walls,
			})
		polygon_renderer.call("_rebuild_wall_render_lookup")

	func _random_wall_polygon_vertices(
		template_index: int,
		random: RandomNumberGenerator,
	) -> Array[Vector2i]:
		var width := random.randi_range(8, 10)
		var height := random.randi_range(6, 8)
		var vertices: Array[Vector2i] = []
		match template_index:
			0:
				vertices.assign([
					Vector2i(0, 0), Vector2i(width, 0),
					Vector2i(width, height / 2), Vector2i(width - 3, height / 2),
					Vector2i(width - 3, height), Vector2i(0, height),
				])
			1:
				vertices.assign([
					Vector2i(0, 0), Vector2i(width, 0), Vector2i(width, height),
					Vector2i(width - 3, height), Vector2i(width - 3, 3),
					Vector2i(3, 3), Vector2i(3, height), Vector2i(0, height),
				])
			2:
				vertices.assign([
					Vector2i(0, 0), Vector2i(width - 3, 0), Vector2i(width - 3, 2),
					Vector2i(width, 2), Vector2i(width, height), Vector2i(3, height),
					Vector2i(3, height - 2), Vector2i(0, height - 2),
				])
			_:
				vertices.assign([
					Vector2i(2, 0), Vector2i(width - 2, 0), Vector2i(width - 2, 2),
					Vector2i(width, 2), Vector2i(width, height - 2),
					Vector2i(width - 2, height - 2), Vector2i(width - 2, height),
					Vector2i(2, height), Vector2i(2, height - 2),
					Vector2i(0, height - 2), Vector2i(0, 2), Vector2i(2, 2),
				])
		return vertices

	func _orthogonal_polygon_cells(vertices: Array[Vector2i]) -> Dictionary:
		var result: Dictionary = {}
		for vertex_index in range(vertices.size()):
			var start := vertices[vertex_index]
			var finish := vertices[(vertex_index + 1) % vertices.size()]
			var delta := finish - start
			var orientation: StringName = &"x" if delta.x != 0 else &"y"
			var distance := absi(delta.x) if delta.x != 0 else absi(delta.y)
			var step := Vector2i(signi(delta.x), 0) if delta.x != 0 else Vector2i(0, signi(delta.y))
			for step_index in range(distance):
				result[start + step * step_index] = orientation
		return result

	func _draw_footprint(anchor: Vector2, footprint: Vector2i, preview_scale: float) -> void:
		for y in range(footprint.y):
			for x in range(footprint.x):
				var points := PackedVector2Array()
				for point in IsoProjection.cell_polygon(Vector2i(x, y)):
					points.append(
						anchor
						+ (point - IsoProjection.project(Vector2(footprint))) * preview_scale
					)
				draw_colored_polygon(points, Color(0.18, 0.72, 0.69, 0.10))
				var closed := points.duplicate()
				closed.append(points[0])
				draw_polyline(closed, Color(0.36, 0.92, 0.88, 0.72), 1.4, true)

	func _draw_fortification(
		anchor: Vector2,
		texture: Texture2D,
		orientation: StringName,
		footprint: Vector2i,
		preview_scale: float,
		wall_corner_direction: StringName = &"",
	) -> void:
		var display_size := (
			battlefield.call(
				"_structure_display_size",
				structure_kind,
				footprint,
				texture,
			) as Vector2
		) * preview_scale
		var content_rect := battlefield.call("_texture_content_rect", texture) as Rect2i
		var bottom_margin := float(texture.get_height() - content_rect.end.y)
		var content_center_x := float(content_rect.position.x) + float(content_rect.size.x) * 0.5
		var flip_h := bool(battlefield.call(
			"_structure_sprite_flipped",
			structure_kind,
			orientation,
			footprint,
			texture,
		))
		var axis_skew := float(battlefield.call(
			"_structure_sprite_axis_skew",
			structure_kind,
			orientation,
			footprint,
			texture,
			display_size,
			flip_h,
		))
		var rect := battlefield.call(
			"_world_texture_rect",
			texture,
			display_size,
			bottom_margin,
			content_center_x,
		) as Rect2
		var overhang := float(battlefield.call(
			"_skewed_texture_bottom_overhang",
			texture,
			display_size,
			content_center_x,
			axis_skew,
		))
		var horizontal_scale := -1.0 if flip_h else 1.0
		# The gallery footprint anchor is its lowest vertex, while live structure art
		# uses a point directly below the projected footprint center. Reproduce that
		# rectangular-footprint offset so the audit matches gameplay exactly.
		var grounded_anchor := anchor + Vector2(
			float(footprint.y - footprint.x)
				* IsoProjection.TILE_WIDTH
				* 0.25
				* preview_scale,
			0.0,
		)
		var axis_anchor_offset := Vector2.ZERO
		if structure_kind == &"gate":
			axis_anchor_offset = battlefield.call(
				"_gate_sprite_axis_anchor_offset",
				orientation,
				texture,
				display_size,
			) as Vector2
		elif structure_kind == &"wall":
			axis_anchor_offset = battlefield.call(
				"_wall_sprite_axis_anchor_offset",
				orientation,
				preview_scale,
			) as Vector2
			if not wall_corner_direction.is_empty():
				axis_anchor_offset += battlefield.call(
					"_wall_corner_direction_anchor_offset",
					wall_corner_direction,
					preview_scale,
				) as Vector2
		draw_set_transform_matrix(Transform2D(
			Vector2(horizontal_scale, axis_skew),
			Vector2(0.0, 1.0),
			grounded_anchor + axis_anchor_offset - Vector2(0.0, overhang),
		))
		draw_texture_rect(texture, rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for _frame in range(frames):
		await process_frame
	RenderingServer.force_draw()


func _capture(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name])
	var result := image.save_png(path)
	if result != OK:
		push_error("failed to save capture %s: %s" % [path, error_string(result)])


func _capture_fortification_facing_audit(
	game: Node,
	structure_kind: StringName,
	capture_name: String,
	wall_corner_gallery: bool = false,
	wall_polygon_gallery: bool = false,
) -> void:
	var audit_layer := CanvasLayer.new()
	audit_layer.layer = 100
	var audit := FortificationFacingAudit.new()
	audit.battlefield = game.battlefield
	audit.structure_kind = structure_kind
	audit.wall_corner_gallery = wall_corner_gallery
	audit.wall_polygon_gallery = wall_polygon_gallery
	audit.size = root.get_visible_rect().size
	audit_layer.add_child(audit)
	root.add_child(audit_layer)
	await _settle(2)
	_capture(capture_name)
	root.remove_child(audit_layer)
	if audit.polygon_renderer != null:
		audit.polygon_renderer.free()
	audit_layer.free()
	await _settle(2)


func _find_visual_wall_line(simulation: RtsSimulation, length: int) -> Array[Vector2i]:
	for y in range(5, MapCatalog.SIZE.y - 5):
		for x in range(5, MapCatalog.SIZE.x - length - 5):
			var start := Vector2i(x, y)
			var finish := start + Vector2i(length - 1, 0)
			if simulation.can_place_wall_line(RtsSimulation.TEAM_PLAYER, start, finish):
				return simulation.wall_line_cells(start, finish)
	return []


func _capture_game_juice_states(game: Node, battlefield: Battlefield, stronghold: Dictionary) -> void:
	var base := battlefield.call("_entity_world_center", stronghold) as Vector2
	var worker_kinds: Array[StringName] = [&"worker"]
	var workers: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		worker_kinds,
	)
	battlefield.camera_scale = 0.92
	battlefield.center_on_cell(stronghold["cell"] as Vector2i)
	battlefield.configure_effects(&"full", false, &"all", &"full")
	battlefield._effect_director.clear()
	battlefield._presentation.synchronize(game.simulation.entities)
	battlefield.select_entities(workers.slice(0, mini(3, workers.size())))
	if not workers.is_empty():
		var hover_id := workers[0]
		battlefield._presentation.set_hover(hover_id)
		battlefield._presentation.advance(0.12)
		battlefield._mouse_position = battlefield.entity_screen_position(game.simulation.entity(hover_id))
	battlefield._effect_director.emit_click(base + Vector2(2.2, 0.5), &"move", Color("78dfb7"))
	battlefield._effect_director.emit_click(base + Vector2(1.0, 2.4), &"queued", Color("79c9ee"), true)
	battlefield._effect_director.emit_invalid(base + Vector2(-1.5, 2.0))
	_stage_game_juice_capture(battlefield)
	battlefield.move_armed = true
	game._toast_panel.visible = false
	game.call("_update_hud")
	battlefield.queue_redraw()
	await _settle(2)
	_capture("game-juice-interaction")
	battlefield.cancel_modes()

	battlefield._effect_director.clear()
	var combat_events: Array[Dictionary] = [
		{
			"type": &"attack", "from": base + Vector2(-2.5, -0.2), "to": base + Vector2(-0.8, 0.5),
			"color": Color("f1cb67"), "attacker_kind": &"vanguard", "attacker_faction": &"human",
			"target_category": &"unit", "target_id": 9001, "amount": 14.0,
		},
		{
			"type": &"attack", "from": base + Vector2(-1.5, 2.0), "to": base + Vector2(1.0, 1.2),
			"color": Color("77c6ff"), "attacker_kind": &"hunter", "attacker_faction": &"human",
			"target_category": &"unit", "target_id": 9002, "amount": 11.0,
		},
		{
			"type": &"attack", "from": base + Vector2(1.7, -1.0), "to": base + Vector2(0.8, 1.0),
			"color": Color("79e1c1"), "attacker_kind": &"mystic", "attacker_faction": &"celestial",
			"target_category": &"unit", "target_id": 9002, "amount": 18.0,
		},
		{
			"type": &"attack", "from": base + Vector2(2.8, 0.2), "to": base + Vector2(1.3, 1.8),
			"color": Color("d6a45b"), "attacker_kind": &"jadeclaw", "attacker_faction": &"beast",
			"target_category": &"unit", "target_id": 9004, "amount": 22.0,
		},
		{
			"type": &"attack", "from": base + Vector2(-3.2, -1.5), "to": base + Vector2(2.6, -0.7),
			"color": Color("b7ffd8"), "attacker_kind": &"shenlong", "attacker_faction": &"celestial",
			"target_category": &"structure", "target_id": 9005, "amount": 30.0,
		},
		{
			"type": &"death", "position": base + Vector2(2.2, 1.8), "category": &"unit",
			"kind": &"vanguard", "faction": &"demon", "color": Color("ff685b"),
		},
	]
	for event in combat_events:
		battlefield.preview_effect(event)
	_stage_game_juice_capture(battlefield)
	battlefield.queue_redraw()
	await _settle(2)
	_capture("game-juice-combat")

	battlefield._effect_director.clear()
	for event in [
		{"type": &"build", "position": base + Vector2(-2.0, 1.0), "color": Color("f1cb67"), "faction": &"human", "category": &"structure"},
		{"type": &"repair", "position": base + Vector2(0.4, 0.4), "color": Color("e4c66d"), "faction": &"human", "target_id": int(stronghold["id"]), "amount": 8.0},
		{"type": &"deposit", "position": base, "color": Color("73dfab"), "faction": &"human", "entity_id": int(stronghold["id"]), "resource_kind": &"jade", "amount": 10.0},
		{"type": &"food", "position": base + Vector2(2.0, -1.2), "color": Color("f2c85b"), "faction": &"human", "entity_id": 9003, "resource_kind": &"food", "amount": 5.0},
	]:
		battlefield.preview_effect(event)
	_stage_game_juice_capture(battlefield)
	battlefield.queue_redraw()
	await _settle(2)
	_capture("game-juice-economy")

	battlefield.configure_effects(&"low", true, &"contextual", &"off")
	battlefield._effect_director.clear()
	battlefield.preview_effect(combat_events[1])
	battlefield.preview_effect({
		"type": &"capture", "position": base + Vector2(1.2, 1.0), "color": Color("79e1c1"),
		"faction": &"celestial", "category": &"structure",
	})
	_stage_game_juice_capture(battlefield)
	battlefield.queue_redraw()
	await _settle(2)
	_capture("game-juice-reduced-motion")
	battlefield.configure_effects(&"full", false, &"contextual", &"major")
	battlefield._effect_director.clear()


func _stage_game_juice_capture(battlefield: Battlefield) -> void:
	for record in battlefield._effect_director.trails:
		record["elapsed"] = float(record.get("duration", 0.2)) * 0.48
	for record in battlefield._effect_director.impacts:
		record["elapsed"] = float(record.get("duration", 0.2)) * 0.24
	for record in battlefield._effect_director.particles:
		record["elapsed"] = float(record.get("duration", 0.4)) * 0.32
	for record in battlefield._effect_director.values:
		record["elapsed"] = float(record.get("duration", 0.8)) * 0.34
	for record in battlefield._effect_director.pulses:
		record["elapsed"] = float(record.get("duration", 0.5)) * 0.36
	for record in battlefield._effect_director.deaths:
		record["elapsed"] = float(record.get("duration", 0.8)) * 0.44


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var leaderboard_save_path := "user://visual_leaderboard_test.json"
	_cleanup_leaderboard(leaderboard_save_path)
	game.leaderboard_save_path = leaderboard_save_path
	root.add_child(game)
	await _settle()
	_capture("title")
	game.leaderboard_store.set_callsign("JADE GENERAL")
	game.leaderboard_store.record_match(6840, &"victory", &"human", 502)
	game.leaderboard_store.record_match(5210, &"defeat", &"beast", 417)
	game._leaderboard_button.pressed.emit()
	await _settle(2)
	_capture("leaderboard-title")
	game._leaderboard_dialog.close_dialog()
	game.call("_show_faction_select")
	await _settle()
	_capture("faction-select")
	game.call("_start_match", &"human")
	await _settle(20)
	_capture("skirmish")
	var cargo_preview_worker_kinds: Array[StringName] = [&"worker"]
	var cargo_preview_workers: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		cargo_preview_worker_kinds,
	)
	var cargo_preview_kinds: Array[StringName] = [&"jade", &"lumber", &"essence"]
	for index in range(mini(cargo_preview_workers.size(), cargo_preview_kinds.size())):
		var cargo_worker: Dictionary = game.simulation.entity(cargo_preview_workers[index])
		cargo_worker["cargo_kind"] = cargo_preview_kinds[index]
		cargo_worker["cargo_amount"] = RtsSimulation.CARGO_CAPACITY * 0.5
	game.battlefield.queue_redraw()
	await _settle(2)
	_capture("worker-cargo-icons")
	for worker_id in cargo_preview_workers:
		var cargo_worker: Dictionary = game.simulation.entity(worker_id)
		cargo_worker["cargo_kind"] = &""
		cargo_worker["cargo_amount"] = 0.0
	game.call("_toggle_pause")
	await _settle(2)
	_capture("paused")
	game._settings_button.pressed.emit()
	await _settle(2)
	_capture("settings")
	game._settings_back_button.pressed.emit()
	game._resume_button.pressed.emit()
	game._toast_panel.visible = false
	var live_battlefield: Battlefield = game.battlefield
	game.set_process(false)
	live_battlefield.set_process(false)
	game._minimap.set_process(false)
	game.call("_toggle_fog_of_war")
	var player_stronghold_id: int = game.simulation.primary_structure_id(
		RtsSimulation.TEAM_PLAYER,
		&"stronghold",
	)
	var player_stronghold: Dictionary = game.simulation.entity(player_stronghold_id)
	await _capture_game_juice_states(game, live_battlefield, player_stronghold)
	player_stronghold["stronghold_level"] = RtsSimulation.STRONGHOLD_MAX_LEVEL
	game.simulation.players[RtsSimulation.TEAM_PLAYER]["population_cap"] = (
		RtsSimulation.POPULATION_CAP
		+ RtsSimulation.STRONGHOLD_POPULATION_PER_UPGRADE * 2
	)
	live_battlefield._wind_animation_time = 1.35
	live_battlefield.select_entities([player_stronghold_id])
	game.battlefield.camera_scale = 1.0
	game.battlefield.center_on_cell(player_stronghold["cell"] as Vector2i)
	game.call("_update_hud")
	await _settle(2)
	_capture("stronghold-upgrade-effects")
	player_stronghold["stronghold_level"] = RtsSimulation.STRONGHOLD_INITIAL_LEVEL
	game.simulation.players[RtsSimulation.TEAM_PLAYER]["population_cap"] = RtsSimulation.POPULATION_CAP
	var enemy_stronghold_id: int = game.simulation.primary_structure_id(
		RtsSimulation.TEAM_ENEMY,
		&"stronghold",
	)
	var enemy_stronghold: Dictionary = game.simulation.entity(enemy_stronghold_id)
	live_battlefield.select_entities([enemy_stronghold_id])
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(enemy_stronghold["cell"] as Vector2i)
	game.call("_update_hud")
	await _settle(2)
	_capture("enemy-inspection")
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(MapCatalog.CAVES[0]["cell"] as Vector2i)
	await _settle(2)
	_capture("monster-cave")
	var cave_id: int = int(game.simulation.cave_ids()[0])
	var cave: Dictionary = game.simulation.entity(cave_id)
	var hunter_id: int = int(game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		(cave["cell"] as Vector2i) + Vector2i(2, 1),
	))
	var hunter: Dictionary = game.simulation.entity(hunter_id)
	for raw_guardian_id in cave["guardian_ids"] as Array:
		game.simulation._kill(game.simulation.entity(int(raw_guardian_id)), hunter)
	game.simulation._complete_cave_capture(cave, RtsSimulation.TEAM_PLAYER)
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		game.simulation.players[RtsSimulation.TEAM_PLAYER][String(resource)] = 1000
	game.simulation.command_train(RtsSimulation.TEAM_PLAYER, cave_id, &"jadeclaw")
	game.simulation.command_train(RtsSimulation.TEAM_PLAYER, cave_id, &"jadeclaw")
	var selected_cave_ids: Array[int] = [cave_id]
	live_battlefield.select_entities(selected_cave_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("captured-cave")
	var selected_vanguard_ids: Array[int] = [hunter_id]
	live_battlefield.select_entities(selected_vanguard_ids)
	live_battlefield.begin_attack_move()
	game.call("_update_hud")
	await _settle(2)
	_capture("armed-attack-move")
	live_battlefield.cancel_modes()
	game._toast_panel.visible = false
	var farm_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"rice_farm",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	var farm_id: int = game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"rice_farm",
		farm_site,
		true,
	)
	game.simulation._rebuild_pathfinding()
	var lodge_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		farm_site + Vector2i(3, 0),
	)
	game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		lodge_site,
		true,
	)
	game.simulation._rebuild_pathfinding()
	var worker_kinds: Array[StringName] = [&"worker"]
	var player_worker_ids: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		worker_kinds,
	)
	var selected_worker_ids: Array[int] = [player_worker_ids[0]]
	game.simulation.command_assign_farm_worker(
		RtsSimulation.TEAM_PLAYER,
		selected_worker_ids,
		farm_id,
	)
	live_battlefield.select_entities(selected_worker_ids)
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(farm_site)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-build-menu")
	var selected_worker_group: Array[int] = player_worker_ids.slice(0, 3)
	live_battlefield.select_entities(selected_worker_group)
	game.call("_update_hud")
	await _settle(2)
	_capture("multi-selection")
	var selected_farm_ids: Array[int] = [farm_id]
	live_battlefield.select_entities(selected_farm_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-economy")
	await _capture_fortification_facing_audit(
		game,
		&"gate",
		"fortification-facing-audit",
	)
	await _capture_fortification_facing_audit(game, &"wall", "wall-facing-audit")
	await _capture_fortification_facing_audit(
		game,
		&"wall",
		"wall-corner-audit",
		true,
	)
	await _capture_fortification_facing_audit(
		game,
		&"wall",
		"wall-polygon-audit",
		false,
		true,
	)
	var wall_cells := _find_visual_wall_line(game.simulation, 6)
	if wall_cells.is_empty():
		push_error("fortification capture requires a clear wall line")
		quit(1)
		return
	for wall_cell in wall_cells:
		game.simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"wall", wall_cell, true)
	var gate_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"gate",
		wall_cells[2] + Vector2i(0, 3),
	)
	var gate_id: int = game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"gate",
		gate_site,
		true,
		&"x",
	)
	var tower_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"sentry_tower",
		gate_site + Vector2i(5, 0),
	)
	var tower_id: int = game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"sentry_tower",
		tower_site,
		true,
	)
	game.simulation._rebuild_pathfinding()
	var tower_hunter_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		game.simulation._nearest_walkable_around(tower_site, 4),
	)
	game.simulation._enter_garrison(game.simulation.entity(tower_id), game.simulation.entity(tower_hunter_id))
	live_battlefield.select_entities([tower_id])
	game.battlefield.camera_scale = 0.84
	game.battlefield.center_on_cell(Vector2i(((Vector2(gate_site) + Vector2(tower_site)) * 0.5).round()))
	game.call("_update_hud")
	await _settle(2)
	_capture("fortifications")
	if game.simulation.entity(gate_id).get("orientation") != &"x":
		push_error("fortification capture gate orientation diverged")
	var deer_id: int = game.simulation.wildlife_ids(&"deer")[0]
	var deer: Dictionary = game.simulation.entity(deer_id)
	var wildlife_hunter_cell: Vector2i = game.simulation._nearest_walkable(
		(deer["cell"] as Vector2i) + Vector2i(-2, 0),
	)
	var wildlife_hunter_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		wildlife_hunter_cell,
	)
	game.simulation._refresh_visibility()
	var wildlife_hunter_ids: Array[int] = [wildlife_hunter_id]
	game.simulation.command_attack(RtsSimulation.TEAM_PLAYER, wildlife_hunter_ids, deer_id)
	for _step in range(24):
		game.simulation.advance(RtsSimulation.TICK_SECONDS)
	live_battlefield.select_entities(wildlife_hunter_ids)
	game.battlefield.camera_scale = 0.86
	game.battlefield.center_on_cell(deer["cell"] as Vector2i)
	game.call("_update_hud")
	await _settle(2)
	_capture("wildlife-hunt")
	var nearest_resource: Dictionary = {}
	var nearest_resource_distance := INF
	for raw_entity in game.simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") != &"resource" or not bool(entity_state.get("alive", false)):
			continue
		var distance := (entity_state["position"] as Vector2).distance_to(deer["position"] as Vector2)
		if distance < nearest_resource_distance:
			nearest_resource_distance = distance
			nearest_resource = entity_state
	if nearest_resource.is_empty():
		push_error("command visualization capture requires a live resource")
		quit(1)
		return
	var command_center := nearest_resource["cell"] as Vector2i
	var move_worker_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"worker",
		game.simulation._nearest_walkable(command_center + Vector2i(-5, 1)),
	)
	var gather_worker_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"worker",
		game.simulation._nearest_walkable(command_center + Vector2i(-3, -1)),
	)
	var command_vanguard_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		game.simulation._nearest_walkable(command_center + Vector2i(0, 3)),
	)
	var command_target_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		game.simulation._nearest_walkable(command_center + Vector2i(2, 3)),
	)
	game.simulation._refresh_visibility()
	var move_worker_ids: Array[int] = [move_worker_id]
	var gather_worker_ids: Array[int] = [gather_worker_id]
	var command_vanguard_ids: Array[int] = [command_vanguard_id]
	game.simulation.command_move(
		RtsSimulation.TEAM_PLAYER,
		move_worker_ids,
		game.simulation._nearest_walkable(command_center + Vector2i(5, 1)),
	)
	game.simulation.command_gather(RtsSimulation.TEAM_PLAYER, gather_worker_ids, int(nearest_resource["id"]))
	game.simulation.command_attack(RtsSimulation.TEAM_PLAYER, command_vanguard_ids, command_target_id)
	live_battlefield.select_entities([move_worker_id, gather_worker_id, command_vanguard_id])
	live_battlefield._command_indicator_time = 0.72
	live_battlefield.camera_scale = 0.86
	live_battlefield.center_on_cell(command_center)
	game.call("_update_hud")
	await _settle(2)
	_capture("command-visualization")
	var shenlong: Dictionary = game.simulation.shenlong_guardian()
	var shenlong_egg: Dictionary = game.simulation.shenlong_egg()
	live_battlefield.select_entities([int(shenlong_egg["id"])])
	live_battlefield.camera_scale = 0.72
	live_battlefield.center_on_cell(MapCatalog.SHENLONG_EGG_CELL)
	game.call("_update_hud")
	await _settle(2)
	_capture("shenlong-objective")
	game.simulation._kill(shenlong, hunter)
	var egg_worker_id: int = player_worker_ids[0]
	var egg_worker_ids: Array[int] = [egg_worker_id]
	var egg_worker: Dictionary = game.simulation.entity(egg_worker_id)
	game.simulation.command_stop(RtsSimulation.TEAM_PLAYER, egg_worker_ids)
	egg_worker["cell"] = MapCatalog.SHENLONG_EGG_CELL + Vector2i(0, 1)
	egg_worker["position"] = Vector2(egg_worker["cell"] as Vector2i)
	game.simulation._refresh_visibility()
	game.simulation.command_claim_egg(
		RtsSimulation.TEAM_PLAYER,
		egg_worker_ids,
		int(shenlong_egg["id"]),
	)
	game.simulation.advance(RtsSimulation.TICK_SECONDS * 2.0)
	live_battlefield.select_entities(egg_worker_ids)
	live_battlefield.camera_scale = 0.86
	live_battlefield.center_on_cell(MapCatalog.SHENLONG_EGG_CELL)
	game.call("_update_hud")
	await _settle(2)
	_capture("dragon-egg-carrier")
	game._toast_panel.visible = false
	live_battlefield.select_entities([])
	game.call("_update_hud")
	game.battlefield.camera_scale = 0.105
	game.battlefield.center_on_cell(MapCatalog.SIZE / 2)
	game.battlefield.camera_offset.y -= 76.0
	await _settle(2)
	_capture("map-overview")
	for raw_entity in game.simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		entity_state["alive"] = false
	var tower_gallery_cell := Vector2i(40, 40)
	for team in range(game.simulation.players.size()):
		var faction := game.simulation.players[team]["faction"] as StringName
		var gallery_tower_id: int = int(game.simulation._spawn_structure(
			team,
			&"sentry_tower",
			tower_gallery_cell,
			true,
		))
		var gallery_unit_kinds: Array[StringName] = [&"hunter", &"mystic"]
		if faction == &"celestial":
			gallery_unit_kinds = [&"mystic", &"mystic"]
		var gallery_unit_ids: Array[int] = []
		for unit_index in range(gallery_unit_kinds.size()):
			var gallery_unit_id: int = int(game.simulation._spawn_unit(
				team,
				gallery_unit_kinds[unit_index],
				tower_gallery_cell + Vector2i(3 + unit_index, 0),
			))
			gallery_unit_ids.append(gallery_unit_id)
			game.simulation._enter_garrison(
				game.simulation.entity(gallery_tower_id),
				game.simulation.entity(gallery_unit_id),
			)
		live_battlefield.select_entities([gallery_tower_id])
		game.battlefield.camera_scale = 1.0
		game.battlefield.center_on_cell(tower_gallery_cell)
		game.call("_update_hud")
		await _settle(2)
		_capture("tower-garrison-%s" % faction)
		game.simulation.entity(gallery_tower_id)["alive"] = false
		for gallery_unit_id in gallery_unit_ids:
			game.simulation.entity(gallery_unit_id)["alive"] = false
	game.call("_on_match_ended", &"victory")
	await _settle(2)
	_capture("result")
	game._result_leaderboard_button.pressed.emit()
	await _settle(2)
	_capture("leaderboard-result")
	game._leaderboard_dialog.close_dialog()
	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player in director._players:
		player.stream = null
	director._music_player.stream = null
	root.remove_child(game)
	game.free()
	await process_frame
	_cleanup_leaderboard(leaderboard_save_path)
	print("PASS visual_capture: title, title/result leaderboards, faction-select, skirmish, worker cargo icons, pause, settings, four game-juice proof states, Stronghold upgrade effects, enemy inspection, caves, production queue, armed command, multi-selection, food economy, all-race wall, corner, polygon, and gate audits, fortifications, four-faction tower garrisons, wildlife hunt, command visualization, Shenlong objective, egg carrier, map overview, and result")
	quit(0)


func _cleanup_leaderboard(save_path: String) -> void:
	for path in [save_path, "%s.bak" % save_path, "%s.tmp" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
