extends Node

const STATE_TITLE := &"title"
const STATE_FACTION := &"faction"
const STATE_MATCH := &"match"
const STATE_RESULT := &"result"
const TITLE_ART := preload("res://assets/runtime/ui/mandate_of_myth_title.webp")

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
	match key.keycode:
		KEY_ESCAPE:
			if battlefield.attack_move_armed or battlefield.placement_worker_id >= 0:
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
		KEY_A:
			battlefield.begin_attack_move()
		KEY_S:
			simulation.command_stop(battlefield.selected_commandable_units())
			_show_feedback("Selected units halted.", false)


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
	_add_title_background(root, 0.34)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.025, 0.065, 0.067, 0.9), Color("d2b764"), 2, 14))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -165)
	root.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 13)
	panel.add_child(content)

	var overline := ThemeFactory.label("A CHINESE MYTHOLOGY REAL-TIME STRATEGY GAME", 14, ThemeFactory.GOLD)
	overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(overline)
	var title := ThemeFactory.label("MANDATE OF MYTH", 42, Color("fff0c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := ThemeFactory.label("Four hosts. One Jade Meridian. Predictable administrative violence.", 17, ThemeFactory.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)
	var rule := HSeparator.new()
	content.add_child(rule)
	var play := ThemeFactory.button("ENTER THE JADE MERIDIAN", "Choose a faction and begin a skirmish")
	play.custom_minimum_size.y = 52
	play.pressed.connect(_show_faction_select)
	content.add_child(play)
	var guide := ThemeFactory.label("10–15 minute skirmish · Economy · Base building · Army control · AI opponent", 14, ThemeFactory.MUTED)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(guide)

	var footer := ThemeFactory.label("Built in Godot 4.7 · All representational art generated with GPT Image 2", 13, Color(0.82, 0.86, 0.8, 0.86))
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38
	footer.offset_bottom = -12
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)
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
	var subtitle := ThemeFactory.label("Each host shares the same core army. Their passive changes how the war breathes.", 16, ThemeFactory.MUTED)
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

	var controls := ThemeFactory.label("Controls: left select · drag box-select · right contextual order · A attack-move · Q workers · E army · Space stronghold · middle-drag / arrows camera · wheel zoom", 14, ThemeFactory.MUTED)
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
	_update_hud()
	_show_feedback("Harvest. Build. Raise an army. Destroy the rival Stronghold.", false)


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
	_faction_label.custom_minimum_size.x = 330
	row.add_child(_faction_label)
	_resource_label = ThemeFactory.label("", 18, Color("f4e8c7"))
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
	command_grid.columns = 2
	command_grid.custom_minimum_size = Vector2(420, 116)
	command_grid.add_theme_constant_override(&"h_separation", 8)
	command_grid.add_theme_constant_override(&"v_separation", 8)
	row.add_child(command_grid)
	_add_command_button(command_grid, &"build", "BUILD WAR CAMP\n180 Jade · 40 Essence", _command_build)
	_add_command_button(command_grid, &"worker", "TRAIN WORKER\n55 Jade", func() -> void: _command_train(&"worker"))
	_add_command_button(command_grid, &"vanguard", "TRAIN VANGUARD\n75 Jade", func() -> void: _command_train(&"vanguard"))
	_add_command_button(command_grid, &"mystic", "TRAIN MYSTIC\n50 Jade · 65 Essence", func() -> void: _command_train(&"mystic"))


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
	panel.size = Vector2(310, 80)
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color(0.02, 0.05, 0.052, 0.82), Color("345d57"), 1, 8))
	root.add_child(panel)
	var text := ThemeFactory.label("OBJECTIVE\nDestroy the rival Stronghold. The AI receives a disclosed income stipend, but no combat bonuses.", 13, ThemeFactory.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)


func _update_hud() -> void:
	if simulation == null or simulation.players.is_empty() or _resource_label == null:
		return
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var enemy := simulation.players[RtsSimulation.TEAM_ENEMY]
	var player_definition := FactionCatalog.definition(player["faction"] as StringName)
	var enemy_definition := FactionCatalog.definition(enemy["faction"] as StringName)
	_faction_label.text = "%s  vs  %s" % [player_definition["name"], enemy_definition["name"]]
	_faction_label.add_theme_color_override(&"font_color", player_definition["accent"] as Color)
	var minutes := int(simulation.elapsed_time) / 60
	var seconds := int(simulation.elapsed_time) % 60
	_resource_label.text = "JADE  %d     ESSENCE  %d     POPULATION  %d / %d     %02d:%02d" % [
		int(player["jade"]),
		int(player["essence"]),
		int(player["population"]),
		int(player["population_cap"]),
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
		_selection_detail.text = "Left-click a unit or structure. Drag to select an army. Right-click to move, gather, attack, or set a rally point."
		return
	if ids.size() > 1:
		var workers := 0
		var vanguards := 0
		var mystics := 0
		for id in ids:
			match simulation.entity(id).get("kind"):
				&"worker": workers += 1
				&"vanguard": vanguards += 1
				&"mystic": mystics += 1
		_selection_title.text = "%d units selected" % ids.size()
		_selection_detail.text = "Workers %d  ·  Vanguards %d  ·  Mystics %d\nA: attack-move  ·  S: stop" % [workers, vanguards, mystics]
		return
	var entity_state := simulation.entity(ids[0])
	if entity_state.is_empty():
		return
	if entity_state.get("category") == &"resource":
		_selection_title.text = "Jade Outcrop" if entity_state.get("resource_kind") == &"jade" else "Essence Shrine"
		_selection_detail.text = "%d remaining · Select workers and right-click this node to gather." % int(entity_state.get("amount", 0.0))
		return
	var stats := FactionCatalog.stats(entity_state["kind"] as StringName, entity_state["faction"] as StringName)
	_selection_title.text = String(stats["name"])
	var hp_text := "%d / %d health" % [int(entity_state["hp"]), int(entity_state["max_hp"])]
	var detail := "%s\n%s · Order: %s" % [stats["role"], hp_text, String(entity_state.get("order", &"idle")).capitalize()]
	if entity_state.get("category") == &"structure":
		var completion := float(entity_state.get("complete", 1.0))
		if completion < 1.0:
			detail += " · Construction %d%%" % int(completion * 100.0)
		var queue := entity_state.get("queue", []) as Array
		if not queue.is_empty():
			var item := queue[0] as Dictionary
			detail += "\nTraining %s · %.1fs · Queue %d" % [String(item["kind"]).capitalize(), float(item["remaining"]), queue.size()]
	elif entity_state.get("kind") == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
		detail += "\nCarrying %d %s" % [int(entity_state["cargo_amount"]), String(entity_state["cargo_kind"]).capitalize()]
	_selection_detail.text = detail


func _update_commands() -> void:
	if battlefield == null or _command_buttons.is_empty():
		return
	var selected_structure := battlefield.primary_selected_structure()
	var has_worker := false
	for id in battlefield.selected_ids:
		if simulation.entity(id).get("kind") == &"worker":
			has_worker = true
	var structure := simulation.entity(selected_structure) if selected_structure >= 0 else {}
	var player_faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var camp_stats := FactionCatalog.stats(&"war_camp", player_faction)
	var build_button := _command_buttons[&"build"] as Button
	build_button.visible = has_worker
	build_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"war_camp")
	build_button.text = "BUILD WAR CAMP\n%d Jade · %d Essence" % [camp_stats["jade_cost"], camp_stats["essence_cost"]]

	var worker_button := _command_buttons[&"worker"] as Button
	worker_button.visible = not structure.is_empty() and structure.get("kind") == &"stronghold"
	worker_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"worker") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"worker")
	var vanguard_button := _command_buttons[&"vanguard"] as Button
	vanguard_button.visible = not structure.is_empty() and structure.get("kind") == &"war_camp" and float(structure.get("complete", 0.0)) >= 1.0
	vanguard_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"vanguard") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"vanguard")
	var mystic_button := _command_buttons[&"mystic"] as Button
	mystic_button.visible = vanguard_button.visible
	mystic_button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, &"mystic") or not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, &"mystic")


func _command_build() -> void:
	battlefield.begin_war_camp_placement()


func _command_train(kind: StringName) -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback("Select the correct production structure.", true)
		return
	if simulation.command_train(structure_id, kind):
		_show_feedback("%s added to the training queue." % String(kind).capitalize(), false)
	else:
		_show_feedback("Insufficient resources, population, or production capacity.", true)


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
	var time_label := ThemeFactory.label("Skirmish time: %02d:%02d" % [int(simulation.elapsed_time) / 60, int(simulation.elapsed_time) % 60], 15, ThemeFactory.MUTED)
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
