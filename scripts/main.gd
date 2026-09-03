extends Node

const STATE_TITLE := &"title"
const STATE_FACTION := &"faction"
const STATE_MATCH := &"match"
const STATE_RESULT := &"result"
const TITLE_ART := preload("res://assets/runtime/ui/mandate_of_myth_title.webp")
const BATTLEFIELD_MINIMAP := preload("res://scripts/view/battlefield_minimap.gd")
const HUD_ICON := preload("res://scripts/ui/hud_icon.gd")
const HUD_COMMAND_BUTTON := preload("res://scripts/ui/hud_command_button.gd")
const LEADERBOARD_STORE_SCRIPT := preload("res://scripts/services/leaderboard_store.gd")
const LEADERBOARD_BRIDGE_SCRIPT := preload("res://scripts/services/leaderboard_bridge.gd")
const LEADERBOARD_DIALOG_SCRIPT := preload("res://scripts/ui/leaderboard_dialog.gd")
const PERSISTENT_COMMAND_IDS: Array[StringName] = [
	&"build",
	&"build_farm",
	&"build_lodge",
	&"build_wall",
	&"build_gate",
	&"build_tower",
	&"move",
	&"attack_move",
	&"patrol",
	&"repair",
	&"rally",
]
const COMMAND_VISIBLE_META := &"command_visible_for_update"
const ARMED_TOOLTIP_SUFFIX := "\nARMED · Click again or Esc cancels"
const RESOURCE_ICON_TEXTURES := {
	&"jade": preload("res://assets/runtime/ui/resource_icons/jade.png"),
	&"lumber": preload("res://assets/runtime/ui/resource_icons/lumber.png"),
	&"essence": preload("res://assets/runtime/ui/resource_icons/essence.png"),
	&"food": preload("res://assets/runtime/ui/resource_icons/food.png"),
	&"population": preload("res://assets/runtime/ui/resource_icons/population.png"),
	&"dens": preload("res://assets/runtime/ui/resource_icons/dens.png"),
}
const HUD_UTILITY_ICON_TEXTURES := {
	&"pause": preload("res://assets/runtime/ui/utility_icons/pause.png"),
	&"resume": preload("res://assets/runtime/ui/utility_icons/resume.png"),
	&"audio_on": preload("res://assets/runtime/ui/utility_icons/audio_on.png"),
	&"audio_muted": preload("res://assets/runtime/ui/utility_icons/audio_muted.png"),
}

var state: StringName = STATE_TITLE
var selected_faction: StringName = &"human"
var paused := false
var simulation: RtsSimulation
var battlefield: Battlefield
var _screen: Control
var _resource_label: Label
var _score_label: Label
var _resource_values: Dictionary = {}
var _resource_icons: Dictionary = {}
var _selection_title: Label
var _selection_detail: Label
var _selection_portrait: TextureRect
var _selection_portrait_frame: PanelContainer
var _selection_health: ProgressBar
var _selection_health_label: Label
var _selection_status: Label
var _selection_order: Label
var _selection_meta: Label
var _selection_stacks: HBoxContainer
var _queue_panel: PanelContainer
var _queue_tiles: Array[Button] = []
var _feedback_label: Label
var _toast_panel: PanelContainer
var _pause_overlay: Control
var _pause_menu: PanelContainer
var _settings_menu: PanelContainer
var _resume_button: Button
var _settings_button: Button
var _resign_button: Button
var _settings_audio_button: Button
var _settings_back_button: Button
var _pause_button: Button
var _audio_button: Button
var _fog_button: Button
var _fog_icon: HudIcon
var _minimap: Control
var _objective_panel: PanelContainer
var _objective_rows: Array[Label] = []
var _objective_collapsed := false
var _objective_toggle: Button
var _command_deck: PanelContainer
var _command_grid: GridContainer
var _command_slots: Array[Control] = []
var _command_buttons: Dictionary = {}
var _command_mode_group: ButtonGroup
var _hud_timer := 0.0
var _feedback_timer := 0.0
var _result_overlay: Control
var _leaderboard_dialog: LeaderboardDialog
var _leaderboard_button: Button
var _result_leaderboard_button: Button
var _match_score_recorded := false
var audio_director: AudioDirector
var leaderboard_store: LeaderboardStore
var leaderboard_bridge: LeaderboardBridge
var leaderboard_save_path: String = LeaderboardStore.SAVE_PATH


func _ready() -> void:
	leaderboard_store = LEADERBOARD_STORE_SCRIPT.new() as LeaderboardStore
	leaderboard_store.name = "LeaderboardStore"
	add_child(leaderboard_store)
	leaderboard_store.setup(leaderboard_save_path)
	leaderboard_bridge = LEADERBOARD_BRIDGE_SCRIPT.new() as LeaderboardBridge
	leaderboard_bridge.name = "LeaderboardBridge"
	add_child(leaderboard_bridge)
	leaderboard_bridge.state_changed.connect(_on_leaderboard_state_changed)
	leaderboard_bridge.callsign_sync_changed.connect(_on_callsign_sync_changed)
	leaderboard_bridge.setup(leaderboard_store)
	audio_director = AudioDirector.new()
	audio_director.name = "AudioDirector"
	add_child(audio_director)
	var game_window := get_window()
	game_window.mouse_entered.connect(CursorSystem.resume)
	game_window.mouse_exited.connect(CursorSystem.suspend)
	CursorSystem.resume()
	_show_title()


func _exit_tree() -> void:
	CursorSystem.suspend()


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
			_toast_panel.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	audio_director.ensure_bgm()
	if _leaderboard_dialog != null and _leaderboard_dialog.visible:
		if key.keycode == KEY_ESCAPE:
			audio_director.play_ui(&"ui_cancel")
			_leaderboard_dialog.close_dialog()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_M:
		_toggle_audio()
		return
	if state != STATE_MATCH or battlefield == null:
		if key.keycode == KEY_ESCAPE and state == STATE_FACTION:
			audio_director.play_ui(&"ui_cancel")
			_show_title()
		return
	if paused:
		match key.keycode:
			KEY_ESCAPE:
				if _settings_menu != null and _settings_menu.visible:
					_show_pause_menu()
				else:
					_set_paused(false)
			KEY_P:
				_set_paused(false)
		get_viewport().set_input_as_handled()
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
				battlefield.move_armed
				or battlefield.attack_move_armed
				or battlefield.patrol_armed
				or battlefield.repair_armed
				or battlefield.rally_armed
				or battlefield.placement_worker_id >= 0
			):
				battlefield.cancel_modes()
				audio_director.play_ui(&"ui_cancel")
				_update_armed_command_styles()
				_show_feedback("Command cancelled.", false)
			elif not battlefield.selected_ids.is_empty():
				battlefield.select_entities([])
			else:
				_toggle_pause()
		KEY_P:
			_toggle_pause()
		KEY_Q:
			battlefield.select_all_workers()
			_show_feedback("All workers selected.", false)
		KEY_I:
			battlefield.select_all_idle_workers()
			_show_feedback("Idle workers selected.", false)
		KEY_E:
			battlefield.select_all_army()
			_show_feedback("Army selected.", false)
		KEY_SPACE:
			battlefield.select_player_stronghold()
		KEY_F:
			battlefield.begin_attack_move(key.shift_pressed)
			_update_armed_command_styles()
		KEY_T:
			battlefield.begin_patrol(key.shift_pressed)
			_update_armed_command_styles()
		KEY_R:
			battlefield.begin_repair(key.shift_pressed)
			_update_armed_command_styles()
		KEY_X:
			simulation.command_stop(RtsSimulation.TEAM_PLAYER, battlefield.selected_commandable_units())
			audio_director.play_ui(&"ui_cancel")
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
	_score_label = null
	_resource_values.clear()
	_resource_icons.clear()
	_selection_title = null
	_selection_detail = null
	_selection_portrait = null
	_selection_portrait_frame = null
	_selection_health = null
	_selection_health_label = null
	_selection_status = null
	_selection_order = null
	_selection_meta = null
	_selection_stacks = null
	_queue_panel = null
	_queue_tiles.clear()
	_feedback_label = null
	_toast_panel = null
	_pause_overlay = null
	_pause_menu = null
	_settings_menu = null
	_resume_button = null
	_settings_button = null
	_resign_button = null
	_settings_audio_button = null
	_settings_back_button = null
	_pause_button = null
	_audio_button = null
	_fog_button = null
	_fog_icon = null
	_minimap = null
	_objective_panel = null
	_objective_rows.clear()
	_objective_toggle = null
	_command_deck = null
	_command_grid = null
	_command_slots.clear()
	_command_buttons.clear()
	_command_mode_group = null
	_result_overlay = null
	_leaderboard_dialog = null
	_leaderboard_button = null
	_result_leaderboard_button = null


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
	audio_director.set_music_state(STATE_TITLE)
	audio_director.ensure_bgm()
	var root := _make_screen()
	_add_title_background(root, 0.42)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(520, 218)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-260, -109)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 22)
	root.add_child(content)

	var title := ThemeFactory.label("GAME TEMPLATE - RTS", 48, Color("fff0c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var play := ThemeFactory.button("START GAME")
	play.custom_minimum_size = Vector2(340, 56)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_connect_button(play, _show_faction_select)
	content.add_child(play)
	_leaderboard_button = ThemeFactory.button("LEADERBOARD", "View local and global rankings")
	_leaderboard_button.name = "TitleLeaderboardButton"
	_leaderboard_button.custom_minimum_size = Vector2(340, 48)
	_leaderboard_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_connect_button(_leaderboard_button, func() -> void: _open_leaderboard(_leaderboard_button))
	content.add_child(_leaderboard_button)
	_build_leaderboard_dialog(root)
	play.grab_focus()


func _show_faction_select() -> void:
	state = STATE_FACTION
	audio_director.set_music_state(STATE_FACTION)
	var root := _make_screen()
	_add_title_background(root, 0.72)

	var title := ThemeFactory.label("CHOOSE YOUR FACTION", 32, Color("fff0c8"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22
	title.offset_bottom = 64
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

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
	_connect_button(back, _show_title, &"ui_cancel")
	root.add_child(back)

	var controls := ThemeFactory.label("Controls: left select / inspect · drag box-select · right contextual order · Esc clear · F attack-move · X stop · Q workers · I idle workers · E army · Space stronghold · WASD / arrows camera · Cmd+wheel / pinch zoom", 14, ThemeFactory.MUTED)
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
	_connect_button(choose, func() -> void: _start_match(faction_id))
	column.add_child(choose)
	if faction_id == FactionCatalog.ORDER[0]:
		choose.call_deferred("grab_focus")
	return panel


func _start_match(faction_id: StringName) -> void:
	selected_faction = faction_id
	state = STATE_MATCH
	paused = false
	_match_score_recorded = false
	audio_director.set_music_state(STATE_MATCH)
	audio_director.ensure_bgm()
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
	battlefield.audio_cue.connect(audio_director.play_cue)
	battlefield.simulation_event.connect(audio_director.handle_simulation_event)
	root.add_child(battlefield)

	_build_top_bar(root)
	_build_bottom_hud(root)
	_build_help_panel(root)
	_build_leaderboard_dialog(root)
	_update_hud()
	_show_feedback("Harvest resources, build food production, and capture Yaoguai Dens before destroying the rival Stronghold.", false)


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 8
	panel.offset_top = 6
	panel.offset_right = -8
	panel.offset_bottom = 56
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_deck_style(ThemeFactory.GOLD))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	panel.add_child(row)
	_score_label = ThemeFactory.label("SCORE: 0", 14, ThemeFactory.GOLD)
	_score_label.name = "ScoreLabel"
	_score_label.custom_minimum_size.x = 222
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_score_label)
	_add_resource_chip(row, &"jade", &"jade", "JADE", ThemeFactory.JADE, 88.0)
	_add_resource_chip(row, &"lumber", &"lumber", "LUMBER", ThemeFactory.LUMBER, 100.0)
	_add_resource_chip(row, &"essence", &"essence", "ESSENCE", ThemeFactory.ESSENCE, 108.0)
	_add_resource_chip(row, &"food", &"food", "FOOD", ThemeFactory.FOOD, 136.0)
	_add_resource_chip(row, &"population", &"population", "POP", ThemeFactory.IVORY, 88.0)
	_add_resource_chip(row, &"dens", &"den", "DENS", ThemeFactory.GOLD, 82.0)
	_add_resource_chip(row, &"time", &"clock", "TIME", ThemeFactory.MUTED, 82.0)
	_pause_button = ThemeFactory.icon_button(HUD_UTILITY_ICON_TEXTURES[&"pause"], "Pause the realm")
	_pause_button.name = "PauseButton"
	_pause_button.pressed.connect(_toggle_pause)
	row.add_child(_pause_button)
	_audio_button = ThemeFactory.icon_button(
		HUD_UTILITY_ICON_TEXTURES[&"audio_muted" if audio_director.muted else &"audio_on"],
		"Toggle music and sound effects",
	)
	_audio_button.name = "AudioButton"
	_audio_button.pressed.connect(_toggle_audio)
	row.add_child(_audio_button)


func _add_resource_chip(
	container: Control,
	id: StringName,
	glyph: StringName,
	label_text: String,
	color: Color,
	minimum_width: float,
) -> void:
	var chip := PanelContainer.new()
	chip.name = "%sChip" % String(id).capitalize()
	chip.custom_minimum_size.x = minimum_width
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override(&"panel", ThemeFactory.economy_chip_style(color))
	container.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	chip.add_child(row)
	var icon: Control
	if RESOURCE_ICON_TEXTURES.has(id):
		var texture_icon := TextureRect.new()
		texture_icon.texture = RESOURCE_ICON_TEXTURES[id] as Texture2D
		texture_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		texture_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon = texture_icon
	else:
		icon = HUD_ICON.new().configure(glyph, color) as HudIcon
	icon.name = "%sIcon" % String(id).capitalize()
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	row.add_child(icon)
	_resource_icons[id] = icon
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override(&"separation", -3)
	row.add_child(copy)
	var name_label := ThemeFactory.label(label_text, 9, ThemeFactory.MUTED_SAGE)
	copy.add_child(name_label)
	var value_label := ThemeFactory.label("0", 15, ThemeFactory.IVORY)
	value_label.name = "%sValue" % String(id).capitalize()
	value_label.clip_text = true
	copy.add_child(value_label)
	_resource_values[id] = value_label


func _build_bottom_hud(root: Control) -> void:
	_command_deck = PanelContainer.new()
	_command_deck.name = "CommandDeck"
	_command_deck.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_command_deck.offset_left = 8
	_command_deck.offset_top = -242
	_command_deck.offset_right = -8
	_command_deck.offset_bottom = -8
	var player_accent := FactionCatalog.definition(selected_faction)["accent"] as Color
	_command_deck.add_theme_stylebox_override(&"panel", ThemeFactory.hud_deck_style(player_accent))
	root.add_child(_command_deck)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	_command_deck.add_child(row)
	row.add_child(_build_minimap_bay())
	row.add_child(_build_selection_bay())
	row.add_child(_build_command_bay())
	_build_toast(root)


func _build_minimap_bay() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MinimapPanel"
	panel.custom_minimum_size.x = 236.0
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_inset_style(ThemeFactory.GOLD))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := ThemeFactory.label("JADE MERIDIAN", 11, ThemeFactory.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var map_state := ThemeFactory.label("TACTICAL MAP", 9, ThemeFactory.MUTED_SAGE)
	header.add_child(map_state)
	_minimap = BATTLEFIELD_MINIMAP.new()
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = Vector2(214.0, 145.0)
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.set_battlefield(battlefield)
	column.add_child(_minimap)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override(&"separation", 3)
	column.add_child(utilities)
	utilities.add_child(_make_utility_button("Q", "Select all Workers", func() -> void: battlefield.select_all_workers()))
	utilities.add_child(_make_utility_button("I", "Select all idle Workers", func() -> void: battlefield.select_all_idle_workers()))
	utilities.add_child(_make_utility_button("E", "Select the army", func() -> void: battlefield.select_all_army()))
	utilities.add_child(_make_utility_button("⌂", "Select and center the Stronghold · Space", func() -> void: battlefield.select_player_stronghold()))
	_fog_button = _make_utility_button("", "Toggle fog of war", _toggle_fog_of_war, &"fog")
	_fog_button.name = "FogToggle"
	_fog_icon = _fog_button.get_node("Icon") as HudIcon
	utilities.add_child(_fog_button)
	utilities.add_child(_make_utility_button("−", "Zoom battlefield out", func() -> void: battlefield.zoom_by(1.0 / 1.14)))
	utilities.add_child(_make_utility_button("+", "Zoom battlefield in", func() -> void: battlefield.zoom_by(1.14)))
	return panel


func _make_utility_button(
	button_text: String,
	tooltip: String,
	action: Callable,
	glyph: StringName = &"",
) -> Button:
	var button := ThemeFactory.button(button_text, tooltip)
	button.custom_minimum_size = Vector2(28.0, 30.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", 12)
	button.add_theme_stylebox_override(&"normal", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.BUTTON_BORDER))
	button.add_theme_stylebox_override(&"hover", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE_HOVER, ThemeFactory.JADE, 2))
	button.add_theme_stylebox_override(&"pressed", ThemeFactory.command_button_style(ThemeFactory.GOLD, Color("ffe8a0"), 2))
	button.pressed.connect(action)
	if not glyph.is_empty():
		var icon := HUD_ICON.new().configure(glyph, ThemeFactory.GOLD) as HudIcon
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6.0
		icon.offset_top = 5.0
		icon.offset_right = -6.0
		icon.offset_bottom = -5.0
		button.add_child(icon)
	return button


func _build_selection_bay() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SelectionBay"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_inset_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	panel.add_child(column)
	_queue_panel = _build_queue_panel()
	column.add_child(_queue_panel)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 10)
	column.add_child(body)
	_selection_portrait_frame = PanelContainer.new()
	_selection_portrait_frame.custom_minimum_size = Vector2(108.0, 112.0)
	_selection_portrait_frame.add_theme_stylebox_override(&"panel", ThemeFactory.portrait_style())
	body.add_child(_selection_portrait_frame)
	_selection_portrait = TextureRect.new()
	_selection_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selection_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_selection_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_selection_portrait_frame.add_child(_selection_portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 2)
	body.add_child(info)
	var title_row := HBoxContainer.new()
	info.add_child(title_row)
	_selection_title = ThemeFactory.label("NO SELECTION", 20, ThemeFactory.GOLD)
	_selection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_title.clip_text = true
	title_row.add_child(_selection_title)
	_selection_status = ThemeFactory.label("COMMAND", 10, ThemeFactory.JADE)
	_selection_status.add_theme_stylebox_override(&"normal", ThemeFactory.badge_style())
	_selection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_status.custom_minimum_size = Vector2(82.0, 22.0)
	title_row.add_child(_selection_status)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override(&"separation", 7)
	info.add_child(health_row)
	_selection_health = ProgressBar.new()
	_selection_health.show_percentage = false
	_selection_health.custom_minimum_size.y = 14.0
	_selection_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(_selection_health)
	_selection_health_label = ThemeFactory.label("", 11, ThemeFactory.IVORY)
	_selection_health_label.custom_minimum_size.x = 92.0
	_selection_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_row.add_child(_selection_health_label)
	_selection_order = ThemeFactory.label("SELECT OR INSPECT AN ENTITY", 13, ThemeFactory.IVORY)
	_selection_order.clip_text = true
	info.add_child(_selection_order)
	_selection_meta = ThemeFactory.label("Q WORKERS · I IDLE · E ARMY · SPACE STRONGHOLD", 11, ThemeFactory.JADE)
	_selection_meta.clip_text = true
	info.add_child(_selection_meta)
	_selection_detail = ThemeFactory.label("Left-click an entity to select or inspect it. Drag to box-select friendly units.", 11, ThemeFactory.MUTED_SAGE)
	_selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_detail.max_lines_visible = 2
	_selection_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(_selection_detail)
	_selection_stacks = HBoxContainer.new()
	_selection_stacks.add_theme_constant_override(&"separation", 4)
	_selection_stacks.visible = false
	info.add_child(_selection_stacks)
	return panel


func _build_queue_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ProductionQueue"
	panel.custom_minimum_size.y = 48.0
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.queue_panel_style(ThemeFactory.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	panel.add_child(row)
	var title_column := VBoxContainer.new()
	title_column.custom_minimum_size.x = 74.0
	row.add_child(title_column)
	var title := ThemeFactory.label("PRODUCTION", 9, ThemeFactory.GOLD)
	title_column.add_child(title)
	var hint := ThemeFactory.label("CLICK TO CANCEL", 8, ThemeFactory.MUTED_SAGE)
	title_column.add_child(hint)
	for index in range(5):
		var tile := ThemeFactory.button("", "Cancel this unit for a full refund")
		tile.name = "QueueTile%d" % index
		tile.custom_minimum_size = Vector2(84.0, 38.0)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override(&"font_size", 9)
		tile.add_theme_stylebox_override(&"normal", ThemeFactory.queue_tile_style())
		tile.add_theme_stylebox_override(&"hover", ThemeFactory.queue_tile_style(ThemeFactory.JADE, ThemeFactory.BUTTON_SURFACE_HOVER))
		tile.expand_icon = true
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tile.pressed.connect(_on_queue_tile_pressed.bind(tile))
		tile.visible = false
		row.add_child(tile)
		_queue_tiles.append(tile)
	panel.visible = false
	return panel


func _build_command_bay() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CommandCard"
	panel.custom_minimum_size.x = 424.0
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_inset_style(ThemeFactory.GOLD))
	_command_grid = GridContainer.new()
	_command_mode_group = ButtonGroup.new()
	_command_mode_group.allow_unpress = true
	_command_grid.columns = 4
	_command_grid.add_theme_constant_override(&"h_separation", 4)
	_command_grid.add_theme_constant_override(&"v_separation", 4)
	panel.add_child(_command_grid)
	for index in range(12):
		var slot := Control.new()
		slot.name = "CommandSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(98.0, 66.0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_command_grid.add_child(slot)
		_command_slots.append(slot)
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	_add_command_button(0, &"build", "WAR CAMP", func() -> void: _command_build(&"war_camp"), load(FactionCatalog.entity_art_path(faction, &"war_camp")) as Texture2D)
	_add_command_button(1, &"build_farm", "RICE FARM", func() -> void: _command_build(&"rice_farm"), load(FactionCatalog.entity_art_path(faction, &"rice_farm")) as Texture2D)
	_add_command_button(2, &"build_lodge", "HUNTER LODGE", func() -> void: _command_build(&"hunters_lodge"), load(FactionCatalog.entity_art_path(faction, &"hunters_lodge")) as Texture2D)
	_add_command_button(3, &"build_wall", "WOOD WALL", func() -> void: _command_build(&"wall"), load(FactionCatalog.entity_art_path(faction, &"wall")) as Texture2D)
	_add_command_button(4, &"build_gate", "WOOD GATE", func() -> void: _command_build(&"gate"), load(FactionCatalog.entity_art_path(faction, &"gate")) as Texture2D)
	_add_command_button(5, &"build_tower", "SENTRY TOWER", func() -> void: _command_build(&"sentry_tower"), load(FactionCatalog.entity_art_path(faction, &"sentry_tower")) as Texture2D)
	_add_command_button(0, &"worker", "WORKER", func() -> void: _command_train(&"worker"), load(FactionCatalog.entity_art_path(faction, &"worker")) as Texture2D)
	var hunter_icon: Texture2D = null
	if FactionCatalog.can_train_unit(faction, &"hunter"):
		hunter_icon = load(FactionCatalog.entity_art_path(faction, &"hunter")) as Texture2D
	_add_command_button(0, &"hunter", "HUNTER", func() -> void: _command_train(&"hunter"), hunter_icon)
	_add_command_button(0, &"vanguard", "VANGUARD", func() -> void: _command_train(&"vanguard"), load(FactionCatalog.entity_art_path(faction, &"vanguard")) as Texture2D)
	_add_command_button(1, &"mystic", "MYSTIC", func() -> void: _command_train(&"mystic"), load(FactionCatalog.entity_art_path(faction, &"mystic")) as Texture2D)
	_add_command_button(0, &"jadeclaw", "JADECLAW", func() -> void: _command_train(&"jadeclaw"), load(FactionCatalog.entity_art_path(faction, &"jadeclaw")) as Texture2D)
	_add_command_button(6, &"move", "MOVE", func() -> void:
		battlefield.begin_move(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"move")
	_add_command_button(7, &"attack_move", "ATTACK-MOVE", func() -> void:
		battlefield.begin_attack_move(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"attack_move", "F")
	_add_command_button(8, &"patrol", "PATROL", func() -> void:
		battlefield.begin_patrol(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"patrol", "T")
	_add_command_button(9, &"repair", "REPAIR", func() -> void:
		battlefield.begin_repair(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"repair", "R")
	_add_command_button(10, &"rally", "RALLY", func() -> void:
		battlefield.begin_rally()
		_update_armed_command_styles()
	, null, &"rally")
	_add_command_button(11, &"stop", "STOP", _command_stop, null, &"stop", "X")
	_add_command_button(11, &"cancel_queue", "CANCEL LAST", _command_cancel_training, null, &"cancel")
	return panel


func _add_command_button(
	slot_index: int,
	id: StringName,
	title: String,
	action: Callable,
	texture: Texture2D = null,
	glyph: StringName = &"objective",
	hotkey: String = "",
) -> void:
	var button := HUD_COMMAND_BUTTON.new().configure(title, "", hotkey, texture, glyph, ThemeFactory.GOLD) as HudCommandButton
	button.name = "%sCommand" % String(id).capitalize()
	if id in PERSISTENT_COMMAND_IDS:
		button.toggle_mode = true
		button.button_group = _command_mode_group
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override(&"normal", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.BUTTON_BORDER))
	button.add_theme_stylebox_override(&"hover", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE_HOVER, ThemeFactory.JADE, 2))
	button.add_theme_stylebox_override(&"pressed", ThemeFactory.command_button_style(ThemeFactory.GOLD, Color("ffe8a0"), 2))
	button.add_theme_stylebox_override(&"focus", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.GOLD, 2))
	button.add_theme_stylebox_override(&"disabled", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE_DISABLED, ThemeFactory.BUTTON_BORDER_DISABLED))
	button.pressed.connect(action)
	button.visible = false
	_command_slots[slot_index].add_child(button)
	_command_buttons[id] = button


func _build_toast(root: Control) -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "AlertToast"
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.position = Vector2(-220.0, -286.0)
	_toast_panel.size = Vector2(440.0, 38.0)
	_toast_panel.add_theme_stylebox_override(&"panel", ThemeFactory.toast_style())
	root.add_child(_toast_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	_toast_panel.add_child(row)
	var icon := HUD_ICON.new().configure(&"objective", ThemeFactory.JADE) as HudIcon
	icon.name = "ToastIcon"
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	row.add_child(icon)
	_feedback_label = ThemeFactory.label("", 13, ThemeFactory.JADE)
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.clip_text = true
	row.add_child(_feedback_label)
	_toast_panel.visible = false
	_build_pause_overlay(root)


func _build_pause_overlay(root: Control) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_pause_overlay)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.02, 0.022, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)

	_pause_menu = _make_modal_menu("PauseMenu", "PAUSED", "THE MANDATE AWAITS")
	_pause_overlay.add_child(_pause_menu)
	var pause_column := _pause_menu.get_node("MenuColumn") as VBoxContainer
	_resume_button = _make_modal_button("RESUME", "Return to the battle")
	_resume_button.name = "ResumeButton"
	_connect_button(_resume_button, func() -> void: _set_paused(false))
	pause_column.add_child(_resume_button)
	_settings_button = _make_modal_button("SETTINGS", "Open game settings")
	_settings_button.name = "SettingsButton"
	_connect_button(_settings_button, _show_settings_menu)
	pause_column.add_child(_settings_button)
	_resign_button = _make_modal_button("RESIGN", "Concede this match")
	_resign_button.name = "ResignButton"
	_resign_button.add_theme_color_override(&"font_color", ThemeFactory.DANGER)
	_resign_button.add_theme_color_override(&"font_hover_color", Color("ff8b7f"))
	_connect_button(_resign_button, _resign_match, &"ui_cancel")
	pause_column.add_child(_resign_button)
	var pause_hint := ThemeFactory.label("ESC OR P TO RESUME", 12, ThemeFactory.MUTED_SAGE)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_column.add_child(pause_hint)

	_settings_menu = _make_modal_menu("SettingsMenu", "SETTINGS", "GAME OPTIONS")
	_pause_overlay.add_child(_settings_menu)
	var settings_column := _settings_menu.get_node("MenuColumn") as VBoxContainer
	var audio_heading := ThemeFactory.label("AUDIO", 12, ThemeFactory.MUTED_SAGE)
	audio_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_column.add_child(audio_heading)
	_settings_audio_button = _make_modal_button("", "Toggle music and sound effects")
	_settings_audio_button.name = "AudioSettingButton"
	_connect_button(_settings_audio_button, _toggle_audio, &"")
	settings_column.add_child(_settings_audio_button)
	var settings_spacer := Control.new()
	settings_spacer.custom_minimum_size.y = 10.0
	settings_column.add_child(settings_spacer)
	_settings_back_button = _make_modal_button("BACK", "Return to the pause menu")
	_settings_back_button.name = "SettingsBackButton"
	_connect_button(_settings_back_button, _show_pause_menu, &"ui_cancel")
	settings_column.add_child(_settings_back_button)
	var settings_hint := ThemeFactory.label("ESC TO GO BACK", 12, ThemeFactory.MUTED_SAGE)
	settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_column.add_child(settings_hint)

	_update_audio_controls()
	_pause_overlay.visible = false
	_settings_menu.visible = false


func _make_modal_menu(node_name: String, title_text: String, subtitle_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210.0, -190.0)
	panel.size = Vector2(420.0, 380.0)
	panel.add_theme_stylebox_override(
		&"panel",
		ThemeFactory.panel_style(Color("071313fc"), Color(ThemeFactory.GOLD, 0.92), 2, 6),
	)
	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	var title := ThemeFactory.label(title_text, 34, ThemeFactory.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := ThemeFactory.label(subtitle_text, 12, ThemeFactory.JADE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var divider := ColorRect.new()
	divider.color = Color(ThemeFactory.GOLD, 0.58)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4.0
	column.add_child(spacer)
	return panel


func _make_modal_button(text: String, tooltip: String) -> Button:
	var button := ThemeFactory.button(text, tooltip)
	button.custom_minimum_size = Vector2(300.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func _build_help_panel(root: Control) -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "Objective"
	_objective_panel.position = Vector2(10, 64)
	_objective_panel.size = Vector2(326, 154)
	_objective_panel.add_theme_stylebox_override(&"panel", ThemeFactory.objective_style(true))
	root.add_child(_objective_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 1)
	_objective_panel.add_child(column)
	_objective_toggle = ThemeFactory.button("OBJECTIVES    ▴", "Collapse or expand the objective tracker")
	_objective_toggle.name = "ObjectiveToggle"
	_objective_toggle.custom_minimum_size.y = 22.0
	_objective_toggle.add_theme_font_size_override(&"font_size", 11)
	_objective_toggle.add_theme_stylebox_override(&"normal", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.GOLD))
	_objective_toggle.pressed.connect(_toggle_objectives)
	column.add_child(_objective_toggle)
	for index in range(4):
		var label := ThemeFactory.label("", 11, ThemeFactory.IVORY)
		label.name = "ObjectiveRow%d" % (index + 1)
		label.custom_minimum_size.y = 20.0
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		column.add_child(label)
		_objective_rows.append(label)


func _build_minimap(root: Control) -> void:
	# The minimap is integrated into the bottom command deck.
	pass


func _update_hud() -> void:
	if simulation == null or simulation.players.is_empty() or _resource_values.is_empty():
		return
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var player_definition := FactionCatalog.definition(player["faction"] as StringName)
	_score_label.text = "SCORE: %d" % simulation.team_score(RtsSimulation.TEAM_PLAYER)
	_score_label.add_theme_color_override(&"font_color", player_definition["accent"] as Color)
	var minutes := floori(simulation.elapsed_time / 60.0)
	var seconds := int(simulation.elapsed_time) % 60
	(_resource_values[&"jade"] as Label).text = "%d" % int(player["jade"])
	(_resource_values[&"lumber"] as Label).text = "%d" % int(player["lumber"])
	(_resource_values[&"essence"] as Label).text = "%d" % int(player["essence"])
	(_resource_values[&"food"] as Label).text = "%d  +%.1f/s" % [
		int(player["food"]), simulation.food_income_per_second(RtsSimulation.TEAM_PLAYER),
	]
	var remaining_population := int(player["population_cap"]) - int(player["population"])
	var population_label := _resource_values[&"population"] as Label
	population_label.text = "%d/%d" % [int(player["population"]), int(player["population_cap"])]
	var population_color := ThemeFactory.IVORY
	if remaining_population <= 0:
		population_color = ThemeFactory.DANGER
	elif remaining_population <= 2:
		population_color = ThemeFactory.GOLD
	population_label.add_theme_color_override(&"font_color", population_color)
	(_resource_values[&"dens"] as Label).text = "%d/%d" % [
		simulation.captured_cave_count(RtsSimulation.TEAM_PLAYER), MapCatalog.CAVES.size(),
	]
	(_resource_values[&"time"] as Label).text = "%02d:%02d" % [minutes, seconds]
	_update_objectives()
	_update_selection_panel()
	_update_production_queue()
	_update_commands()
	_update_armed_command_styles()
	if _fog_icon != null:
		_fog_icon.glyph_color = ThemeFactory.JADE if battlefield.fog_enabled else ThemeFactory.MUTED_SAGE
		_fog_icon.queue_redraw()
		_fog_button.tooltip_text = "Fog of war on" if battlefield.fog_enabled else "Fog of war off"


func _on_selection_changed(_ids: Array) -> void:
	_update_hud()


func _toggle_objectives() -> void:
	_objective_collapsed = not _objective_collapsed
	_update_objectives()


func _update_objectives() -> void:
	if _objective_panel == null or _objective_rows.size() < 4:
		return
	var food_buildings := 0
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and entity_state.get("kind") in RtsSimulation.FOOD_PRODUCER_KINDS
			and float(entity_state.get("complete", 0.0)) >= 1.0
		):
			food_buildings += 1
	var dens := simulation.captured_cave_count(RtsSimulation.TEAM_PLAYER)
	var player_shenlongs := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"shenlong"])
	var rivals_defeated := RtsSimulation.TEAM_COUNT - 1 - simulation.living_rival_count()
	var completed: Array[bool] = [food_buildings > 0, dens > 0, not player_shenlongs.is_empty(), simulation.living_rival_count() == 0]
	var copy: Array[String] = [
		"Build Food Supply  %d/1" % mini(food_buildings, 1),
		"Capture a Yaoguai Den  %d/%d" % [dens, MapCatalog.CAVES.size()],
		"Hatch the Dragon Egg  %d/1" % mini(player_shenlongs.size(), 1),
		"Defeat Rival Strongholds  %d/3" % rivals_defeated,
	]
	var next_index := 3
	for index in range(completed.size()):
		if not completed[index]:
			next_index = index
			break
	for index in range(_objective_rows.size()):
		var row := _objective_rows[index]
		row.text = "%s  %s" % ["✓" if completed[index] else "◆", copy[index]]
		row.add_theme_color_override(
			&"font_color",
			ThemeFactory.MUTED_SAGE if completed[index] else ThemeFactory.IVORY,
		)
		row.visible = not _objective_collapsed or index == next_index
	_objective_panel.size.y = 58.0 if _objective_collapsed else 154.0
	_objective_panel.add_theme_stylebox_override(&"panel", ThemeFactory.objective_style(not completed.all(func(value: bool) -> bool: return value)))
	_objective_toggle.text = "OBJECTIVES    ▾" if _objective_collapsed else "OBJECTIVES    ▴"


func _update_selection_panel() -> void:
	if battlefield == null or _selection_title == null:
		return
	for child in _selection_stacks.get_children():
		_selection_stacks.remove_child(child)
		child.queue_free()
	_selection_stacks.visible = false
	_selection_health.visible = true
	_selection_health_label.visible = true
	var ids: Array[int] = battlefield.selected_ids
	_selection_portrait.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ids.is_empty()
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	if ids.is_empty():
		_selection_portrait.texture = load(FactionCatalog.portrait_path(selected_faction)) as Texture2D
		_selection_portrait_frame.add_theme_stylebox_override(&"panel", ThemeFactory.portrait_style(FactionCatalog.definition(selected_faction)["accent"] as Color))
		_selection_title.text = "NO SELECTION"
		_selection_status.text = "COMMAND"
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
		_selection_health.visible = false
		_selection_health_label.visible = false
		_selection_order.text = "SELECT OR INSPECT AN ENTITY"
		_selection_meta.text = "Q WORKERS · I IDLE · E ARMY · SPACE STRONGHOLD"
		_selection_detail.text = "Left-click an entity to select or inspect it. Drag to box-select friendly units."
		return
	if ids.size() > 1:
		_update_group_selection(ids)
		return
	var entity_state := simulation.entity(ids[0])
	if entity_state.is_empty():
		return
	_selection_portrait.texture = _selection_art_texture(entity_state)
	var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	var accent := ThemeFactory.GOLD
	if team == RtsSimulation.TEAM_PLAYER:
		accent = FactionCatalog.definition(selected_faction)["accent"] as Color
	elif team > RtsSimulation.TEAM_PLAYER:
		accent = ThemeFactory.DANGER
	_selection_portrait_frame.add_theme_stylebox_override(&"panel", ThemeFactory.portrait_style(accent))
	match entity_state.get("category"):
		&"resource":
			_update_resource_selection(entity_state)
		&"wildlife":
			_update_wildlife_selection(entity_state)
		_:
			if entity_state.get("kind") == &"yaoguai_den":
				_update_den_selection(entity_state)
			elif entity_state.get("kind") == &"shenlong_egg":
				_update_egg_selection(entity_state)
			else:
				_update_owned_selection(entity_state)


func _update_group_selection(ids: Array[int]) -> void:
	var groups := {}
	var current_hp := 0.0
	var maximum_hp := 0.0
	var shared_order: StringName = &""
	var mixed_orders := false
	for id in ids:
		var entity_state := simulation.entity(id)
		if entity_state.is_empty():
			continue
		var kind := entity_state.get("kind", &"unknown") as StringName
		if not groups.has(kind):
			groups[kind] = []
		(groups[kind] as Array).append(id)
		current_hp += float(entity_state.get("hp", 0.0))
		maximum_hp += float(entity_state.get("max_hp", 1.0))
		var order := entity_state.get("order", &"idle") as StringName
		if shared_order.is_empty():
			shared_order = order
		elif shared_order != order:
			mixed_orders = true
	_selection_portrait.texture = load(FactionCatalog.portrait_path(selected_faction)) as Texture2D
	_selection_portrait_frame.add_theme_stylebox_override(&"panel", ThemeFactory.portrait_style(FactionCatalog.definition(selected_faction)["accent"] as Color))
	_selection_title.text = "%d UNITS SELECTED" % ids.size()
	_selection_status.text = "GROUP"
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
	_set_selection_progress(current_hp, maximum_hp, "%d / %d TOTAL HP" % [int(current_hp), int(maximum_hp)], ThemeFactory.JADE)
	_selection_order.text = "MIXED ORDERS" if mixed_orders else _order_label({"order": shared_order}).to_upper()
	_selection_meta.text = "%d TYPES · SHIFT QUEUES ORDERS" % groups.size()
	_selection_detail.text = "Click a unit stack to select that type. Shared commands remain in fixed slots."
	_selection_stacks.visible = true
	var group_kinds := groups.keys()
	group_kinds.sort()
	for raw_kind in group_kinds:
		var kind := raw_kind as StringName
		var subgroup: Array[int] = []
		for raw_id in groups[kind] as Array:
			subgroup.append(int(raw_id))
		var sample := simulation.entity(subgroup[0])
		var stack := ThemeFactory.button("%s  ×%d" % [String(kind).replace("_", " ").capitalize(), subgroup.size()], "Select only this unit type")
		stack.custom_minimum_size = Vector2(84.0, 28.0)
		stack.add_theme_font_size_override(&"font_size", 9)
		stack.icon = _selection_art_texture(sample)
		stack.expand_icon = true
		stack.pressed.connect(_select_subgroup.bind(subgroup))
		_selection_stacks.add_child(stack)


func _select_subgroup(ids: Array[int]) -> void:
	battlefield.select_entities(ids)


func _on_garrison_unit_pressed(tower_id: int, unit_id: int) -> void:
	if simulation.command_ungarrison(RtsSimulation.TEAM_PLAYER, tower_id, unit_id):
		audio_director.play_ui(&"ui_confirm")
		_show_feedback("Unit ungarrisoned at the base of the Sentry Tower.", false)
	else:
		_show_feedback("That unit can no longer be ungarrisoned from this tower.", true)


func _update_resource_selection(entity_state: Dictionary) -> void:
	var resource_kind := entity_state.get("resource_kind", &"jade") as StringName
	var resource_name := "Jade Outcrop"
	var resource_color := ThemeFactory.JADE
	if resource_kind == &"lumber":
		resource_name = "Lumber Tree"
		resource_color = ThemeFactory.LUMBER
	elif resource_kind == &"essence":
		resource_name = "Essence Shrine"
		resource_color = ThemeFactory.ESSENCE
	var assigned := 0
	for raw_entity in simulation.entities.values():
		var worker := raw_entity as Dictionary
		if (
			bool(worker.get("alive", false))
			and int(worker.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and worker.get("kind") == &"worker"
			and int(worker.get("gather_source_id", -1)) == int(entity_state["id"])
		):
			assigned += 1
	var amount := float(entity_state.get("amount", 0.0))
	var max_amount := float(entity_state.get("max_amount", maxf(amount, 1.0)))
	_selection_title.text = resource_name.to_upper()
	_selection_status.text = "RESOURCE"
	_selection_status.add_theme_color_override(&"font_color", resource_color)
	_set_selection_progress(amount, max_amount, "%d REMAIN" % int(amount), resource_color)
	_selection_order.text = "%d WORKERS ASSIGNED" % assigned
	_selection_meta.text = String(resource_kind).to_upper()
	_selection_detail.text = "Select Workers, then right-click this source to begin gathering."


func _update_wildlife_selection(entity_state: Dictionary) -> void:
	var stats := FactionCatalog.stats(entity_state["kind"] as StringName, &"neutral")
	var reaction := "RETALIATES" if bool(entity_state.get("retaliates", false)) else "FLEES"
	_selection_title.text = String(stats["name"]).to_upper()
	_selection_status.text = "WILDLIFE"
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.FOOD)
	_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), "%d / %d HP" % [int(entity_state["hp"]), int(entity_state["max_hp"])], ThemeFactory.JADE)
	_selection_order.text = reaction
	_selection_meta.text = "%d FOOD BOUNTY" % int(entity_state.get("food_bounty", 0))
	_selection_detail.text = "Hunters deal triple damage to wildlife. %s" % String(stats["role"])


func _update_den_selection(entity_state: Dictionary) -> void:
	var owner := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	var guardians := simulation.cave_guardian_count(int(entity_state["id"]))
	var progress := float(entity_state.get("capture_progress", 0.0))
	var contested := bool(entity_state.get("capture_contested", false))
	_selection_title.text = "YAOGUAI DEN"
	if guardians > 0:
		_selection_status.text = "GUARDED"
	elif contested:
		_selection_status.text = "CONTESTED"
	elif owner == RtsSimulation.TEAM_PLAYER:
		_selection_status.text = "CONTROLLED"
	elif owner > RtsSimulation.TEAM_PLAYER:
		_selection_status.text = "RIVAL"
	else:
		_selection_status.text = "CLEARED"
	var status_color := ThemeFactory.DANGER if contested or owner > RtsSimulation.TEAM_PLAYER else ThemeFactory.GOLD if owner == RtsSimulation.TEAM_NEUTRAL else ThemeFactory.JADE
	_selection_status.add_theme_color_override(&"font_color", status_color)
	if progress > 0.0 or contested:
		_set_selection_progress(progress, RtsSimulation.CAVE_CAPTURE_SECONDS, "CAPTURE %d%%" % int(100.0 * progress / RtsSimulation.CAVE_CAPTURE_SECONDS), status_color)
	else:
		_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), "%d / %d HP" % [int(entity_state["hp"]), int(entity_state["max_hp"])], ThemeFactory.JADE)
	if guardians > 0:
		_selection_order.text = "%d GUARDIANS REMAIN" % guardians
	elif owner == RtsSimulation.TEAM_PLAYER:
		_selection_order.text = "DEN SECURED"
	elif contested:
		_selection_order.text = "CAPTURE CONTESTED"
	else:
		_selection_order.text = "HOLD THE RING FOR 6 SECONDS"
	var queue := entity_state.get("queue", []) as Array
	_selection_meta.text = "JADECLAW QUEUE  %d" % queue.size() if owner == RtsSimulation.TEAM_PLAYER else "CAPTURE OBJECTIVE"
	if not queue.is_empty():
		var item := queue[0] as Dictionary
		_selection_detail.text = "Calling Jadeclaw · %.1fs remaining · rally %s" % [float(item.get("remaining", 0.0)), _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)]
	elif guardians > 0:
		_selection_detail.text = "Defeat the guardians, then occupy the capture ring uncontested."
	else:
		_selection_detail.text = "Produces Jadeclaws when controlled · rally %s" % _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)


func _update_egg_selection(entity_state: Dictionary) -> void:
	var carrier := simulation.entity(int(entity_state.get("carried_by", -1)))
	_selection_title.text = "SHENLONG DRAGON EGG"
	_selection_status.text = "LOCKED"
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.GOLD)
	_selection_health.visible = false
	_selection_health_label.visible = false
	if not carrier.is_empty():
		var carrier_team := int(carrier.get("team", RtsSimulation.TEAM_NEUTRAL))
		_selection_status.text = "YOUR CARRIER" if carrier_team == RtsSimulation.TEAM_PLAYER else "RIVAL CARRIER"
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE if carrier_team == RtsSimulation.TEAM_PLAYER else ThemeFactory.DANGER)
		_selection_order.text = "RETURNING TO A STRONGHOLD"
		_selection_meta.text = "INTERCEPTABLE OBJECTIVE"
		_selection_detail.text = "Defeat the carrier to drop the egg and make it claimable again."
	elif bool(entity_state.get("claimable", false)):
		_selection_status.text = "CLAIMABLE"
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
		_selection_order.text = "AWAITING AN EMPTY-HANDED WORKER"
		_selection_meta.text = "CENTRAL MYTHIC OBJECTIVE"
		_selection_detail.text = "Select a Worker and right-click the egg, then escort it home to hatch Shenlong."
	else:
		_selection_order.text = "GUARDED BY SHENLONG"
		_selection_meta.text = "CENTRAL MYTHIC OBJECTIVE"
		_selection_detail.text = "Defeat the neutral Shenlong to unlock this egg for every player."


func _update_owned_selection(entity_state: Dictionary) -> void:
	var kind := entity_state["kind"] as StringName
	var faction := entity_state.get("faction", selected_faction) as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var completion := float(entity_state.get("complete", 1.0))
	var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	var category_label := "STRUCTURE" if entity_state.get("category") == &"structure" else "UNIT"
	var affiliation := "NEUTRAL"
	var status_color := ThemeFactory.GOLD
	if team == RtsSimulation.TEAM_PLAYER:
		affiliation = "YOUR"
		status_color = ThemeFactory.JADE
	elif team > RtsSimulation.TEAM_PLAYER:
		affiliation = "ENEMY"
		status_color = ThemeFactory.DANGER
	_selection_title.text = String(stats["name"]).to_upper()
	_selection_status.text = "%s %s" % [affiliation, category_label] if team != RtsSimulation.TEAM_PLAYER else category_label
	_selection_status.add_theme_color_override(&"font_color", status_color)
	if completion < 1.0:
		_set_selection_progress(completion, 1.0, "CONSTRUCTION %d%%" % int(completion * 100.0), ThemeFactory.GOLD)
	else:
		_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), "%d / %d HP" % [int(entity_state["hp"]), int(entity_state["max_hp"])], status_color)
	_selection_order.text = _order_label(entity_state).to_upper()
	if entity_state.get("category") == &"structure":
		var queue := entity_state.get("queue", []) as Array
		_selection_meta.text = "QUEUE %d · RALLY %s" % [queue.size(), _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)]
		if kind == &"sentry_tower" and completion >= 1.0:
			var occupants := entity_state.get("garrisoned_unit_ids", []) as Array
			_selection_order.text = "MANNED" if not occupants.is_empty() else "AWAITING GARRISON"
			_selection_meta.text = "GARRISON %d/%d · DOUBLE OCCUPANT RANGE" % [occupants.size(), int(entity_state.get("garrison_capacity", 1))]
			_selection_detail.text = "Right-click with a Hunter or Mystic to garrison. Click the occupant below to deploy them at the tower base."
			if team == RtsSimulation.TEAM_PLAYER and not occupants.is_empty():
				_selection_stacks.visible = true
				for raw_id in occupants:
					var occupant := simulation.entity(int(raw_id))
					if occupant.is_empty():
						continue
					var occupant_name := String(FactionCatalog.stats(occupant["kind"] as StringName, occupant["faction"] as StringName)["name"])
					var button := ThemeFactory.button("%s  ·  UNGARRISON" % occupant_name.to_upper(), "Deploy this unit at the tower base")
					button.name = "GarrisonUnitButton"
					button.custom_minimum_size = Vector2(190.0, 30.0)
					button.add_theme_font_size_override(&"font_size", 9)
					button.icon = _selection_art_texture(occupant)
					button.expand_icon = true
					button.pressed.connect(_on_garrison_unit_pressed.bind(int(entity_state["id"]), int(occupant["id"])))
					_selection_stacks.add_child(button)
		elif kind in RtsSimulation.FOOD_PRODUCER_KINDS and completion >= 1.0:
			var interval := float(stats.get("food_interval", 1.0))
			var next_harvest := maxf(0.0, interval - float(entity_state.get("food_timer", 0.0)))
			var harvest_yield := simulation.structure_food_yield(int(entity_state["id"]))
			if kind == &"rice_farm":
				var farmer_id := simulation.farm_worker_id(int(entity_state["id"]))
				var farm_state := "PASSIVE"
				if farmer_id >= 0:
					farm_state = "STAFFED" if simulation.is_farm_staffed(int(entity_state["id"])) else "WORKER EN ROUTE"
				_selection_order.text = farm_state
				_selection_meta.text = "FARMER %d/1 · %.1f FOOD/S" % [1 if farmer_id >= 0 else 0, float(harvest_yield) / interval]
				_selection_detail.text = "+%d Food every %.0fs · next harvest in %.1fs · right-click with an empty Worker to staff" % [harvest_yield, interval, next_harvest]
			else:
				_selection_detail.text = "+%d passive Food every %.0fs · next harvest in %.1fs · Hunters earn one-time wildlife bounties" % [harvest_yield, interval, next_harvest]
		elif not queue.is_empty():
			var item := queue[0] as Dictionary
			_selection_detail.text = "Training %s · %.1fs remaining" % [String(item.get("kind", &"unit")).capitalize(), float(item.get("remaining", 0.0))]
		else:
			_selection_detail.text = String(stats["role"])
	else:
		var command_queue := entity_state.get("command_queue", []) as Array
		if kind == &"worker" and bool(entity_state.get("carrying_egg", false)):
			_selection_meta.text = "CARRYING THE DRAGON EGG"
		elif kind == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
			_selection_meta.text = "CARRYING %d/%d %s" % [int(entity_state["cargo_amount"]), int(RtsSimulation.CARGO_CAPACITY), String(entity_state.get("cargo_kind", &"")).to_upper()]
		else:
			_selection_meta.text = "DAMAGE %d · RANGE %.1f · QUEUED %d" % [int(stats.get("damage", 0)), float(stats.get("range", 0.0)), command_queue.size()]
		_selection_detail.text = String(stats["role"])


func _order_label(entity_state: Dictionary) -> String:
	var order := entity_state.get("order", &"idle") as StringName
	match order:
		&"move": return "Moving"
		&"attack_move": return "Attack-moving"
		&"attack": return "Attacking"
		&"gather":
			var source := simulation.entity(int(entity_state.get("gather_source_id", -1)))
			return "Gathering %s" % String(source.get("resource_kind", &"resources")).capitalize()
		&"farm": return "Working farm"
		&"return": return "Returning cargo"
		&"claim_egg": return "Claiming Dragon Egg"
		&"return_egg": return "Returning Dragon Egg"
		&"repair": return "Repairing"
		&"garrison": return "Entering tower"
		&"garrisoned": return "Garrisoned"
		&"patrol": return "Patrolling"
		&"construct": return "Constructing"
		&"constructing": return "Constructing"
		_: return String(order).replace("_", " ").capitalize()


func _set_selection_progress(current: float, maximum: float, label_text: String, color: Color) -> void:
	_selection_health.visible = true
	_selection_health_label.visible = true
	_selection_health.max_value = maxf(maximum, 0.001)
	_selection_health.value = clampf(current, 0.0, _selection_health.max_value)
	_selection_health.add_theme_stylebox_override(&"fill", ThemeFactory.progress_fill_style(color))
	_selection_health_label.text = label_text


func _selection_art_texture(entity_state: Dictionary) -> Texture2D:
	if entity_state.get("category") == &"resource":
		match entity_state.get("resource_kind"):
			&"lumber": return load("res://assets/runtime/resources/lumber_pine.png") as Texture2D
			&"essence": return load("res://assets/runtime/resources/essence_shrine.png") as Texture2D
			_: return load("res://assets/runtime/resources/jade_outcrop.png") as Texture2D
	var faction := entity_state.get("faction", &"neutral") as StringName
	return load(FactionCatalog.entity_art_path(faction, entity_state.get("kind", &"worker") as StringName)) as Texture2D


func _cell_label(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _update_production_queue() -> void:
	if _queue_panel == null:
		return
	var producers: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and entity_state.get("category") == &"structure"
			and not (entity_state.get("queue", []) as Array).is_empty()
		):
			producers.append(entity_state)
	producers.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first["id"]) < int(second["id"]))
	var queue_items: Array[Dictionary] = []
	for producer in producers:
		var queue := producer.get("queue", []) as Array
		for index in range(queue.size()):
			var item := queue[index] as Dictionary
			queue_items.append({
				"producer_id": int(producer["id"]),
				"queue_index": index,
				"order_id": int(item.get("order_id", -1)),
				"kind": item.get("kind", &"unit") as StringName,
				"remaining": float(item.get("remaining", 0.0)),
			})
	for tile_index in range(_queue_tiles.size()):
		var tile := _queue_tiles[tile_index]
		tile.visible = tile_index < queue_items.size()
		if not tile.visible:
			continue
		var item := queue_items[tile_index]
		var kind := item["kind"] as StringName
		var producer_id := int(item["producer_id"])
		tile.set_meta(&"producer_id", producer_id)
		tile.set_meta(&"queue_index", int(item["queue_index"]))
		tile.set_meta(&"order_id", int(item["order_id"]))
		tile.icon = load(FactionCatalog.entity_art_path(selected_faction, kind)) as Texture2D
		tile.text = "%s\n%.1fs" % [String(kind).replace("_", " ").capitalize(), float(item["remaining"])]
		tile.tooltip_text = "Cancel this %s for a full refund" % String(kind).replace("_", " ").capitalize()
	_queue_panel.visible = not queue_items.is_empty()


func _on_queue_tile_pressed(tile: Button) -> void:
	var producer_id := int(tile.get_meta(&"producer_id", -1))
	var queue_index := int(tile.get_meta(&"queue_index", -1))
	var order_id := int(tile.get_meta(&"order_id", -1))
	if producer_id < 0 or queue_index < 0 or order_id < 0 or simulation.entity(producer_id).is_empty():
		return
	_cancel_training_order(producer_id, queue_index, order_id)


func _update_commands() -> void:
	if battlefield == null or _command_buttons.is_empty():
		return
	for raw_button in _command_buttons.values():
		(raw_button as HudCommandButton).set_meta(COMMAND_VISIBLE_META, false)
	var selected_structure_id := battlefield.primary_selected_structure()
	var structure := simulation.entity(selected_structure_id) if selected_structure_id >= 0 else {}
	var has_units := not battlefield.selected_commandable_units().is_empty()
	var has_worker := false
	var has_military := false
	for id in battlefield.selected_ids:
		var selected_entity := simulation.entity(id)
		if int(selected_entity.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER:
			continue
		if selected_entity.get("kind") == &"worker":
			has_worker = true
		elif selected_entity.get("kind") in [&"hunter", &"vanguard", &"mystic", &"jadeclaw"]:
			has_military = true
	var player_faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var build_commands := {
		&"build": &"war_camp",
		&"build_farm": &"rice_farm",
		&"build_lodge": &"hunters_lodge",
		&"build_wall": &"wall",
		&"build_gate": &"gate",
		&"build_tower": &"sentry_tower",
	}
	for button_id in build_commands:
		var structure_kind := build_commands[button_id] as StringName
		if has_worker and simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, structure_kind):
			_show_cost_command(button_id, structure_kind, "Build")
	if not structure.is_empty() and float(structure.get("complete", 0.0)) >= 1.0:
		match structure.get("kind"):
			&"stronghold": _show_cost_command(&"worker", &"worker", "Train", true)
			&"war_camp":
				_show_cost_command(&"vanguard", &"vanguard", "Train", true)
				_show_cost_command(&"mystic", &"mystic", "Train", true)
			&"hunters_lodge":
				if simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"hunter"):
					_show_cost_command(&"hunter", &"hunter", "Train", true)
			&"yaoguai_den": _show_cost_command(&"jadeclaw", &"jadeclaw", "Call", true)
	_set_simple_command(&"move", has_units, "Choose a movement destination")
	_set_simple_command(&"attack_move", has_military, "Move while engaging hostile targets · F")
	_set_simple_command(&"patrol", has_military, "Patrol repeatedly between the current position and a destination · T")
	_set_simple_command(&"repair", has_worker, "Repair a damaged allied structure · 15 health per 1 Lumber · R")
	_set_simple_command(&"stop", has_units, "Cancel current and queued orders · X")
	_set_simple_command(&"rally", not structure.is_empty(), "Set the selected producer's rally destination")
	var production_queue := structure.get("queue", []) as Array if not structure.is_empty() else []
	var cancel_button := _command_buttons[&"cancel_queue"] as HudCommandButton
	cancel_button.set_meta(COMMAND_VISIBLE_META, not production_queue.is_empty())
	cancel_button.disabled = production_queue.is_empty()
	if not production_queue.is_empty():
		cancel_button.set_command_title("CANCEL LAST")
		cancel_button.set_cost_markup("REFUND")
		cancel_button.tooltip_text = "Refund the newest queued unit and release its reserved population"
	for raw_button in _command_buttons.values():
		var command_button := raw_button as HudCommandButton
		command_button.visible = bool(command_button.get_meta(COMMAND_VISIBLE_META, false))
		CursorSystem.apply(command_button, CursorSystem.FORBIDDEN if command_button.disabled else CursorSystem.UI_ACTION)


func _show_cost_command(button_id: StringName, kind: StringName, verb: String, check_population: bool = false) -> void:
	var button := _command_buttons[button_id] as HudCommandButton
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var free_recovery_worker := (
		kind == &"worker"
		and simulation.can_train_free_worker(RtsSimulation.TEAM_PLAYER)
	)
	if free_recovery_worker:
		for cost_key in ["jade_cost", "lumber_cost", "essence_cost", "food_cost"]:
			stats[cost_key] = 0
	button.set_meta(COMMAND_VISIBLE_META, true)
	button.disabled = not simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, kind) or (check_population and not simulation.has_population_for(RtsSimulation.TEAM_PLAYER, kind))
	button.set_cost_markup(_cost_markup(stats))
	var tooltip := "%s %s · %s" % [verb, stats["name"], _long_cost(stats)]
	if free_recovery_worker:
		tooltip += "\nRecovery worker: free because you have no Workers left"
	var unavailable := _unavailable_reason(stats, check_population)
	if not unavailable.is_empty():
		tooltip += "\nUnavailable: %s" % unavailable
	button.tooltip_text = tooltip


func _set_simple_command(button_id: StringName, visible: bool, tooltip: String) -> void:
	var button := _command_buttons[button_id] as HudCommandButton
	button.set_meta(COMMAND_VISIBLE_META, visible)
	button.disabled = false
	button.set_cost_markup("")
	button.tooltip_text = tooltip


func _cost_markup(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", "J", "6fd2aa"],
		["lumber_cost", "L", "d0a25c"],
		["essence_cost", "E", "a974e6"],
		["food_cost", "F", "e8c56a"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append("[color=#%s]%d%s[/color]" % [definition[2], amount, definition[1]])
	return "  ".join(parts) if not parts.is_empty() else "FREE"


func _unavailable_reason(stats: Dictionary, check_population: bool) -> String:
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var missing: Array[String] = []
	for definition in [
		["jade_cost", "jade", "Jade"],
		["lumber_cost", "lumber", "Lumber"],
		["essence_cost", "essence", "Essence"],
		["food_cost", "food", "Food"],
	]:
		var shortfall := int(stats.get(definition[0], 0)) - int(player.get(definition[1], 0))
		if shortfall > 0:
			missing.append("need %d more %s" % [shortfall, definition[2]])
	if check_population:
		var population_cost := int(stats.get("population", 0))
		var room := int(player["population_cap"]) - int(player["population"])
		if population_cost > room:
			missing.append("need %d population space" % (population_cost - room))
	return ", ".join(missing)


func _update_armed_command_styles() -> void:
	var active := {
		&"move": battlefield.move_armed,
		&"attack_move": battlefield.attack_move_armed,
		&"patrol": battlefield.patrol_armed,
		&"repair": battlefield.repair_armed,
		&"rally": battlefield.rally_armed,
		&"build": battlefield.placement_kind == &"war_camp",
		&"build_farm": battlefield.placement_kind == &"rice_farm",
		&"build_lodge": battlefield.placement_kind == &"hunters_lodge",
		&"build_wall": battlefield.placement_kind == &"wall",
		&"build_gate": battlefield.placement_kind == &"gate",
		&"build_tower": battlefield.placement_kind == &"sentry_tower",
	}
	for button_id in active:
		var button := _command_buttons[button_id] as HudCommandButton
		var is_active := bool(active[button_id])
		button.set_pressed_no_signal(is_active)
		button.tooltip_text = button.tooltip_text.trim_suffix(ARMED_TOOLTIP_SUFFIX)
		if is_active:
			var armed_style := ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE_ACTIVE, ThemeFactory.JADE, 2)
			button.add_theme_stylebox_override(&"normal", armed_style)
			button.add_theme_stylebox_override(&"pressed", armed_style)
			button.tooltip_text += ARMED_TOOLTIP_SUFFIX
		else:
			button.add_theme_stylebox_override(&"normal", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.BUTTON_BORDER))
			button.add_theme_stylebox_override(&"pressed", ThemeFactory.command_button_style(ThemeFactory.GOLD, Color("ffe8a0"), 2))


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
	_update_armed_command_styles()


func _command_stop() -> void:
	var units := battlefield.selected_commandable_units()
	if units.is_empty():
		_show_feedback("Select units before issuing Stop.", true)
		return
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, units)
	audio_director.play_ui(&"ui_cancel")
	_show_feedback("Selected units halted.", false)


func _command_train(kind: StringName) -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback("Select the correct production structure.", true)
		return
	if simulation.command_train(RtsSimulation.TEAM_PLAYER, structure_id, kind):
		audio_director.play_ui(&"ui_confirm")
		_show_feedback("%s added to the training queue." % String(kind).capitalize(), false)
	else:
		_show_feedback("Insufficient resources, Food, population, or production capacity.", true)


func _command_cancel_training() -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback("Select a production structure with a queued unit.", true)
		return
	_cancel_training_order(structure_id)


func _cancel_training_order(
	structure_id: int,
	queue_index: int = -1,
	expected_order_id: int = -1,
) -> void:
	var cancelled := simulation.command_cancel_training(
		RtsSimulation.TEAM_PLAYER,
		structure_id,
		queue_index,
		expected_order_id,
	)
	if cancelled.is_empty():
		_show_feedback("That unit is no longer in the production queue.", true)
		_update_hud()
		return
	audio_director.play_ui(&"ui_cancel")
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
	var refund_text := " · ".join(refund_parts) if not refund_parts.is_empty() else "no resources (free unit)"
	_show_feedback(
		"Cancelled %s · full refund: %s." % [
			String(cancelled.get("kind", &"unit")).capitalize(),
			refund_text,
		],
		false,
	)
	_update_hud()


func _on_battle_notice(message: String, team: int) -> void:
	if team == RtsSimulation.TEAM_PLAYER or message.begins_with("A rival"):
		_show_feedback(message, false)
	elif message.contains("Dragon Egg") or message.contains("Shenlong"):
		_show_feedback("A rival is contesting the Shenlong objective.", false)
	elif message.contains("cleared"):
		_show_feedback("The rival cleared a Yaoguai Den and can now capture it.", false)
	elif message.contains("Food"):
		_show_feedback("The rival completed a wildlife hunt.", false)
	else:
		_show_feedback("The rival claimed a Jadeclaw bounty.", false)


func _show_feedback(message: String, is_error: bool = false) -> void:
	audio_director.ensure_bgm()
	if is_error:
		audio_director.play_ui(&"ui_error")
	if _feedback_label == null or _toast_panel == null:
		return
	var color := ThemeFactory.IVORY
	var duration := 2.0
	var lower := message.to_lower()
	if lower.contains("under attack") or lower.contains("population cap") or lower.contains("being seized"):
		color = ThemeFactory.DANGER
		duration = 4.0
	elif is_error:
		color = ThemeFactory.GOLD
		duration = 3.0
	elif lower.contains("captured") or lower.contains("completed") or lower.contains("trained") or lower.contains("foundation placed") or lower.contains("refunded") or lower.contains("deposited"):
		color = ThemeFactory.JADE
		duration = 2.2
	_feedback_label.text = message
	_feedback_label.tooltip_text = message
	_feedback_label.add_theme_color_override(&"font_color", color)
	_toast_panel.add_theme_stylebox_override(&"panel", ThemeFactory.toast_style(color))
	var toast_icon := _toast_panel.get_node_or_null("HBoxContainer/ToastIcon") as HudIcon
	if toast_icon != null:
		toast_icon.glyph_color = color
		toast_icon.queue_redraw()
	_toast_panel.visible = true
	_feedback_timer = duration


func _toggle_pause() -> void:
	if state != STATE_MATCH or simulation == null or not simulation.outcome.is_empty():
		return
	_set_paused(not paused)


func _set_paused(next_paused: bool) -> void:
	if state != STATE_MATCH or simulation == null or not simulation.outcome.is_empty():
		return
	paused = next_paused
	ThemeFactory.set_icon_button_texture(
		_pause_button,
		HUD_UTILITY_ICON_TEXTURES[&"resume" if paused else &"pause"],
	)
	_pause_button.tooltip_text = "Resume the realm" if paused else "Pause the realm"
	if battlefield != null:
		battlefield.set_process(not paused)
	if paused:
		_show_pause_menu()
	else:
		_pause_overlay.visible = false
	audio_director.set_music_state(&"paused" if paused else STATE_MATCH)
	audio_director.play_ui(&"ui_cancel" if paused else &"ui_confirm")
	_show_feedback("The realm is paused." if paused else "The realm resumes.", false)


func _show_pause_menu() -> void:
	if not paused or _pause_overlay == null:
		return
	_pause_overlay.visible = true
	_pause_menu.visible = true
	_settings_menu.visible = false
	_resume_button.call_deferred("grab_focus")


func _show_settings_menu() -> void:
	if not paused or _pause_overlay == null:
		return
	_pause_overlay.visible = true
	_pause_menu.visible = false
	_settings_menu.visible = true
	_update_audio_controls()
	_settings_audio_button.call_deferred("grab_focus")


func _resign_match() -> void:
	if simulation == null:
		return
	simulation.command_resign(RtsSimulation.TEAM_PLAYER)


func _toggle_fog_of_war() -> void:
	if battlefield == null:
		return
	battlefield.set_fog_enabled(not battlefield.fog_enabled)
	audio_director.play_ui(&"ui_confirm")
	_show_feedback("Fog of war enabled." if battlefield.fog_enabled else "Fog of war disabled.", false)


func _toggle_audio() -> void:
	var is_muted := audio_director.toggle_muted()
	_update_audio_controls()
	if not is_muted:
		audio_director.play_ui(&"ui_confirm")


func _update_audio_controls() -> void:
	if _audio_button != null:
		ThemeFactory.set_icon_button_texture(
			_audio_button,
			HUD_UTILITY_ICON_TEXTURES[&"audio_muted" if audio_director.muted else &"audio_on"],
		)
	if _settings_audio_button != null:
		_settings_audio_button.text = "AUDIO: OFF" if audio_director.muted else "AUDIO: ON"
		_settings_audio_button.tooltip_text = (
			"Enable music and sound effects" if audio_director.muted
			else "Mute music and sound effects"
		)


func _on_match_ended(result: StringName) -> void:
	if _match_score_recorded or simulation == null:
		return
	_match_score_recorded = true
	var final_score := simulation.team_score(RtsSimulation.TEAM_PLAYER)
	leaderboard_store.record_match(
		final_score,
		result,
		selected_faction,
		int(simulation.elapsed_time),
	)
	leaderboard_bridge.submit_current()
	paused = true
	state = STATE_RESULT
	if _pause_overlay != null:
		_pause_overlay.visible = false
	audio_director.play_outcome(result)
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
	var title := ThemeFactory.label("VICTORY" if result == &"victory" else "DEFEAT", 30, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := ThemeFactory.label(
		"All three rival Strongholds have fallen." if result == &"victory" else "Your Stronghold has fallen. The remaining mandates endure.",
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
	var result_score := ThemeFactory.label("SCORE: %d" % final_score, 23, ThemeFactory.GOLD)
	result_score.name = "ResultScore"
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_score)
	var rematch := ThemeFactory.button("REMATCH")
	_connect_button(rematch, func() -> void: _start_match(selected_faction))
	column.add_child(rematch)
	_result_leaderboard_button = ThemeFactory.button("LEADERBOARD", "View local and global rankings")
	_result_leaderboard_button.name = "ResultLeaderboardButton"
	_connect_button(_result_leaderboard_button, func() -> void: _open_leaderboard(_result_leaderboard_button))
	column.add_child(_result_leaderboard_button)
	var choose := ThemeFactory.button("CHOOSE ANOTHER FACTION")
	_connect_button(choose, _show_faction_select)
	column.add_child(choose)
	var title_button := ThemeFactory.button("RETURN TO TITLE")
	_connect_button(title_button, _show_title, &"ui_cancel")
	column.add_child(title_button)
	rematch.grab_focus()


func _build_leaderboard_dialog(root: Control) -> void:
	_leaderboard_dialog = LEADERBOARD_DIALOG_SCRIPT.new() as LeaderboardDialog
	root.add_child(_leaderboard_dialog)
	_leaderboard_dialog.configure(leaderboard_store)
	_leaderboard_dialog.set_global_state(
		leaderboard_bridge.state,
		leaderboard_bridge.entries,
		leaderboard_bridge.personal_rank,
	)
	_leaderboard_dialog.global_refresh_requested.connect(leaderboard_bridge.request_list)
	_leaderboard_dialog.callsign_saved.connect(leaderboard_bridge.update_callsign)


func _open_leaderboard(source_button: Button) -> void:
	if _leaderboard_dialog == null:
		return
	_leaderboard_dialog.open(source_button)


func _on_leaderboard_state_changed(next_state: StringName, entries: Array, personal_rank: Dictionary) -> void:
	if _leaderboard_dialog != null:
		_leaderboard_dialog.set_global_state(next_state, entries, personal_rank)


func _on_callsign_sync_changed(sync_state: StringName) -> void:
	if _leaderboard_dialog != null and _leaderboard_dialog.visible:
		_leaderboard_dialog.set_callsign_sync_state(sync_state)


func _connect_button(button: Button, action: Callable, cue: StringName = &"ui_confirm") -> void:
	button.pressed.connect(func() -> void:
		audio_director.ensure_bgm()
		if not cue.is_empty():
			audio_director.play_ui(cue)
		action.call()
	)
