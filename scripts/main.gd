extends Node

const STATE_TITLE := &"title"
const STATE_FACTION := &"faction"
const STATE_MATCH := &"match"
const STATE_RESULT := &"result"
const TITLE_ART := preload("res://assets/runtime/ui/mandate_of_myth_title.webp")
const BATTLEFIELD_MINIMAP := preload("res://scripts/view/battlefield_minimap.gd")

var state: StringName = STATE_TITLE
var selected_faction: StringName = &"human"
var paused := false
var simulation: RtsSimulation
var battlefield: Battlefield
var _screen: Control
var _resource_label: Label
var _faction_label: Label
var _selection_title: Label
var _selection_detail: Label
var _feedback_label: Label
var _pause_button: Button
var _fog_button: Button
var _minimap: Control
var _command_buttons: Dictionary = {}
var _hud_timer := 0.0
var _feedback_timer := 0.0
var _result_overlay: Control


func _ready() -> void:
	_show_title()


func _process(delta: float) -> void:
	if state == STATE_MATCH and simulation != null:
		if not paused:
			simulation.advance(delta)
		_hud_timer -= delta
		if _hud_timer <= 0.0:
			_hud_timer = 0.1
			_update_hud()
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0 and _feedback_label != null:
			_feedback_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if state != STATE_MATCH or battlefield == null:
		if key.keycode == KEY_ESCAPE and state == STATE_FACTION:
			_show_title()
		return
	var control_group := _control_group_index(key)
	if control_group >= 0:
		if key.ctrl_pressed or key.meta_pressed:
			battlefield.assign_control_group(control_group, key.shift_pressed)
		else:
			battlefield.recall_control_group(control_group, key.shift_pressed)
		return
	match key.keycode:
		KEY_ESCAPE:
			if (
				battlefield.attack_move_armed
				or battlefield.patrol_armed
				or battlefield.repair_armed
				or battlefield.placement_worker_id >= 0
			):
				battlefield.cancel_modes()
				_show_feedback("Command cancelled.", false)
			else:
				_toggle_pause()
		KEY_P:
			_toggle_pause()
		KEY_Q:
			battlefield.select_all_workers()
			_show_feedback("All workers selected.", false)
		KEY_E:
			battlefield.select_all_army()
			_show_feedback("Army selected.", false)
		KEY_SPACE:
			battlefield.select_player_stronghold()
		KEY_F:
			battlefield.begin_attack_move(key.shift_pressed)
		KEY_T:
			battlefield.begin_patrol(key.shift_pressed)
		KEY_R:
			battlefield.begin_repair(key.shift_pressed)
		KEY_X:
			simulation.command_stop(battlefield.selected_commandable_units())
			_show_feedback("Selected units halted.", false)


func _control_group_index(key: InputEventKey) -> int:
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	match code:
		KEY_0: return 0
		KEY_1: return 1
		KEY_2: return 2
		KEY_3: return 3
		KEY_4: return 4
		KEY_5: return 5
		KEY_6: return 6
		KEY_7: return 7
		KEY_8: return 8
		KEY_9: return 9
	return -1


func _clear_screen() -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = null
	battlefield = null
	_resource_label = null
	_faction_label = null
	_selection_title = null
	_selection_detail = null
	_feedback_label = null
	_pause_button = null
	_fog_button = null
	_minimap = null
	_command_buttons.clear()
	_result_overlay = null


func _make_screen() -> Control:
	_clear_screen()
	var result := Control.new()
	result.name = "Screen"
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.theme = ThemeFactory.create()
	add_child(result)
	_screen = result
	return result


func _add_title_background(root: Control, darkness: float = 0.38) -> void:
	var art := TextureRect.new()
	art.name = "GeneratedTitleArt"
	art.texture = TITLE_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.028, darkness)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)


func _show_title() -> void:
	state = STATE_TITLE
	paused = false
	simulation = null
	var root := _make_screen()
	_add_title_background(root, 0.42)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(520, 140)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-260, -70)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 22)
	root.add_child(content)

	var title := ThemeFactory.label("GAME TEMPLATE - RTS", 48, Color("fff0c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var play := ThemeFactory.button("START GAME")
	play.custom_minimum_size = Vector2(340, 56)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_show_faction_select)
	content.add_child(play)
	play.grab_focus()


func _show_faction_select() -> void:
	state = STATE_FACTION
	var root := _make_screen()
	_add_title_background(root, 0.72)

	var title := ThemeFactory.label("CHOOSE YOUR MANDATE", 32, Color("fff0c8"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22
	title.offset_bottom = 64
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := ThemeFactory.label("Food traditions differ: Celestials farm, Demons and Beasts hunt, and Humans can do both.", 16, ThemeFactory.MUTED)
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 65
	subtitle.offset_bottom = 96
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	var card_row := HBoxContainer.new()
	card_row.name = "FactionCards"
	card_row.set_anchors_preset(Control.PRESET_CENTER)
	card_row.position = Vector2(-590, -245)
	card_row.size = Vector2(1180, 500)
	card_row.add_theme_constant_override(&"separation", 14)
	root.add_child(card_row)

	for faction_id in FactionCatalog.ORDER:
		card_row.add_child(_make_faction_card(faction_id))

	var back := ThemeFactory.button("BACK")
	back.position = Vector2(20, 18)
	back.size = Vector2(110, 40)
	back.pressed.connect(_show_title)
	root.add_child(back)

	var controls := ThemeFactory.label("Controls: left select · drag box-select · right contextual order · F attack-move · X stop · Q workers · E army · Space stronghold · WASD / arrows camera · Cmd+wheel / pinch zoom", 14, ThemeFactory.MUTED)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 120
	controls.offset_right = -120
	controls.offset_top = -42
	controls.offset_bottom = -12
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(controls)


func _make_faction_card(faction_id: StringName) -> PanelContainer:
	var definition := FactionCatalog.definition(faction_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(284, 500)
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.025, 0.065, 0.067, 0.96), definition["accent"] as Color, 2, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)

	var portrait := TextureRect.new()
	portrait.texture = load(FactionCatalog.portrait_path(faction_id)) as Texture2D
	portrait.custom_minimum_size = Vector2(252, 258)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	column.add_child(portrait)
	var name_label := ThemeFactory.label(String(definition["name"]), 23, definition["accent"] as Color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var epithet := ThemeFactory.label(String(definition["epithet"]), 13, ThemeFactory.GOLD)
	epithet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(epithet)
	var identity := ThemeFactory.label(String(definition["identity"]), 15, ThemeFactory.PARCHMENT)
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(identity)
	var passive := ThemeFactory.label(String(definition["passive"]), 13, ThemeFactory.MUTED)
	passive.custom_minimum_size.y = 62
	passive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(passive)
	var button_spacer := Control.new()
	button_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(button_spacer)
	var choose := ThemeFactory.button("COMMAND %s" % String(definition["name"]).to_upper())
	choose.pressed.connect(func() -> void: _start_match(faction_id))
	column.add_child(choose)
	return panel


func _start_match(faction_id: StringName) -> void:
	selected_faction = faction_id
	state = STATE_MATCH
	paused = false
	simulation = RtsSimulation.new()
	simulation.setup(faction_id)
	simulation.match_ended.connect(_on_match_ended)
	simulation.battle_notice.connect(_on_battle_notice)
	var root := _make_screen()

	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield.set_simulation(simulation)
	battlefield.selection_changed.connect(_on_selection_changed)
	battlefield.feedback.connect(_show_feedback)
	root.add_child(battlefield)

	_build_top_bar(root)
	_build_bottom_hud(root)
	_build_help_panel(root)
	_build_minimap(root)
	_update_hud()
	_show_feedback("Harvest resources, build food production, and capture Yaoguai Dens before destroying the rival Stronghold.", false)


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_top = 10
	panel.offset_right = -12
	panel.offset_bottom = 62
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.025, 0.065, 0.067, 0.94), Color("456f67"), 1, 9))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	panel.add_child(row)
	_faction_label = ThemeFactory.label("", 19, ThemeFactory.GOLD)
	_faction_label.custom_minimum_size.x = 280
	row.add_child(_faction_label)
	_resource_label = ThemeFactory.label("", 16, Color("f4e8c7"))
	_resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_resource_label)
	_pause_button = ThemeFactory.button("PAUSE  P")
	_pause_button.custom_minimum_size.x = 120
	_pause_button.pressed.connect(_toggle_pause)
	row.add_child(_pause_button)


func _build_bottom_hud(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "CommandDeck"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_top = -151
	panel.offset_right = -12
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.022, 0.058, 0.061, 0.97), Color("456f67"), 1, 10))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	panel.add_child(row)

	var selection_box := VBoxContainer.new()
	selection_box.custom_minimum_size.x = 420
	selection_box.add_theme_constant_override(&"separation", 5)
	row.add_child(selection_box)
	_selection_title = ThemeFactory.label("No selection", 22, ThemeFactory.GOLD)
	selection_box.add_child(_selection_title)
	_selection_detail = ThemeFactory.label("Select a unit, structure, or resource.", 14, ThemeFactory.MUTED)
	_selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_box.add_child(_selection_detail)
	_feedback_label = ThemeFactory.label("", 14, ThemeFactory.JADE)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_box.add_child(_feedback_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var command_grid := GridContainer.new()
	command_grid.columns = 3
	command_grid.custom_minimum_size = Vector2(630, 116)
	command_grid.add_theme_constant_override(&"h_separation", 8)
	command_grid.add_theme_constant_override(&"v_separation", 8)
	row.add_child(command_grid)
	_add_command_button(command_grid, &"build", "BUILD WAR CAMP", func() -> void: _command_build(&"war_camp"))
	_add_command_button(command_grid, &"build_farm", "BUILD RICE FARM", func() -> void: _command_build(&"rice_farm"))
	_add_command_button(command_grid, &"build_lodge", "BUILD HUNTER'S LODGE", func() -> void: _command_build(&"hunters_lodge"))
	_add_command_button(command_grid, &"worker", "TRAIN WORKER", func() -> void: _command_train(&"worker"))
	_add_command_button(command_grid, &"hunter", "TRAIN HUNTER", func() -> void: _command_train(&"hunter"))
	_add_command_button(command_grid, &"vanguard", "TRAIN VANGUARD", func() -> void: _command_train(&"vanguard"))
	_add_command_button(command_grid, &"mystic", "TRAIN MYSTIC", func() -> void: _command_train(&"mystic"))
	_add_command_button(command_grid, &"jadeclaw", "CALL JADECLAW", func() -> void: _command_train(&"jadeclaw"))
	_add_command_button(command_grid, &"repair", "REPAIR  R", func() -> void: battlefield.begin_repair())
	_add_command_button(command_grid, &"patrol", "PATROL  T", func() -> void: battlefield.begin_patrol())
	_add_command_button(command_grid, &"cancel_queue", "CANCEL LAST", _command_cancel_training)


func _add_command_button(container: Control, id: StringName, text: String, action: Callable) -> void:
	var button := ThemeFactory.button(text)
	button.custom_minimum_size = Vector2(204, 52)
	button.pressed.connect(action)
	container.add_child(button)
	_command_buttons[id] = button


func _build_help_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Objective"
	panel.position = Vector2(14, 76)
	panel.size = Vector2(330, 122)
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.02, 0.05, 0.052, 0.82), Color("345d57"), 1, 8))
	root.add_child(panel)
	var text := ThemeFactory.label("OBJECTIVE\nUse your faction's farming or hunting tradition to supply Food. Hunters harvest roaming wildlife; boars and bears fight back. Claim Dens and destroy the rival Stronghold.", 13, ThemeFactory.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)


func _build_minimap(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "MinimapPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-250, 76)
	panel.size = Vector2(236, 225)
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.02, 0.05, 0.052, 0.94), Color("456f67"), 1, 8))
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	panel.add_child(column)
	var title := ThemeFactory.label("JADE MERIDIAN", 13, ThemeFactory.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_minimap = BATTLEFIELD_MINIMAP.new()
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = Vector2(208, 132)
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.set_battlefield(battlefield)
	column.add_child(_minimap)

	_fog_button = ThemeFactory.button("FOG OF WAR  ON", "Toggle battlefield and minimap fog of war")
	_fog_button.name = "FogToggle"
	_fog_button.custom_minimum_size.y = 36
	_fog_button.pressed.connect(_toggle_fog_of_war)
	column.add_child(_fog_button)


func _update_hud() -> void:
	if simulation == null or simulation.players.is_empty() or _resource_label == null:
		return
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var enemy := simulation.players[RtsSimulation.TEAM_ENEMY]
	var player_definition := FactionCatalog.definition(player["faction"] as StringName)
	var enemy_definition := FactionCatalog.definition(enemy["faction"] as StringName)
	_faction_label.text = "%s  vs  %s" % [player_definition["name"], enemy_definition["name"]]
	_faction_label.add_theme_color_override(&"font_color", player_definition["accent"] as Color)
	var minutes := floori(simulation.elapsed_time / 60.0)
	var seconds := int(simulation.elapsed_time) % 60
	_resource_label.text = "JADE %d    LUMBER %d    ESSENCE %d    FOOD %d (+%.1f/s)    POP %d/%d    DENS %d/%d    %02d:%02d" % [
		int(player["jade"]),
		int(player["lumber"]),
		int(player["essence"]),
		int(player["food"]),
		simulation.food_income_per_second(RtsSimulation.TEAM_PLAYER),
		int(player["population"]),
		int(player["population_cap"]),
		simulation.captured_cave_count(RtsSimulation.TEAM_PLAYER),
		MapCatalog.CAVES.size(),
		minutes,
		seconds,
	]
	_update_selection_text()
	_update_commands()


func _on_selection_changed(_ids: Array) -> void:
	_update_hud()


func _update_selection_text() -> void:
	if battlefield == null or _selection_title == null:
		return
	var ids := battlefield.selected_ids
	if ids.is_empty():
		_selection_title.text = "No selection"
		_selection_detail.text = "Left-click a unit, structure, or animal. Select Hunters and right-click wildlife to hunt for Food."
		return
	if ids.size() > 1:
		var workers := 0
		var hunters := 0
		var vanguards := 0
		var mystics := 0
		var jadeclaws := 0
		for id in ids:
			match simulation.entity(id).get("kind"):
				&"worker": workers += 1
				&"hunter": hunters += 1
				&"vanguard": vanguards += 1
				&"mystic": mystics += 1
				&"jadeclaw": jadeclaws += 1
		_selection_title.text = "%d units selected" % ids.size()
		_selection_detail.text = "Workers %d  ·  Hunters %d  ·  Vanguards %d  ·  Mystics %d  ·  Jadeclaws %d\nF: attack-move  ·  T: patrol  ·  R: repair  ·  X: stop  ·  Shift: queue" % [workers, hunters, vanguards, mystics, jadeclaws]
		return
	var entity_state := simulation.entity(ids[0])
	if entity_state.is_empty():
		return
	if entity_state.get("category") == &"resource":
		match entity_state.get("resource_kind"):
			&"jade":
				_selection_title.text = "Jade Outcrop"
			&"lumber":
				_selection_title.text = "Lumber Tree"
			_:
				_selection_title.text = "Essence Shrine"
		_selection_detail.text = "%d remaining · Select workers and right-click this node to gather." % int(entity_state.get("amount", 0.0))
		return
	if entity_state.get("category") == &"wildlife":
		var wildlife_stats := FactionCatalog.stats(entity_state["kind"] as StringName, &"neutral")
		_selection_title.text = String(wildlife_stats["name"])
		var reaction := "Fights back when attacked" if bool(entity_state.get("retaliates", false)) else "Flees when attacked"
		_selection_detail.text = "%s · %d / %d health\n%s · Hunt bounty: %d Food." % [
			wildlife_stats["role"],
			int(entity_state["hp"]),
			int(entity_state["max_hp"]),
			reaction,
			int(entity_state.get("food_bounty", 0)),
		]
		return
	if entity_state.get("kind") == &"yaoguai_den":
		_selection_title.text = "Yaoguai Den"
		var owner := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
		var guardians := simulation.cave_guardian_count(int(entity_state["id"]))
		var cave_detail := ""
		if guardians > 0:
			cave_detail = "Guarded neutral objective · %d Jadeclaws remain. Hunt them for 45 Jade, 30 Lumber, and 25 Essence each." % guardians
		elif owner == RtsSimulation.TEAM_NEUTRAL:
			cave_detail = "Cleared neutral objective · Hold the ring with military units for 6 seconds to capture it."
		elif owner == RtsSimulation.TEAM_PLAYER:
			cave_detail = "Controlled by your faction · Produces durable Jadeclaws for 90 Jade, 55 Essence, and 65 Food."
		else:
			cave_detail = "Controlled by the rival · Hold the ring uncontested for 6 seconds to seize it."
		if bool(entity_state.get("capture_contested", false)):
			cave_detail += "\nCapture contested."
		elif float(entity_state.get("capture_progress", 0.0)) > 0.0:
			var capture_percent := int(100.0 * float(entity_state["capture_progress"]) / RtsSimulation.CAVE_CAPTURE_SECONDS)
			var capturing_side := "your forces" if int(entity_state.get("capture_team", -1)) == RtsSimulation.TEAM_PLAYER else "the rival"
			cave_detail += "\nCapture %d%% · %s." % [capture_percent, capturing_side]
		var cave_queue := entity_state.get("queue", []) as Array
		if not cave_queue.is_empty():
			var cave_item := cave_queue[0] as Dictionary
			cave_detail += "\nCalling Jadeclaw · %.1fs · Queue %d" % [float(cave_item["remaining"]), cave_queue.size()]
		_selection_detail.text = cave_detail
		return
	var stats := FactionCatalog.stats(entity_state["kind"] as StringName, entity_state["faction"] as StringName)
	_selection_title.text = String(stats["name"])
	var hp_text := "%d / %d health" % [int(entity_state["hp"]), int(entity_state["max_hp"])]
	var detail := "%s\n%s · Order: %s" % [stats["role"], hp_text, String(entity_state.get("order", &"idle")).capitalize()]
	if entity_state.get("category") == &"unit":
		var command_queue := entity_state.get("command_queue", []) as Array
		if not command_queue.is_empty():
			detail += " · Orders queued: %d" % command_queue.size()
	if entity_state.get("category") == &"structure":
		var completion := float(entity_state.get("complete", 1.0))
		if completion < 1.0:
			detail += " · Construction %d%%" % int(completion * 100.0)
		var queue := entity_state.get("queue", []) as Array
		if not queue.is_empty():
			var item := queue[0] as Dictionary
			detail += "\nTraining %s · %.1fs · Queue %d" % [String(item["kind"]).capitalize(), float(item["remaining"]), queue.size()]
		if entity_state.get("kind") in RtsSimulation.FOOD_PRODUCER_KINDS and completion >= 1.0:
			var food_yield := int(stats.get("food_yield", 0))
			var interval := float(stats.get("food_interval", 1.0))
			var next_harvest := maxf(0.0, interval - float(entity_state.get("food_timer", 0.0)))
			detail += "\nHarvest: +%d Food every %.0fs · next in %.1fs" % [food_yield, interval, next_harvest]
	elif entity_state.get("kind") == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
		detail += "\nCarrying %d %s" % [int(entity_state["cargo_amount"]), String(entity_state["cargo_kind"]).capitalize()]
	_selection_detail.text = detail


func _update_commands() -> void:
	if battlefield == null or _command_buttons.is_empty():
		return
	var selected_structure := battlefield.primary_selected_structure()
	var has_worker := false
	var has_military := false
	for id in battlefield.selected_ids:
		var selected_entity := simulation.entity(id)
		if selected_entity.get("kind") == &"worker":
			has_worker = true
		elif selected_entity.get("kind") in [&"vanguard", &"mystic", &"jadeclaw"]:
			has_military = true
	var structure := simulation.entity(selected_structure) if selected_structure >= 0 else {}
	var player_faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var build_commands := {
		&"build": &"war_camp",
		&"build_farm": &"rice_farm",
		&"build_lodge": &"hunters_lodge",
	}
	for button_id in build_commands:
		var structure_kind := build_commands[button_id] as StringName
		var build_stats := FactionCatalog.stats(structure_kind, player_faction)
		var build_button := _command_buttons[button_id] as Button
		build_button.visible = has_worker and simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, structure_kind)
		build_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, structure_kind)
		build_button.text = "BUILD %s\n%s" % [String(build_stats["name"]).to_upper(), _short_cost(build_stats)]
		build_button.tooltip_text = _long_cost(build_stats)

	var worker_button := _command_buttons[&"worker"] as Button
	worker_button.visible = not structure.is_empty() and structure.get("kind") == &"stronghold"
	worker_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"worker") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"worker")
	var worker_stats := FactionCatalog.stats(&"worker", player_faction)
	worker_button.text = "TRAIN WORKER\n%s" % _short_cost(worker_stats)
	worker_button.tooltip_text = _long_cost(worker_stats)
	var hunter_button := _command_buttons[&"hunter"] as Button
	hunter_button.visible = (
		not structure.is_empty()
		and structure.get("kind") == &"hunters_lodge"
		and float(structure.get("complete", 0.0)) >= 1.0
		and simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"hunter")
	)
	hunter_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"hunter") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"hunter")
	var hunter_stats := FactionCatalog.stats(&"hunter", player_faction)
	hunter_button.text = "TRAIN HUNTER\n%s" % _short_cost(hunter_stats)
	hunter_button.tooltip_text = _long_cost(hunter_stats)
	var vanguard_button := _command_buttons[&"vanguard"] as Button
	vanguard_button.visible = not structure.is_empty() and structure.get("kind") == &"war_camp" and float(structure.get("complete", 0.0)) >= 1.0
	vanguard_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"vanguard") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"vanguard")
	var vanguard_stats := FactionCatalog.stats(&"vanguard", player_faction)
	vanguard_button.text = "TRAIN VANGUARD\n%s" % _short_cost(vanguard_stats)
	vanguard_button.tooltip_text = _long_cost(vanguard_stats)
	var mystic_button := _command_buttons[&"mystic"] as Button
	mystic_button.visible = vanguard_button.visible
	mystic_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"mystic") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"mystic")
	var mystic_stats := FactionCatalog.stats(&"mystic", player_faction)
	mystic_button.text = "TRAIN MYSTIC\n%s" % _short_cost(mystic_stats)
	mystic_button.tooltip_text = _long_cost(mystic_stats)
	var jadeclaw_button := _command_buttons[&"jadeclaw"] as Button
	jadeclaw_button.visible = not structure.is_empty() and structure.get("kind") == &"yaoguai_den"
	jadeclaw_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"jadeclaw") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"jadeclaw")
	var jadeclaw_stats := FactionCatalog.stats(&"jadeclaw", player_faction)
	jadeclaw_button.text = "CALL JADECLAW\n%s" % _short_cost(jadeclaw_stats)
	jadeclaw_button.tooltip_text = _long_cost(jadeclaw_stats)

	var repair_button := _command_buttons[&"repair"] as Button
	repair_button.visible = has_worker
	repair_button.disabled = false
	repair_button.tooltip_text = "Repair a damaged allied structure · 15 health per 1 Lumber"
	var patrol_button := _command_buttons[&"patrol"] as Button
	patrol_button.visible = has_military
	patrol_button.disabled = false
	patrol_button.tooltip_text = "Patrol repeatedly between the unit's position and a destination"
	var cancel_button := _command_buttons[&"cancel_queue"] as Button
	var production_queue := structure.get("queue", []) as Array if not structure.is_empty() else []
	cancel_button.visible = not production_queue.is_empty()
	cancel_button.disabled = production_queue.is_empty()
	if not production_queue.is_empty():
		var queued_item := production_queue[-1] as Dictionary
		cancel_button.text = "CANCEL LAST\n%s" % String(queued_item.get("kind", &"unit")).to_upper()
		cancel_button.tooltip_text = "Refund the newest queued unit and release its reserved population"


func _short_cost(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", "J"],
		["lumber_cost", "L"],
		["essence_cost", "E"],
		["food_cost", "F"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append("%d%s" % [amount, definition[1]])
	return " · ".join(parts) if not parts.is_empty() else "FREE"


func _long_cost(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", "Jade"],
		["lumber_cost", "Lumber"],
		["essence_cost", "Essence"],
		["food_cost", "Food"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append("%d %s" % [amount, definition[1]])
	return " · ".join(parts) if not parts.is_empty() else "Free"


func _command_build(structure_kind: StringName) -> void:
	battlefield.begin_structure_placement(structure_kind)


func _command_train(kind: StringName) -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback("Select the correct production structure.", true)
		return
	if simulation.command_train(structure_id, kind):
		_show_feedback("%s added to the training queue." % String(kind).capitalize(), false)
	else:
		_show_feedback("Insufficient resources, Food, population, or production capacity.", true)


func _command_cancel_training() -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback("Select a production structure with a queued unit.", true)
		return
	var cancelled := simulation.command_cancel_training(
		structure_id,
		RtsSimulation.TEAM_PLAYER,
	)
	if cancelled.is_empty():
		_show_feedback("There is no queued unit to cancel.", true)
		return
	var costs := cancelled.get("costs", {}) as Dictionary
	var refund_parts: Array[String] = []
	for definition in [
		["jade", "J"],
		["lumber", "L"],
		["essence", "E"],
		["food", "F"],
	]:
		var amount := int(costs.get(definition[0], 0))
		if amount > 0:
			refund_parts.append("%d%s" % [amount, definition[1]])
	_show_feedback(
		"Cancelled %s · refunded %s." % [
			String(cancelled.get("kind", &"unit")).capitalize(),
			" · ".join(refund_parts),
		],
		false,
	)


func _on_battle_notice(message: String, team: int) -> void:
	if team == RtsSimulation.TEAM_PLAYER or message.begins_with("The rival"):
		_show_feedback(message, false)
	elif message.contains("cleared"):
		_show_feedback("The rival cleared a Yaoguai Den and can now capture it.", false)
	elif message.contains("Food"):
		_show_feedback("The rival completed a wildlife hunt.", false)
	else:
		_show_feedback("The rival claimed a Jadeclaw bounty.", false)


func _show_feedback(message: String, is_error: bool = false) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = message
	_feedback_label.add_theme_color_override(&"font_color", ThemeFactory.DANGER if is_error else ThemeFactory.JADE)
	_feedback_timer = 3.0


func _toggle_pause() -> void:
	if state != STATE_MATCH or simulation == null or not simulation.outcome.is_empty():
		return
	paused = not paused
	_pause_button.text = "RESUME  P" if paused else "PAUSE  P"
	_show_feedback("The realm is paused." if paused else "The realm resumes its poor decisions.", false)


func _toggle_fog_of_war() -> void:
	if battlefield == null:
		return
	battlefield.set_fog_enabled(not battlefield.fog_enabled)
	_fog_button.text = "FOG OF WAR  ON" if battlefield.fog_enabled else "FOG OF WAR  OFF"
	_show_feedback("Fog of war enabled." if battlefield.fog_enabled else "Fog of war disabled.", false)


func _on_match_ended(result: StringName) -> void:
	paused = true
	state = STATE_RESULT
	_result_overlay = Control.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_result_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-235, -150)
	var accent := ThemeFactory.JADE if result == &"victory" else ThemeFactory.DANGER
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.025, 0.065, 0.067, 0.98), accent, 2, 14))
	_result_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 13)
	panel.add_child(column)
	var title := ThemeFactory.label("MANDATE SECURED" if result == &"victory" else "THE MANDATE IS LOST", 30, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := ThemeFactory.label(
		"The rival Stronghold has fallen." if result == &"victory" else "Your Stronghold has fallen. Bureaucracy remains undefeated.",
		17,
		ThemeFactory.PARCHMENT,
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var elapsed_seconds := int(simulation.elapsed_time)
	var elapsed_minutes := floori(simulation.elapsed_time / 60.0)
	var time_label := ThemeFactory.label("Skirmish time: %02d:%02d" % [elapsed_minutes, elapsed_seconds % 60], 15, ThemeFactory.MUTED)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(time_label)
	var rematch := ThemeFactory.button("REMATCH")
	rematch.pressed.connect(func() -> void: _start_match(selected_faction))
	column.add_child(rematch)
	var choose := ThemeFactory.button("CHOOSE ANOTHER FACTION")
	choose.pressed.connect(_show_faction_select)
	column.add_child(choose)
	var title_button := ThemeFactory.button("RETURN TO TITLE")
	title_button.pressed.connect(_show_title)
	column.add_child(title_button)
	rematch.grab_focus()
