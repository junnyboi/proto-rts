extends Node

const STATE_TITLE := &"title"
const STATE_FACTION := &"faction"
const STATE_MATCH := &"match"
const STATE_RESULT := &"result"
const SHELL_BACKGROUND := preload("res://assets/runtime/backgrounds/jade_meridian_backdrop.webp")
const SHELL_FOREGROUND := preload("res://assets/runtime/foregrounds/jade_meridian_foreground.png")
const PAUSE_FRAME := preload("res://assets/runtime/ui/mandate_pause_frame.png")
const BATTLEFIELD_MINIMAP := preload("res://scripts/view/battlefield_minimap.gd")
const HUD_ICON := preload("res://scripts/ui/hud_icon.gd")
const HUD_COMMAND_BUTTON := preload("res://scripts/ui/hud_command_button.gd")
const LEADERBOARD_STORE_SCRIPT := preload("res://scripts/services/leaderboard_store.gd")
const LEADERBOARD_BRIDGE_SCRIPT := preload("res://scripts/services/leaderboard_bridge.gd")
const LEADERBOARD_DIALOG_SCRIPT := preload("res://scripts/ui/leaderboard_dialog.gd")
const TWEAK_CATALOG := preload("res://config/tweaks/catalog.gd")
const TWEAK_SERVICE_SCRIPT := preload("res://scripts/tuning/tweak_service.gd")
const TWEAK_PANEL_SCRIPT := preload("res://scripts/ui/tweak_panel.gd")
const INPUT_ROUTER_SCRIPT := preload("res://scripts/input/input_router.gd")
const TUTORIAL_DIRECTOR_SCRIPT := preload("res://scripts/tutorial/tutorial_director.gd")
const TUTORIAL_CALLOUT_SCRIPT := preload("res://scripts/ui/tutorial_callout.gd")
const TOUCH_CONTROLS_SCRIPT := preload("res://scripts/ui/touch_controls.gd")
const RESPONSIVE_LAYOUT := preload("res://scripts/ui/responsive_layout.gd")
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
const STRUCTURE_PRODUCTION_LISTS := {
	&"stronghold": [&"worker"],
	&"war_camp": [&"vanguard", &"mystic"],
	&"hunters_lodge": [&"hunter"],
	&"yaoguai_den": [&"jadeclaw"],
}
const COMMAND_VISIBLE_META := &"command_visible_for_update"
const ARMED_TOOLTIP_SUFFIX_KEY := &"ui.command.armed_suffix"
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
var _restart_button: Button
var _return_title_button: Button
var _resign_button: Button
var _settings_audio_button: Button
var _settings_effect_intensity_button: Button
var _settings_reduced_motion_button: Button
var _settings_camera_impulse_button: Button
var _settings_damage_numbers_button: Button
var _settings_back_button: Button
var _tutorial_replay_button: Button
var _confirm_menu: PanelContainer
var _confirm_title: Label
var _confirm_body: Label
var _confirm_accept_button: Button
var _confirm_cancel_button: Button
var _confirm_action: StringName = &""
var _pause_frame: TextureRect
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
var _locale_buttons: Dictionary = {}
var _match_score_recorded := false
var audio_director: AudioDirector
var leaderboard_store: LeaderboardStore
var leaderboard_bridge: LeaderboardBridge
var leaderboard_save_path: String = LeaderboardStore.SAVE_PATH
var tweak_service: TweakService
var tweak_save_path: String = TweakService.SAVE_PATH
var effect_intensity: StringName = &"full"
var reduced_motion := false
var camera_impulse: StringName = &"major"
var damage_numbers: StringName = &"contextual"
var _tweak_layer: Control
var _tweak_button: Button
var _tweak_panel: TweakPanel
var _filter_overlay: ColorRect
var _tweak_previous_focus: Control
var _tweak_previous_paused := false
var _tweak_previous_pause_visible := false
var _tweak_previous_settings_visible := false
var _tweak_button_pressing := false
var input_router: InputRouter
var tutorial_director: TutorialDirector
var tutorial_save_path: String = TutorialDirector.SAVE_PATH
var _tutorial_callout: TutorialCallout
var _touch_controls: TouchControls
var _top_bar_grid: GridContainer
var _command_deck_grid: GridContainer
var _faction_grid: GridContainer
var _faction_scroll: ScrollContainer
var _title_content: VBoxContainer
var _objective_progress_snapshot: Array[bool] = []


func _ready() -> void:
	input_router = INPUT_ROUTER_SCRIPT.new() as InputRouter
	input_router.name = "InputRouter"
	add_child(input_router)
	input_router.method_changed.connect(_on_input_method_changed)
	tutorial_director = TUTORIAL_DIRECTOR_SCRIPT.new() as TutorialDirector
	tutorial_director.name = "TutorialDirector"
	add_child(tutorial_director)
	tutorial_director.setup(tutorial_save_path)
	tutorial_director.callout_changed.connect(_on_tutorial_callout_changed)
	tweak_service = TWEAK_SERVICE_SCRIPT.new() as TweakService
	tweak_service.name = "TweakService"
	add_child(tweak_service)
	tweak_service.setup(tweak_save_path)
	tweak_service.values_changed.connect(_on_tweak_values_changed)
	tweak_service.run_integrity_changed.connect(_on_tweak_integrity_changed)
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
	audio_director.apply_tweak_values(tweak_service.active_values())
	var game_window := get_window()
	game_window.mouse_entered.connect(CursorSystem.resume)
	game_window.mouse_exited.connect(CursorSystem.suspend)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	CursorSystem.resume()
	_show_title()


func _exit_tree() -> void:
	CursorSystem.suspend()


func _process(delta: float) -> void:
	if tutorial_director != null:
		tutorial_director.advance(delta, paused)
	if state == STATE_MATCH and simulation != null:
		if not paused:
			simulation.advance(delta * float(tweak_service.active_value(&"gameplay.time_scale")))
			if input_router != null and input_router.method == InputRouter.GAMEPAD and battlefield != null:
				var camera_stick := Vector2(
					Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
					Input.get_joy_axis(0, JOY_AXIS_LEFT_Y),
				)
				var cursor_stick := Vector2(
					Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
					Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y),
				)
				battlefield.gamepad_pan(camera_stick, delta)
				battlefield.gamepad_move_cursor(cursor_stick, delta)
		_hud_timer -= delta
		if _hud_timer <= 0.0:
			_hud_timer = 0.1
			_update_hud()
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0 and _feedback_label != null:
			_feedback_label.text = ""
			_toast_panel.visible = false


func _input(event: InputEvent) -> void:
	if input_router != null:
		input_router.observe(event)
	if event is InputEventJoypadButton:
		_handle_gamepad_button(event as InputEventJoypadButton)
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if (
		not key.pressed
		or key.echo
		or key.keycode != KEY_SPACE
		or state != STATE_MATCH
		or paused
		or battlefield == null
	):
		return
	var unit_kind := _first_selected_production_kind()
	if unit_kind.is_empty():
		return
	# Handle Space before focused HUD buttons can consume their activation key.
	audio_director.ensure_bgm()
	_command_train(unit_kind)
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	audio_director.ensure_bgm()
	if _tweak_panel != null and _tweak_panel.visible:
		if key.keycode == KEY_ESCAPE:
			_tweak_panel.close_panel()
			get_viewport().set_input_as_handled()
		return
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
				if _confirm_menu != null and _confirm_menu.visible:
					_cancel_abandon_confirmation()
				elif _settings_menu != null and _settings_menu.visible:
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
				or battlefield.context_armed
				or battlefield.placement_worker_id >= 0
			):
				battlefield.cancel_modes()
				audio_director.play_ui(&"ui_cancel")
				_update_armed_command_styles()
				_show_feedback(I18n.t(&"feedback.command_cancelled"), false)
			elif not battlefield.selected_ids.is_empty():
				battlefield.select_entities([])
			else:
				_toggle_pause()
		KEY_P:
			_toggle_pause()
		KEY_Q:
			battlefield.select_all_workers()
			_show_feedback(I18n.t(&"feedback.all_workers_selected"), false)
		KEY_I:
			battlefield.select_all_idle_workers()
			_show_feedback(I18n.t(&"feedback.idle_workers_selected"), false)
		KEY_E:
			battlefield.select_all_army()
			_show_feedback(I18n.t(&"feedback.army_selected"), false)
		KEY_H:
			battlefield.select_player_stronghold()
		KEY_F:
			battlefield.begin_attack_move(key.shift_pressed)
			_update_armed_command_styles()
		KEY_T:
			battlefield.begin_patrol(key.shift_pressed)
			_update_armed_command_styles()
		KEY_R:
			if not battlefield.rotate_structure_placement():
				battlefield.begin_repair(key.shift_pressed)
			_update_armed_command_styles()
		KEY_X:
			_command_stop()


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


func _handle_gamepad_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return
	audio_director.ensure_bgm()
	if state != STATE_MATCH or battlefield == null:
		return
	if event.button_index == JOY_BUTTON_START:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		if event.button_index == JOY_BUTTON_B:
			if _confirm_menu != null and _confirm_menu.visible:
				_cancel_abandon_confirmation()
			elif _settings_menu != null and _settings_menu.visible:
				_show_pause_menu()
			else:
				_set_paused(false)
			get_viewport().set_input_as_handled()
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if event.button_index == JOY_BUTTON_A and focus_owner is BaseButton and focus_owner.is_visible_in_tree():
		# Let Godot's normal ui_accept path activate focused HUD controls.
		return
	match event.button_index:
		JOY_BUTTON_A:
			battlefield.gamepad_primary()
		JOY_BUTTON_X:
			battlefield.gamepad_context()
		JOY_BUTTON_Y:
			battlefield.select_all_army()
			_show_feedback(I18n.t(&"feedback.army_selected"), false)
		JOY_BUTTON_B:
			if (
				battlefield.move_armed
				or battlefield.attack_move_armed
				or battlefield.patrol_armed
				or battlefield.repair_armed
				or battlefield.rally_armed
				or battlefield.context_armed
				or battlefield.placement_worker_id >= 0
			):
				battlefield.cancel_modes()
				_update_armed_command_styles()
			else:
				battlefield.select_entities([])
		JOY_BUTTON_LEFT_SHOULDER:
			battlefield.zoom_by(1.0 / 1.14)
		JOY_BUTTON_RIGHT_SHOULDER:
			battlefield.zoom_by(1.14)
		_:
			return
	get_viewport().set_input_as_handled()


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
	_restart_button = null
	_return_title_button = null
	_resign_button = null
	_confirm_menu = null
	_confirm_title = null
	_confirm_body = null
	_confirm_accept_button = null
	_confirm_cancel_button = null
	_confirm_action = &""
	_pause_frame = null
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
	_locale_buttons.clear()
	_tutorial_replay_button = null
	_tutorial_callout = null
	_touch_controls = null
	_top_bar_grid = null
	_command_deck_grid = null
	_faction_grid = null
	_faction_scroll = null
	_title_content = null
	_objective_progress_snapshot.clear()
	_tweak_layer = null
	_tweak_button = null
	_tweak_panel = null
	_filter_overlay = null
	_tweak_previous_focus = null
	_tweak_button_pressing = false


func _make_screen() -> Control:
	_clear_screen()
	var result := Control.new()
	result.name = "Screen"
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.theme = ThemeFactory.create()
	add_child(result)
	_screen = result
	result.resized.connect(_apply_responsive_layout)
	_apply_responsive_layout.call_deferred()
	return result


func _on_input_method_changed(method: StringName) -> void:
	if tutorial_director != null:
		tutorial_director.set_input_method(method)
	if battlefield != null:
		battlefield.set_gamepad_active(method == InputRouter.GAMEPAD)
	if _touch_controls != null:
		_touch_controls.visible = state == STATE_MATCH and method == InputRouter.TOUCH and not paused
	_apply_responsive_layout()


func _on_tutorial_callout_changed(callout: Dictionary) -> void:
	if _tutorial_callout != null:
		_tutorial_callout.show_callout(callout)
		_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if _screen == null or not is_instance_valid(_screen):
		return
	var viewport_size := _screen.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var safe := RESPONSIVE_LAYOUT.safe_rect(viewport_size, DisplayServer.get_display_safe_area()) as Rect2
	var portrait := RESPONSIVE_LAYOUT.is_portrait(viewport_size) as bool
	if _title_content != null:
		var title_size := RESPONSIVE_LAYOUT.clamped_panel_size(
			Vector2(520.0, 360.0), safe, Vector2(minf(320.0, safe.size.x), 320.0)
		) as Vector2
		_title_content.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_title_content.position = safe.position + (safe.size - title_size) * 0.5
		_title_content.size = title_size
	if _faction_scroll != null:
		_faction_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_faction_scroll.position = safe.position + Vector2(0.0, 68.0)
		_faction_scroll.size = Vector2(safe.size.x, maxf(240.0, safe.size.y - 132.0))
	if _faction_grid != null:
		_faction_grid.columns = 2 if portrait else 4
		for child in _faction_grid.get_children():
			if child is Control:
				(child as Control).custom_minimum_size.x = maxf(
					260.0,
					(safe.size.x - 14.0 * float(_faction_grid.columns - 1)) / float(_faction_grid.columns),
				)
	var top_bar := _screen.get_node_or_null("TopBar") as Control
	var top_height := 190.0 if portrait else 50.0
	if top_bar != null:
		top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		top_bar.position = safe.position
		top_bar.size = Vector2(safe.size.x, top_height)
	if _top_bar_grid != null:
		_top_bar_grid.columns = 3 if portrait else 10
		for child in _top_bar_grid.get_children():
			if child is Control:
				var item := child as Control
				item.custom_minimum_size.x = 0.0 if portrait else item.custom_minimum_size.x
	var deck_height := 598.0 if portrait else 234.0
	if _command_deck != null:
		_command_deck.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_command_deck.position = Vector2(safe.position.x, safe.end.y - deck_height)
		_command_deck.size = Vector2(safe.size.x, deck_height)
	if _command_deck_grid != null:
		_command_deck_grid.columns = 1 if portrait else 3
		var minimap_panel := _command_deck_grid.get_node_or_null("MinimapPanel") as Control
		var selection_panel := _command_deck_grid.get_node_or_null("SelectionBay") as Control
		var command_panel := _command_deck_grid.get_node_or_null("CommandCard") as Control
		if minimap_panel != null:
			minimap_panel.custom_minimum_size = Vector2(0.0 if portrait else 236.0, 188.0 if portrait else 0.0)
		if selection_panel != null:
			selection_panel.custom_minimum_size = Vector2.ZERO if not portrait else Vector2(0.0, 164.0)
		if command_panel != null:
			command_panel.custom_minimum_size = Vector2(0.0 if portrait else 424.0, 218.0 if portrait else 0.0)
	if _objective_panel != null:
		var objective_top := top_height + 8.0
		if portrait and _tutorial_callout != null and _tutorial_callout.visible:
			objective_top += 214.0
		_objective_panel.position = safe.position + Vector2(2.0, objective_top)
		_objective_panel.size.x = minf(326.0, safe.size.x)
	if _toast_panel != null:
		_toast_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_toast_panel.size = Vector2(minf(440.0, safe.size.x), 38.0)
		_toast_panel.position = Vector2(
			safe.position.x + (safe.size.x - _toast_panel.size.x) * 0.5,
			safe.end.y - deck_height - 46.0,
		)
	var touch_height := 0.0
	if _touch_controls != null and _touch_controls.visible:
		touch_height = _touch_controls.occupied_height() + 8.0
		_touch_controls.apply_layout(safe, deck_height + 8.0)
	if _tutorial_callout != null:
		_tutorial_callout.apply_layout(portrait, safe, safe.position.y + top_height + 8.0)
	if _tweak_button != null:
		var tweak_bottom := deck_height + touch_height + 8.0 if state in [STATE_MATCH, STATE_RESULT] else 18.0
		_tweak_button.offset_top = -tweak_bottom - 46.0
		_tweak_button.offset_bottom = -tweak_bottom
	if _pause_frame != null:
		var frame_size := RESPONSIVE_LAYOUT.clamped_panel_size(Vector2(560.0, 660.0), safe, Vector2(360.0, 520.0)) as Vector2
		_pause_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_pause_frame.position = safe.position + (safe.size - frame_size) * 0.5
		_pause_frame.size = frame_size
	for menu in [_pause_menu, _settings_menu, _confirm_menu]:
		if menu == null:
			continue
		var modal := menu as Control
		var preferred_height := 560.0 if modal == _settings_menu else 520.0 if modal == _pause_menu else 380.0
		var modal_size := RESPONSIVE_LAYOUT.clamped_panel_size(Vector2(460.0, preferred_height), safe, Vector2(320.0, 340.0)) as Vector2
		modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
		modal.position = safe.position + (safe.size - modal_size) * 0.5
		modal.size = modal_size


func _build_tweak_access(root: Control) -> void:
	_filter_overlay = ColorRect.new()
	_filter_overlay.name = "FullScreenTweakFilter"
	_filter_overlay.z_index = 150
	_filter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_filter_overlay)

	_tweak_layer = Control.new()
	_tweak_layer.name = "TweakAccessLayer"
	_tweak_layer.z_index = 200
	_tweak_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tweak_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_tweak_layer)
	_tweak_button = ThemeFactory.button(I18n.t(&"tweak.button"), I18n.t(&"tweak.button_tooltip"))
	_tweak_button.name = "TweakControlsButton"
	_tweak_button.accessibility_name = I18n.t(&"tweak.button_accessible")
	_tweak_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_tweak_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var bottom_inset := 256.0 if state in [STATE_MATCH, STATE_RESULT] else 18.0
	_tweak_button.offset_left = -212.0
	_tweak_button.offset_top = -bottom_inset - 46.0
	_tweak_button.offset_right = -18.0
	_tweak_button.offset_bottom = -bottom_inset
	_tweak_button.modulate.a = 0.5
	_tweak_button.mouse_entered.connect(_update_tweak_button_opacity)
	_tweak_button.mouse_exited.connect(_update_tweak_button_opacity)
	_tweak_button.focus_entered.connect(_update_tweak_button_opacity)
	_tweak_button.focus_exited.connect(_update_tweak_button_opacity)
	_tweak_button.button_down.connect(func() -> void:
		_tweak_button_pressing = true
		_update_tweak_button_opacity()
	)
	_tweak_button.button_up.connect(func() -> void:
		_tweak_button_pressing = false
		_update_tweak_button_opacity()
	)
	_tweak_button.pressed.connect(_open_tweak_panel)
	_tweak_layer.add_child(_tweak_button)

	_tweak_panel = TWEAK_PANEL_SCRIPT.new() as TweakPanel
	root.add_child(_tweak_panel)
	_tweak_panel.configure(tweak_service)
	_tweak_panel.value_requested.connect(_on_tweak_value_requested)
	_tweak_panel.reset_requested.connect(_on_tweak_reset_requested)
	_tweak_panel.reset_all_requested.connect(_on_tweak_reset_all_requested)
	_tweak_panel.close_requested.connect(_on_tweak_panel_closed)
	_on_tweak_values_changed()


func _update_tweak_button_opacity() -> void:
	if _tweak_button == null:
		return
	_tweak_button.modulate.a = 1.0 if (
		_tweak_button_pressing or _tweak_button.has_focus() or _tweak_button.is_hovered()
	) else 0.5


func _open_tweak_panel() -> void:
	if _tweak_panel == null or _tweak_panel.visible:
		return
	_tweak_previous_focus = get_viewport().gui_get_focus_owner()
	_tweak_previous_paused = paused
	_tweak_previous_pause_visible = _pause_menu != null and _pause_menu.visible
	_tweak_previous_settings_visible = _settings_menu != null and _settings_menu.visible
	if state == STATE_MATCH and not paused:
		_set_paused(true)
	_tweak_panel.open()


func _on_tweak_panel_closed() -> void:
	if state == STATE_MATCH:
		if _tweak_previous_paused:
			paused = true
			if _pause_overlay != null:
				_pause_overlay.visible = true
				_pause_menu.visible = _tweak_previous_pause_visible
				_settings_menu.visible = _tweak_previous_settings_visible
		else:
			_set_paused(false)
	if is_instance_valid(_tweak_previous_focus) and _tweak_previous_focus.is_visible_in_tree():
		_tweak_previous_focus.call_deferred("grab_focus")
	_tweak_previous_focus = null


func _on_tweak_value_requested(id: StringName, value: Variant) -> void:
	if not tweak_service.set_requested(id, value):
		audio_director.play_ui(&"ui_error")


func _on_tweak_reset_requested(id: StringName) -> void:
	tweak_service.reset_control(id)
	audio_director.play_ui(&"ui_confirm")


func _on_tweak_reset_all_requested() -> void:
	tweak_service.reset_all()
	audio_director.play_ui(&"ui_confirm")


func _on_tweak_values_changed() -> void:
	if tweak_service == null:
		return
	var values := tweak_service.active_values()
	reduced_motion = bool(values.get(&"ui.reduced_motion", false))
	if audio_director != null:
		audio_director.apply_tweak_values(values)
	if simulation != null:
		simulation.set_tweak_values(values)
	if battlefield != null:
		battlefield.configure_effects(effect_intensity, reduced_motion, damage_numbers, camera_impulse)
		battlefield.set_tweak_zoom_multiplier(float(values.get(&"environment.camera.zoom", 1.0)))
		battlefield.set_fog_enabled(bool(values.get(&"environment.fog.enabled", battlefield.fog_enabled)))
	var hud_scale := float(values.get(&"ui.hud.scale", 1.0))
	var hud_opacity := float(values.get(&"ui.hud.opacity", 100.0)) / 100.0
	for node_name: String in ["TopBar", "CommandDeck", "Objective", "AlertToast"]:
		var hud_node := _screen.get_node_or_null(node_name) as Control if _screen != null else null
		if hud_node != null:
			hud_node.pivot_offset = hud_node.size * 0.5
			hud_node.scale = Vector2.ONE * hud_scale
			hud_node.modulate.a = hud_opacity
	if _filter_overlay != null:
		var filter_enabled := bool(values.get(&"environment.filter.enabled", false))
		var filter_intensity := float(values.get(&"environment.filter.intensity", 18.0)) / 100.0
		_filter_overlay.color = Color(0.03, 0.22, 0.16, filter_intensity)
		_filter_overlay.visible = filter_enabled and filter_intensity > 0.0
	if _tweak_panel != null:
		_tweak_panel.refresh()
	_apply_effect_settings()
	_update_audio_controls()


func _on_tweak_integrity_changed(_eligible: bool, _marker: String) -> void:
	if _tweak_panel != null:
		_tweak_panel.refresh()


func _apply_tweak_boundary(mode: StringName) -> void:
	if tweak_service == null:
		return
	tweak_service.apply_boundary(mode)
	if simulation != null:
		simulation.set_tweak_values(tweak_service.active_values())


func _on_battlefield_audio_cue(cue: StringName) -> void:
	if cue in [&"order_move", &"order_attack", &"order_work"]:
		_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
		if tutorial_director != null:
			tutorial_director.notify_event(&"command_issued")
	audio_director.play_cue(cue)


func _add_title_background(root: Control, darkness: float = 0.38) -> void:
	var background := TextureRect.new()
	background.name = "GeneratedShellBackground"
	background.texture = SHELL_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var foreground := TextureRect.new()
	foreground.name = "GeneratedShellForeground"
	foreground.texture = SHELL_FOREGROUND
	foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foreground)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.028, darkness)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)


func _show_title() -> void:
	if tweak_service != null:
		tweak_service.end_run()
	if tutorial_director != null:
		tutorial_director.end_run()
	state = STATE_TITLE
	paused = false
	simulation = null
	audio_director.set_music_state(STATE_TITLE)
	audio_director.ensure_bgm()
	var root := _make_screen()
	_add_title_background(root, 0.42)

	_title_content = VBoxContainer.new()
	_title_content.name = "TitleContent"
	_title_content.custom_minimum_size = Vector2(520, 360)
	_title_content.set_anchors_preset(Control.PRESET_CENTER)
	_title_content.position = Vector2(-260, -180)
	_title_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_content.add_theme_constant_override(&"separation", 18)
	root.add_child(_title_content)

	var title := ThemeFactory.label(I18n.t(&"ui.title.heading"), 48, Color("fff0c8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_content.add_child(title)
	var play := ThemeFactory.button(I18n.t(&"ui.title.start"))
	play.custom_minimum_size = Vector2(340, 56)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_connect_button(play, _show_faction_select)
	_title_content.add_child(play)
	_leaderboard_button = ThemeFactory.button(I18n.t(&"ui.leaderboard"), I18n.t(&"ui.leaderboard_tooltip"))
	_leaderboard_button.name = "TitleLeaderboardButton"
	_leaderboard_button.custom_minimum_size = Vector2(340, 48)
	_leaderboard_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_connect_button(_leaderboard_button, func() -> void: _open_leaderboard(_leaderboard_button))
	_title_content.add_child(_leaderboard_button)
	_tutorial_replay_button = ThemeFactory.button(
		I18n.t(&"tutorial.replay"),
		I18n.t(&"tutorial.replay_tooltip"),
	)
	_tutorial_replay_button.name = "ReplayTutorialButton"
	_tutorial_replay_button.custom_minimum_size = Vector2(340, 48)
	_tutorial_replay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_connect_button(_tutorial_replay_button, _replay_tutorial)
	_title_content.add_child(_tutorial_replay_button)
	_build_locale_selector(_title_content)
	_build_leaderboard_dialog(root)
	_build_tweak_access(root)
	play.grab_focus()


func _build_locale_selector(container: VBoxContainer) -> void:
	var selector := VBoxContainer.new()
	selector.name = "LocaleSelector"
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override(&"separation", 6)
	container.add_child(selector)
	var label := ThemeFactory.label(I18n.t(&"locale.label"), 11, ThemeFactory.MUTED_SAGE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	selector.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for definition: Array in [
		[&"en-US", &"locale.en", "EnglishLocaleButton"],
		[&"zh-CN", &"locale.zh", "ChineseLocaleButton"],
	]:
		var locale_id := definition[0] as StringName
		var button := ThemeFactory.button(I18n.t(definition[1] as StringName))
		button.name = String(definition[2])
		button.custom_minimum_size = Vector2(92.0, 36.0)
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(locale_id == I18n.locale())
		_connect_button(button, _select_locale.bind(locale_id))
		row.add_child(button)
		_locale_buttons[locale_id] = button


func _select_locale(locale_id: StringName) -> void:
	if I18n.set_locale(locale_id):
		_show_title()


func _replay_tutorial() -> void:
	if tutorial_director != null:
		tutorial_director.replay_next_run()
	audio_director.play_ui(&"ui_confirm")
	_show_faction_select()


func _show_faction_select() -> void:
	if tweak_service != null:
		tweak_service.end_run()
	if tutorial_director != null:
		tutorial_director.end_run()
	state = STATE_FACTION
	audio_director.set_music_state(STATE_FACTION)
	var root := _make_screen()
	_add_title_background(root, 0.72)

	var title := ThemeFactory.label(I18n.t(&"ui.faction.choose"), 32, Color("fff0c8"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22
	title.offset_bottom = 64
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_faction_scroll = ScrollContainer.new()
	_faction_scroll.name = "FactionCards"
	_faction_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_faction_scroll.offset_left = 42.0
	_faction_scroll.offset_top = 76.0
	_faction_scroll.offset_right = -42.0
	_faction_scroll.offset_bottom = -76.0
	_faction_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_faction_scroll)
	_faction_grid = GridContainer.new()
	_faction_grid.name = "FactionGrid"
	_faction_grid.columns = 4
	_faction_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_grid.add_theme_constant_override(&"h_separation", 14)
	_faction_grid.add_theme_constant_override(&"v_separation", 14)
	_faction_scroll.add_child(_faction_grid)

	for faction_id in FactionCatalog.ORDER:
		_faction_grid.add_child(_make_faction_card(faction_id))

	var back := ThemeFactory.button(I18n.t(&"ui.faction.back"))
	back.position = Vector2(20, 18)
	back.size = Vector2(110, 40)
	_connect_button(back, _show_title, &"ui_cancel")
	root.add_child(back)

	var controls := ThemeFactory.label(I18n.t(&"ui.faction.controls"), 14, ThemeFactory.MUTED)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 120
	controls.offset_right = -120
	controls.offset_top = -64
	controls.offset_bottom = -8
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(controls)
	_build_tweak_access(root)


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
	var faction_name := I18n.t(FactionCatalog.faction_text_key(faction_id, &"name"))
	var name_label := ThemeFactory.label(faction_name, 23, definition["accent"] as Color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var identity := ThemeFactory.label(I18n.t(FactionCatalog.faction_text_key(faction_id, &"identity")), 15, ThemeFactory.PARCHMENT)
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(identity)
	var passive := ThemeFactory.label(I18n.t(FactionCatalog.faction_text_key(faction_id, &"passive")), 13, ThemeFactory.MUTED)
	passive.custom_minimum_size.y = 62
	passive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(passive)
	var button_spacer := Control.new()
	button_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(button_spacer)
	var choose := ThemeFactory.button(I18n.t(&"ui.faction.command", {"faction": faction_name.to_upper()}))
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
	tweak_service.begin_run()
	audio_director.set_music_state(STATE_MATCH)
	audio_director.ensure_bgm()
	simulation = RtsSimulation.new()
	simulation.tweak_boundary_reached.connect(_apply_tweak_boundary)
	simulation.set_tweak_values(tweak_service.active_values())
	simulation.setup(faction_id)
	simulation.match_ended.connect(_on_match_ended)
	simulation.battle_notice.connect(_on_battle_notice)
	var root := _make_screen()

	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield.set_simulation(simulation)
	battlefield.configure_effects(effect_intensity, reduced_motion, damage_numbers, camera_impulse)
	battlefield.selection_changed.connect(_on_selection_changed)
	battlefield.feedback.connect(_show_feedback)
	battlefield.audio_cue.connect(_on_battlefield_audio_cue)
	battlefield.simulation_event.connect(audio_director.handle_simulation_event)
	root.add_child(battlefield)

	_build_top_bar(root)
	_build_bottom_hud(root)
	_build_help_panel(root)
	_build_leaderboard_dialog(root)
	_build_tweak_access(root)
	_build_touch_controls(root)
	_build_tutorial_callout(root)
	if tutorial_director != null:
		tutorial_director.set_input_method(input_router.method if input_router != null else InputRouter.KEYBOARD_MOUSE)
		tutorial_director.start_run()
	_on_input_method_changed(input_router.method if input_router != null else InputRouter.KEYBOARD_MOUSE)
	_update_hud()
	_show_feedback(I18n.t(&"feedback.match_intro"), false)
	_apply_responsive_layout.call_deferred()


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
	_top_bar_grid = GridContainer.new()
	_top_bar_grid.name = "TopBarGrid"
	_top_bar_grid.columns = 10
	_top_bar_grid.add_theme_constant_override(&"h_separation", 5)
	_top_bar_grid.add_theme_constant_override(&"v_separation", 5)
	panel.add_child(_top_bar_grid)
	_score_label = ThemeFactory.label(I18n.t(&"ui.hud.score", {"score": 0}), 14, ThemeFactory.GOLD)
	_score_label.name = "ScoreLabel"
	_score_label.custom_minimum_size.x = 222
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar_grid.add_child(_score_label)
	_add_resource_chip(_top_bar_grid, &"jade", &"jade", I18n.t(&"ui.hud.jade"), ThemeFactory.JADE, 88.0)
	_add_resource_chip(_top_bar_grid, &"lumber", &"lumber", I18n.t(&"ui.hud.lumber"), ThemeFactory.LUMBER, 100.0)
	_add_resource_chip(_top_bar_grid, &"essence", &"essence", I18n.t(&"ui.hud.essence"), ThemeFactory.ESSENCE, 108.0)
	_add_resource_chip(_top_bar_grid, &"food", &"food", I18n.t(&"ui.hud.food"), ThemeFactory.FOOD, 136.0)
	_add_resource_chip(_top_bar_grid, &"population", &"population", I18n.t(&"ui.hud.population"), ThemeFactory.IVORY, 88.0)
	_add_resource_chip(_top_bar_grid, &"dens", &"den", I18n.t(&"ui.hud.dens"), ThemeFactory.GOLD, 82.0)
	_add_resource_chip(_top_bar_grid, &"time", &"clock", I18n.t(&"ui.hud.time"), ThemeFactory.MUTED, 82.0)
	_pause_button = ThemeFactory.icon_button(HUD_UTILITY_ICON_TEXTURES[&"pause"], I18n.t(&"ui.hud.pause"))
	_pause_button.name = "PauseButton"
	_pause_button.pressed.connect(_toggle_pause)
	_top_bar_grid.add_child(_pause_button)
	_audio_button = ThemeFactory.icon_button(
		HUD_UTILITY_ICON_TEXTURES[&"audio_muted" if audio_director.muted else &"audio_on"],
		I18n.t(&"ui.hud.audio_tooltip"),
	)
	_audio_button.name = "AudioButton"
	_audio_button.pressed.connect(_toggle_audio)
	_top_bar_grid.add_child(_audio_button)


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
	_command_deck_grid = GridContainer.new()
	_command_deck_grid.name = "CommandDeckGrid"
	_command_deck_grid.columns = 3
	_command_deck_grid.add_theme_constant_override(&"h_separation", 7)
	_command_deck_grid.add_theme_constant_override(&"v_separation", 7)
	_command_deck.add_child(_command_deck_grid)
	_command_deck_grid.add_child(_build_minimap_bay())
	_command_deck_grid.add_child(_build_selection_bay())
	_command_deck_grid.add_child(_build_command_bay())
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
	var title := ThemeFactory.label(I18n.t(&"ui.hud.map_name"), 11, ThemeFactory.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var map_state := ThemeFactory.label(I18n.t(&"ui.hud.map_state"), 9, ThemeFactory.MUTED_SAGE)
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
	utilities.add_child(_make_utility_button("Q", I18n.t(&"ui.hud.select_workers"), func() -> void: battlefield.select_all_workers()))
	utilities.add_child(_make_utility_button("I", I18n.t(&"ui.hud.select_idle_workers"), func() -> void: battlefield.select_all_idle_workers()))
	utilities.add_child(_make_utility_button("E", I18n.t(&"ui.hud.select_army"), func() -> void: battlefield.select_all_army()))
	utilities.add_child(_make_utility_button("H", I18n.t(&"ui.hud.select_stronghold"), func() -> void: battlefield.select_player_stronghold()))
	_fog_button = _make_utility_button("", I18n.t(&"ui.hud.fog_toggle"), _toggle_fog_of_war, &"fog")
	_fog_button.name = "FogToggle"
	_fog_icon = _fog_button.get_node("Icon") as HudIcon
	utilities.add_child(_fog_button)
	utilities.add_child(_make_utility_button("−", I18n.t(&"ui.hud.zoom_out"), func() -> void: battlefield.zoom_by(1.0 / 1.14)))
	utilities.add_child(_make_utility_button("+", I18n.t(&"ui.hud.zoom_in"), func() -> void: battlefield.zoom_by(1.14)))
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
	_selection_title = ThemeFactory.label(I18n.t(&"ui.selection.no_selection"), 20, ThemeFactory.GOLD)
	_selection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_title.clip_text = true
	title_row.add_child(_selection_title)
	_selection_status = ThemeFactory.label(I18n.t(&"ui.selection.command"), 10, ThemeFactory.JADE)
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
	_selection_order = ThemeFactory.label(I18n.t(&"ui.selection.select_prompt"), 13, ThemeFactory.IVORY)
	_selection_order.clip_text = true
	info.add_child(_selection_order)
	_selection_meta = ThemeFactory.label(I18n.t(&"ui.selection.quick_select"), 11, ThemeFactory.JADE)
	_selection_meta.clip_text = true
	info.add_child(_selection_meta)
	_selection_detail = ThemeFactory.label(I18n.t(&"ui.selection.select_instruction"), 11, ThemeFactory.MUTED_SAGE)
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
	var title := ThemeFactory.label(I18n.t(&"ui.production.title"), 9, ThemeFactory.GOLD)
	title_column.add_child(title)
	var hint := ThemeFactory.label(I18n.t(&"ui.production.cancel_hint"), 8, ThemeFactory.MUTED_SAGE)
	title_column.add_child(hint)
	for index in range(5):
		var tile := ThemeFactory.button("", I18n.t(&"ui.production.cancel_unit_tooltip"))
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
	_add_command_button(0, &"build", I18n.t(&"ui.command.war_camp"), func() -> void: _command_build(&"war_camp"), load(FactionCatalog.entity_art_path(faction, &"war_camp")) as Texture2D)
	_add_command_button(1, &"build_farm", I18n.t(&"ui.command.rice_farm"), func() -> void: _command_build(&"rice_farm"), load(FactionCatalog.entity_art_path(faction, &"rice_farm")) as Texture2D)
	_add_command_button(2, &"build_lodge", I18n.t(&"ui.command.hunters_lodge"), func() -> void: _command_build(&"hunters_lodge"), load(FactionCatalog.entity_art_path(faction, &"hunters_lodge")) as Texture2D)
	_add_command_button(3, &"build_wall", I18n.t(&"ui.command.wall"), func() -> void: _command_build(&"wall"), load(FactionCatalog.entity_art_path(faction, &"wall")) as Texture2D)
	_add_command_button(4, &"build_gate", I18n.t(&"ui.command.wood_gate"), func() -> void: _command_build(&"gate"), load(FactionCatalog.entity_art_path(faction, &"gate")) as Texture2D)
	_add_command_button(5, &"build_tower", I18n.t(&"ui.command.sentry_tower"), func() -> void: _command_build(&"sentry_tower"), load(FactionCatalog.entity_art_path(faction, &"sentry_tower")) as Texture2D)
	_add_command_button(0, &"worker", I18n.t(&"ui.command.worker"), func() -> void: _command_train(&"worker"), load(FactionCatalog.entity_art_path(faction, &"worker")) as Texture2D, &"objective", I18n.t(&"ui.hotkey.space"))
	_add_command_button(1, &"stronghold_upgrade", I18n.t(&"ui.command.upgrade", {"level": 2}), _command_upgrade_stronghold, null, &"population")
	var hunter_icon: Texture2D = null
	if FactionCatalog.can_train_unit(faction, &"hunter"):
		hunter_icon = load(FactionCatalog.entity_art_path(faction, &"hunter")) as Texture2D
	_add_command_button(0, &"hunter", I18n.t(&"ui.command.hunter"), func() -> void: _command_train(&"hunter"), hunter_icon, &"objective", I18n.t(&"ui.hotkey.space"))
	_add_command_button(0, &"vanguard", I18n.t(&"ui.command.vanguard"), func() -> void: _command_train(&"vanguard"), load(FactionCatalog.entity_art_path(faction, &"vanguard")) as Texture2D, &"objective", I18n.t(&"ui.hotkey.space"))
	_add_command_button(1, &"mystic", I18n.t(&"ui.command.mystic"), func() -> void: _command_train(&"mystic"), load(FactionCatalog.entity_art_path(faction, &"mystic")) as Texture2D)
	_add_command_button(0, &"jadeclaw", I18n.t(&"ui.command.jadeclaw"), func() -> void: _command_train(&"jadeclaw"), load(FactionCatalog.entity_art_path(faction, &"jadeclaw")) as Texture2D, &"objective", I18n.t(&"ui.hotkey.space"))
	_add_command_button(6, &"move", I18n.t(&"ui.command.move"), func() -> void:
		battlefield.begin_move(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"move")
	_add_command_button(7, &"attack_move", I18n.t(&"ui.command.attack_move"), func() -> void:
		battlefield.begin_attack_move(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"attack_move", "F")
	_add_command_button(8, &"patrol", I18n.t(&"ui.command.patrol"), func() -> void:
		battlefield.begin_patrol(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"patrol", "T")
	_add_command_button(9, &"repair", I18n.t(&"ui.command.repair"), func() -> void:
		battlefield.begin_repair(Input.is_key_pressed(KEY_SHIFT))
		_update_armed_command_styles()
	, null, &"repair", "R")
	_add_command_button(10, &"rally", I18n.t(&"ui.command.rally"), func() -> void:
		battlefield.begin_rally()
		_update_armed_command_styles()
	, null, &"rally")
	_add_command_button(9, &"demolish", I18n.t(&"ui.command.demolish"), _command_demolish, null, &"cancel")
	_add_command_button(11, &"stop", I18n.t(&"ui.command.stop"), _command_stop, null, &"stop", "X")
	_add_command_button(11, &"cancel_queue", I18n.t(&"ui.command.cancel_last"), _command_cancel_training, null, &"cancel")
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
	button.set_reduced_motion(reduced_motion)
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
	_pause_overlay.z_index = 190
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_pause_overlay)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.02, 0.022, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)
	_pause_frame = TextureRect.new()
	_pause_frame.name = "GeneratedPauseFrame"
	_pause_frame.texture = PAUSE_FRAME
	_pause_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pause_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_frame.set_anchors_preset(Control.PRESET_CENTER)
	_pause_frame.position = Vector2(-280.0, -330.0)
	_pause_frame.size = Vector2(560.0, 660.0)
	_pause_overlay.add_child(_pause_frame)

	_pause_menu = _make_modal_menu("PauseMenu", I18n.t(&"ui.pause.paused"), I18n.t(&"ui.pause.mandate_waits"))
	_pause_menu.position = Vector2(-210.0, -260.0)
	_pause_menu.size = Vector2(420.0, 520.0)
	_pause_overlay.add_child(_pause_menu)
	var pause_column := _pause_menu.get_node("MenuColumn") as VBoxContainer
	_resume_button = _make_modal_button(I18n.t(&"ui.pause.resume"), I18n.t(&"ui.pause.resume_tooltip"))
	_resume_button.name = "ResumeButton"
	_connect_button(_resume_button, func() -> void: _set_paused(false))
	pause_column.add_child(_resume_button)
	_settings_button = _make_modal_button(I18n.t(&"ui.pause.settings"), I18n.t(&"ui.pause.open_settings"))
	_settings_button.name = "SettingsButton"
	_connect_button(_settings_button, _show_settings_menu)
	pause_column.add_child(_settings_button)
	_restart_button = _make_modal_button(I18n.t(&"ui.pause.restart"), I18n.t(&"ui.pause.restart_tooltip"))
	_restart_button.name = "RestartButton"
	_connect_button(_restart_button, _show_abandon_confirmation.bind(&"restart"), &"ui_cancel")
	pause_column.add_child(_restart_button)
	_return_title_button = _make_modal_button(I18n.t(&"ui.pause.return_title"), I18n.t(&"ui.pause.return_title_tooltip"))
	_return_title_button.name = "ReturnTitleButton"
	_connect_button(_return_title_button, _show_abandon_confirmation.bind(&"title"), &"ui_cancel")
	pause_column.add_child(_return_title_button)
	_resign_button = _make_modal_button(I18n.t(&"ui.pause.resign"), I18n.t(&"ui.pause.resign_tooltip"))
	_resign_button.name = "ResignButton"
	_resign_button.add_theme_color_override(&"font_color", ThemeFactory.DANGER)
	_resign_button.add_theme_color_override(&"font_hover_color", Color("ff8b7f"))
	_connect_button(_resign_button, _resign_match, &"ui_cancel")
	pause_column.add_child(_resign_button)
	var pause_hint := ThemeFactory.label(I18n.t(&"ui.pause.resume_hint"), 12, ThemeFactory.MUTED_SAGE)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_column.add_child(pause_hint)

	_settings_menu = _make_modal_menu("SettingsMenu", I18n.t(&"ui.pause.settings"), I18n.t(&"ui.pause.game_options"))
	_settings_menu.position = Vector2(-230.0, -280.0)
	_settings_menu.size = Vector2(460.0, 560.0)
	_pause_overlay.add_child(_settings_menu)
	var settings_column := _settings_menu.get_node("MenuColumn") as VBoxContainer
	var audio_heading := ThemeFactory.label(I18n.t(&"ui.pause.audio"), 12, ThemeFactory.MUTED_SAGE)
	audio_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_column.add_child(audio_heading)
	_settings_audio_button = _make_modal_button("", I18n.t(&"ui.hud.audio_tooltip"))
	_settings_audio_button.name = "AudioSettingButton"
	_connect_button(_settings_audio_button, _toggle_audio, &"")
	settings_column.add_child(_settings_audio_button)
	var effects_heading := ThemeFactory.label(I18n.t(&"ui.pause.presentation"), 12, ThemeFactory.MUTED_SAGE)
	effects_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_column.add_child(effects_heading)
	_settings_effect_intensity_button = _make_modal_button("", I18n.t(&"ui.pause.effects_tooltip"))
	_settings_effect_intensity_button.name = "EffectIntensityButton"
	_connect_button(_settings_effect_intensity_button, _cycle_effect_intensity)
	settings_column.add_child(_settings_effect_intensity_button)
	_settings_reduced_motion_button = _make_modal_button("", I18n.t(&"ui.pause.reduced_motion_tooltip"))
	_settings_reduced_motion_button.name = "ReducedMotionButton"
	_connect_button(_settings_reduced_motion_button, _toggle_reduced_motion)
	settings_column.add_child(_settings_reduced_motion_button)
	_settings_camera_impulse_button = _make_modal_button("", I18n.t(&"ui.pause.camera_impulse_tooltip"))
	_settings_camera_impulse_button.name = "CameraImpulseButton"
	_connect_button(_settings_camera_impulse_button, _cycle_camera_impulse)
	settings_column.add_child(_settings_camera_impulse_button)
	_settings_damage_numbers_button = _make_modal_button("", I18n.t(&"ui.pause.damage_values_tooltip"))
	_settings_damage_numbers_button.name = "DamageNumbersButton"
	_connect_button(_settings_damage_numbers_button, _cycle_damage_numbers)
	settings_column.add_child(_settings_damage_numbers_button)
	var settings_spacer := Control.new()
	settings_spacer.custom_minimum_size.y = 10.0
	settings_column.add_child(settings_spacer)
	_settings_back_button = _make_modal_button(I18n.t(&"ui.pause.back"), I18n.t(&"ui.pause.back_tooltip"))
	_settings_back_button.name = "SettingsBackButton"
	_connect_button(_settings_back_button, _show_pause_menu, &"ui_cancel")
	settings_column.add_child(_settings_back_button)
	var settings_hint := ThemeFactory.label(I18n.t(&"ui.pause.go_back_hint"), 12, ThemeFactory.MUTED_SAGE)
	settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_column.add_child(settings_hint)

	_confirm_menu = _make_modal_menu(
		"AbandonConfirmation",
		I18n.t(&"ui.pause.confirm_title"),
		I18n.t(&"ui.pause.confirm_subtitle"),
	)
	_confirm_menu.position = Vector2(-210.0, -190.0)
	_confirm_menu.size = Vector2(420.0, 380.0)
	_pause_overlay.add_child(_confirm_menu)
	var confirm_column := _confirm_menu.get_node("MenuColumn") as VBoxContainer
	_confirm_title = _confirm_menu.get_node("MenuColumn/ModalTitle") as Label
	_confirm_body = ThemeFactory.label("", 14, ThemeFactory.IVORY)
	_confirm_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.custom_minimum_size = Vector2(340.0, 72.0)
	confirm_column.add_child(_confirm_body)
	_confirm_accept_button = _make_modal_button(I18n.t(&"ui.pause.confirm_accept"), I18n.t(&"ui.pause.confirm_accept_tooltip"))
	_confirm_accept_button.name = "ConfirmAbandonButton"
	_confirm_accept_button.add_theme_color_override(&"font_color", ThemeFactory.DANGER)
	_connect_button(_confirm_accept_button, _accept_abandon_confirmation, &"ui_cancel")
	confirm_column.add_child(_confirm_accept_button)
	_confirm_cancel_button = _make_modal_button(I18n.t(&"ui.pause.confirm_cancel"), I18n.t(&"ui.pause.confirm_cancel_tooltip"))
	_confirm_cancel_button.name = "CancelAbandonButton"
	_connect_button(_confirm_cancel_button, _cancel_abandon_confirmation, &"ui_cancel")
	confirm_column.add_child(_confirm_cancel_button)

	_update_audio_controls()
	_update_effect_controls()
	_pause_overlay.visible = false
	_settings_menu.visible = false
	_confirm_menu.visible = false


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
	title.name = "ModalTitle"
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
	_objective_toggle = ThemeFactory.button(I18n.t(&"ui.objective.title_expanded"), I18n.t(&"ui.objective.tooltip"))
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


func _build_touch_controls(root: Control) -> void:
	_touch_controls = TOUCH_CONTROLS_SCRIPT.new() as TouchControls
	root.add_child(_touch_controls)
	_touch_controls.workers_requested.connect(func() -> void:
		battlefield.select_all_workers()
		_show_feedback(I18n.t(&"feedback.all_workers_selected"), false)
	)
	_touch_controls.army_requested.connect(func() -> void:
		battlefield.select_all_army()
		_show_feedback(I18n.t(&"feedback.army_selected"), false)
	)
	_touch_controls.move_requested.connect(func() -> void:
		battlefield.begin_move(false)
		_update_armed_command_styles()
	)
	_touch_controls.attack_requested.connect(func() -> void:
		battlefield.begin_attack_move(false)
		_update_armed_command_styles()
	)
	_touch_controls.context_requested.connect(func() -> void:
		battlefield.begin_context_order()
		_update_armed_command_styles()
	)
	_touch_controls.cancel_requested.connect(func() -> void:
		battlefield.cancel_modes()
		_update_armed_command_styles()
		audio_director.play_ui(&"ui_cancel")
		_show_feedback(I18n.t(&"feedback.command_cancelled"), false)
	)


func _build_tutorial_callout(root: Control) -> void:
	_tutorial_callout = TUTORIAL_CALLOUT_SCRIPT.new() as TutorialCallout
	root.add_child(_tutorial_callout)
	_tutorial_callout.skip_requested.connect(func() -> void:
		if tutorial_director != null:
			tutorial_director.skip()
	)


func _build_minimap(root: Control) -> void:
	# The minimap is integrated into the bottom command deck.
	pass


func _update_hud() -> void:
	if simulation == null or simulation.players.is_empty() or _resource_values.is_empty():
		return
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var player_definition := FactionCatalog.definition(player["faction"] as StringName)
	_score_label.text = I18n.t(&"ui.hud.score", {"score": simulation.team_score(RtsSimulation.TEAM_PLAYER)})
	_score_label.add_theme_color_override(&"font_color", player_definition["accent"] as Color)
	var minutes := floori(simulation.elapsed_time / 60.0)
	var seconds := int(simulation.elapsed_time) % 60
	(_resource_values[&"jade"] as Label).text = "%d" % int(player["jade"])
	(_resource_values[&"lumber"] as Label).text = "%d" % int(player["lumber"])
	(_resource_values[&"essence"] as Label).text = "%d" % int(player["essence"])
	(_resource_values[&"food"] as Label).text = I18n.t(&"ui.hud.food_value", {
		"amount": int(player["food"]),
		"rate": "%.1f" % simulation.food_income_per_second(RtsSimulation.TEAM_PLAYER),
	})
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
		_fog_button.tooltip_text = I18n.t(&"ui.hud.fog_on") if battlefield.fog_enabled else I18n.t(&"ui.hud.fog_off")


func _on_selection_changed(ids: Array) -> void:
	if tutorial_director != null:
		for id_value in ids:
			var entity_state := simulation.entity(int(id_value))
			if int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER:
				tutorial_director.notify_event(&"select_player")
				break
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
	if _objective_progress_snapshot.is_empty():
		_objective_progress_snapshot.assign(completed)
	else:
		for index in range(completed.size()):
			if completed[index] and not _objective_progress_snapshot[index]:
				if tutorial_director != null:
					tutorial_director.notify_event(&"objective_progressed")
				break
		_objective_progress_snapshot.assign(completed)
	var copy: Array[String] = [
		I18n.t(&"ui.objective.food_supply", {"count": mini(food_buildings, 1), "total": 1}),
		I18n.t(&"ui.objective.capture_den", {"count": dens, "total": MapCatalog.CAVES.size()}),
		I18n.t(&"ui.objective.hatch_egg", {"count": mini(player_shenlongs.size(), 1), "total": 1}),
		I18n.t(&"ui.objective.defeat_rivals", {"count": rivals_defeated, "total": RtsSimulation.TEAM_COUNT - 1}),
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
	_objective_toggle.text = I18n.t(&"ui.objective.title_collapsed") if _objective_collapsed else I18n.t(&"ui.objective.title_expanded")


func _update_selection_panel() -> void:
	if battlefield == null or _selection_title == null:
		return
	var ids: Array[int] = battlefield.selected_ids
	var rebuild_selection_stacks := _reconcile_selection_stacks(ids)
	_selection_health.visible = true
	_selection_health_label.visible = true
	_selection_portrait.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if ids.is_empty()
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	if ids.is_empty():
		_selection_portrait.texture = load(FactionCatalog.portrait_path(selected_faction)) as Texture2D
		_selection_portrait_frame.add_theme_stylebox_override(&"panel", ThemeFactory.portrait_style(FactionCatalog.definition(selected_faction)["accent"] as Color))
		_selection_title.text = I18n.t(&"ui.selection.no_selection")
		_selection_status.text = I18n.t(&"ui.selection.command")
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
		_selection_health.visible = false
		_selection_health_label.visible = false
		_selection_order.text = I18n.t(&"ui.selection.select_prompt")
		_selection_meta.text = I18n.t(&"ui.selection.quick_select")
		_selection_detail.text = I18n.t(&"ui.selection.select_instruction")
		return
	if ids.size() > 1:
		_update_group_selection(ids, rebuild_selection_stacks)
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
				_update_owned_selection(entity_state, rebuild_selection_stacks)


func _selection_stack_key(ids: Array[int]) -> String:
	if ids.size() > 1:
		var selected_id_parts := PackedStringArray()
		for id in ids:
			selected_id_parts.append(str(id))
		return "group:%s" % ",".join(selected_id_parts)
	if ids.size() != 1:
		return ""
	var entity_state := simulation.entity(ids[0])
	if (
		entity_state.is_empty()
		or entity_state.get("category") != &"structure"
		or entity_state.get("kind") != &"sentry_tower"
		or int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER
		or float(entity_state.get("complete", 0.0)) < 1.0
	):
		return ""
	var occupants := entity_state.get("garrisoned_unit_ids", []) as Array
	if occupants.is_empty():
		return ""
	var occupant_id_parts := PackedStringArray()
	for raw_id in occupants:
		occupant_id_parts.append(str(int(raw_id)))
	return "garrison:%d:%s" % [int(entity_state["id"]), ",".join(occupant_id_parts)]


func _reconcile_selection_stacks(ids: Array[int]) -> bool:
	var next_key := _selection_stack_key(ids)
	_selection_stacks.visible = not next_key.is_empty()
	var current_key := String(_selection_stacks.get_meta(&"contents_key", ""))
	if next_key == current_key:
		return false
	_selection_stacks.set_meta(&"contents_key", next_key)
	for child in _selection_stacks.get_children():
		_selection_stacks.remove_child(child)
		child.queue_free()
	return true


func _update_group_selection(ids: Array[int], rebuild_selection_stacks: bool) -> void:
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
	_selection_title.text = I18n.t(&"ui.selection.group_title", {"count": ids.size()})
	_selection_status.text = I18n.t(&"ui.selection.group")
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
	_set_selection_progress(current_hp, maximum_hp, I18n.t(&"ui.selection.total_health", {"current": int(current_hp), "maximum": int(maximum_hp)}), ThemeFactory.JADE)
	_selection_order.text = I18n.t(&"ui.selection.mixed_orders") if mixed_orders else _order_label({"order": shared_order}).to_upper()
	_selection_meta.text = I18n.t(&"ui.selection.group_meta", {"count": groups.size()})
	_selection_detail.text = I18n.t(&"ui.selection.group_detail")
	_selection_stacks.visible = true
	if not rebuild_selection_stacks:
		return
	var group_kinds := groups.keys()
	group_kinds.sort()
	for raw_kind in group_kinds:
		var kind := raw_kind as StringName
		var subgroup: Array[int] = []
		for raw_id in groups[kind] as Array:
			subgroup.append(int(raw_id))
		var sample := simulation.entity(subgroup[0])
		var stack := ThemeFactory.button(I18n.t(&"ui.selection.stack", {"unit": I18n.t(FactionCatalog.entity_text_key(kind)), "count": subgroup.size()}), I18n.t(&"ui.selection.select_only_type"))
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
		_show_feedback(I18n.t(&"feedback.unit_ungarrisoned"), false)
	else:
		_show_feedback(I18n.t(&"feedback.unit_ungarrison_failed"), true)


func _update_resource_selection(entity_state: Dictionary) -> void:
	var resource_kind := entity_state.get("resource_kind", &"jade") as StringName
	var resource_name := I18n.t(&"resource.jade.name")
	var resource_color := ThemeFactory.JADE
	if resource_kind == &"lumber":
		resource_name = I18n.t(&"resource.lumber.name")
		resource_color = ThemeFactory.LUMBER
	elif resource_kind == &"essence":
		resource_name = I18n.t(&"resource.essence.name")
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
	_selection_status.text = I18n.t(&"ui.selection.resource")
	_selection_status.add_theme_color_override(&"font_color", resource_color)
	_set_selection_progress(amount, max_amount, I18n.t(&"ui.selection.remain", {"amount": int(amount)}), resource_color)
	_selection_order.text = I18n.t(&"ui.selection.workers_assigned", {"count": assigned})
	_selection_meta.text = I18n.t(StringName("value.%s" % resource_kind)).to_upper()
	_selection_detail.text = I18n.t(&"ui.selection.resource_detail")


func _update_wildlife_selection(entity_state: Dictionary) -> void:
	var reaction := I18n.t(&"ui.selection.wildlife_retaliates") if bool(entity_state.get("retaliates", false)) else I18n.t(&"ui.selection.wildlife_flees")
	_selection_title.text = I18n.t(FactionCatalog.entity_text_key(entity_state["kind"] as StringName)).to_upper()
	_selection_status.text = I18n.t(&"ui.selection.wildlife")
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.FOOD)
	_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), I18n.t(&"ui.selection.health", {"current": int(entity_state["hp"]), "maximum": int(entity_state["max_hp"])}), ThemeFactory.JADE)
	_selection_order.text = reaction
	_selection_meta.text = I18n.t(&"ui.selection.food_bounty", {"amount": int(entity_state.get("food_bounty", 0))})
	_selection_detail.text = I18n.t(&"ui.selection.wildlife_detail", {"role": I18n.t(FactionCatalog.entity_text_key(entity_state["kind"] as StringName, &"role"))})


func _update_den_selection(entity_state: Dictionary) -> void:
	var owner := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	var guardians := simulation.cave_guardian_count(int(entity_state["id"]))
	var progress := float(entity_state.get("capture_progress", 0.0))
	var contested := bool(entity_state.get("capture_contested", false))
	_selection_title.text = I18n.t(FactionCatalog.entity_text_key(&"yaoguai_den")).to_upper()
	if guardians > 0:
		_selection_status.text = I18n.t(&"ui.selection.guarded")
	elif contested:
		_selection_status.text = I18n.t(&"ui.selection.capture_contested")
	elif owner == RtsSimulation.TEAM_PLAYER:
		_selection_status.text = I18n.t(&"ui.selection.controlled")
	elif owner > RtsSimulation.TEAM_PLAYER:
		_selection_status.text = I18n.t(&"ui.selection.rival")
	else:
		_selection_status.text = I18n.t(&"ui.selection.cleared")
	var status_color := ThemeFactory.DANGER if contested or owner > RtsSimulation.TEAM_PLAYER else ThemeFactory.GOLD if owner == RtsSimulation.TEAM_NEUTRAL else ThemeFactory.JADE
	_selection_status.add_theme_color_override(&"font_color", status_color)
	if progress > 0.0 or contested:
		_set_selection_progress(progress, RtsSimulation.CAVE_CAPTURE_SECONDS, I18n.t(&"ui.selection.capture_progress", {"percent": int(100.0 * progress / RtsSimulation.CAVE_CAPTURE_SECONDS)}), status_color)
	else:
		_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), I18n.t(&"ui.selection.health", {"current": int(entity_state["hp"]), "maximum": int(entity_state["max_hp"])}), ThemeFactory.JADE)
	if guardians > 0:
		_selection_order.text = I18n.t(&"ui.selection.guardians_remain", {"count": guardians})
	elif owner == RtsSimulation.TEAM_PLAYER:
		_selection_order.text = I18n.t(&"ui.selection.den_secured")
	elif contested:
		_selection_order.text = I18n.t(&"ui.selection.capture_contested")
	else:
		_selection_order.text = I18n.t(&"ui.selection.hold_ring")
	var queue := entity_state.get("queue", []) as Array
	_selection_meta.text = I18n.t(&"ui.selection.queue_meta", {"count": queue.size(), "rally": _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)}) if owner == RtsSimulation.TEAM_PLAYER else I18n.t(&"ui.selection.capture_objective")
	if not queue.is_empty():
		var item := queue[0] as Dictionary
		_selection_detail.text = I18n.t(&"ui.selection.den_detail_training", {"seconds": "%.1f" % float(item.get("remaining", 0.0)), "rally": _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)})
	elif guardians > 0:
		_selection_detail.text = I18n.t(&"ui.selection.den_detail_guardians")
	else:
		_selection_detail.text = I18n.t(&"ui.selection.den_detail_capture", {"rally": _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)})


func _update_egg_selection(entity_state: Dictionary) -> void:
	var carrier := simulation.entity(int(entity_state.get("carried_by", -1)))
	_selection_title.text = I18n.t(&"ui.selection.shenlong_egg")
	_selection_status.text = I18n.t(&"ui.selection.locked")
	_selection_status.add_theme_color_override(&"font_color", ThemeFactory.GOLD)
	_selection_health.visible = false
	_selection_health_label.visible = false
	if not carrier.is_empty():
		var carrier_team := int(carrier.get("team", RtsSimulation.TEAM_NEUTRAL))
		_selection_status.text = I18n.t(&"ui.selection.your_carrier") if carrier_team == RtsSimulation.TEAM_PLAYER else I18n.t(&"ui.selection.rival_carrier")
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE if carrier_team == RtsSimulation.TEAM_PLAYER else ThemeFactory.DANGER)
		_selection_order.text = I18n.t(&"ui.selection.egg_returning")
		_selection_meta.text = I18n.t(&"ui.selection.interceptable")
		_selection_detail.text = I18n.t(&"ui.selection.egg_carrier_detail")
	elif bool(entity_state.get("claimable", false)):
		_selection_status.text = I18n.t(&"ui.selection.claimable")
		_selection_status.add_theme_color_override(&"font_color", ThemeFactory.JADE)
		_selection_order.text = I18n.t(&"ui.selection.egg_awaiting_worker")
		_selection_meta.text = I18n.t(&"ui.selection.central_objective")
		_selection_detail.text = I18n.t(&"ui.selection.egg_claim_detail")
	else:
		_selection_order.text = I18n.t(&"ui.selection.egg_guarded")
		_selection_meta.text = I18n.t(&"ui.selection.central_objective")
		_selection_detail.text = I18n.t(&"ui.selection.egg_guard_detail")


func _update_owned_selection(entity_state: Dictionary, rebuild_selection_stacks: bool) -> void:
	var kind := entity_state["kind"] as StringName
	var faction := entity_state.get("faction", selected_faction) as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var completion := float(entity_state.get("complete", 1.0))
	var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	var category_label := I18n.t(&"ui.selection.category_structure") if entity_state.get("category") == &"structure" else I18n.t(&"ui.selection.category_unit")
	var affiliation := I18n.t(&"ui.selection.neutral")
	var status_color := ThemeFactory.GOLD
	if team == RtsSimulation.TEAM_PLAYER:
		affiliation = I18n.t(&"ui.selection.your")
		status_color = ThemeFactory.JADE
	elif team > RtsSimulation.TEAM_PLAYER:
		affiliation = I18n.t(&"ui.selection.enemy")
		status_color = ThemeFactory.DANGER
	var entity_name := I18n.t(FactionCatalog.entity_text_key(kind))
	_selection_title.text = entity_name.to_upper()
	if kind == &"stronghold":
		_selection_title.text = I18n.t(&"ui.selection.stronghold_level", {"stronghold": entity_name.to_upper(), "level": int(entity_state.get("stronghold_level", RtsSimulation.STRONGHOLD_INITIAL_LEVEL))})
	_selection_status.text = I18n.t(&"ui.selection.affiliated_category", {"affiliation": affiliation, "category": category_label}) if team != RtsSimulation.TEAM_PLAYER else category_label
	_selection_status.add_theme_color_override(&"font_color", status_color)
	if completion < 1.0:
		_set_selection_progress(completion, 1.0, I18n.t(&"ui.selection.constructing", {"percent": int(completion * 100.0)}), ThemeFactory.GOLD)
	else:
		_set_selection_progress(float(entity_state["hp"]), float(entity_state["max_hp"]), I18n.t(&"ui.selection.health", {"current": int(entity_state["hp"]), "maximum": int(entity_state["max_hp"])}), status_color)
	_selection_order.text = _order_label(entity_state).to_upper()
	if entity_state.get("category") == &"structure":
		var queue := entity_state.get("queue", []) as Array
		_selection_meta.text = I18n.t(&"ui.selection.queue_meta", {"count": queue.size(), "rally": _cell_label(entity_state.get("rally_cell", Vector2i.ZERO) as Vector2i)})
		if kind == &"sentry_tower" and completion >= 1.0:
			var occupants := entity_state.get("garrisoned_unit_ids", []) as Array
			_selection_order.text = I18n.t(&"ui.selection.manned") if not occupants.is_empty() else I18n.t(&"ui.selection.awaiting_garrison")
			_selection_meta.text = I18n.t(&"ui.selection.garrison_meta", {"count": occupants.size(), "capacity": int(entity_state.get("garrison_capacity", 1))})
			_selection_detail.text = I18n.t(&"ui.selection.tower_detail")
			if team == RtsSimulation.TEAM_PLAYER and not occupants.is_empty() and rebuild_selection_stacks:
				_selection_stacks.visible = true
				for raw_id in occupants:
					var occupant := simulation.entity(int(raw_id))
					if occupant.is_empty():
						continue
					var occupant_name := I18n.t(FactionCatalog.entity_text_key(occupant["kind"] as StringName))
					var button := ThemeFactory.button(I18n.t(&"ui.selection.ungarrison", {"unit": occupant_name.to_upper()}), I18n.t(&"ui.selection.deploy_tooltip"))
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
				var farm_state := I18n.t(&"ui.selection.farm_passive")
				if farmer_id >= 0:
					farm_state = I18n.t(&"ui.selection.farm_staffed") if simulation.is_farm_staffed(int(entity_state["id"])) else I18n.t(&"ui.selection.farm_worker_en_route")
				_selection_order.text = farm_state
				_selection_meta.text = I18n.t(&"ui.selection.farmer_meta", {"count": 1 if farmer_id >= 0 else 0, "rate": "%.1f" % (float(harvest_yield) / interval)})
				_selection_detail.text = I18n.t(&"ui.selection.farm_staffed_detail", {"yield": harvest_yield, "interval": "%.0f" % interval, "next": "%.1f" % next_harvest})
			else:
				_selection_detail.text = I18n.t(&"ui.selection.farm_passive_detail", {"yield": harvest_yield, "interval": "%.0f" % interval, "next": "%.1f" % next_harvest})
		elif not queue.is_empty():
			var item := queue[0] as Dictionary
			var training_kind := item.get("kind", &"worker") as StringName
			_selection_detail.text = I18n.t(&"ui.selection.training", {"unit": I18n.t(FactionCatalog.entity_text_key(training_kind)), "seconds": "%.1f" % float(item.get("remaining", 0.0))})
		else:
			_selection_detail.text = I18n.t(FactionCatalog.entity_text_key(kind, &"role"))
	else:
		var command_queue := entity_state.get("command_queue", []) as Array
		if kind == &"worker" and bool(entity_state.get("carrying_egg", false)):
			_selection_meta.text = I18n.t(&"ui.selection.carrying_egg")
		elif kind == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
			var cargo_kind := entity_state.get("cargo_kind", &"jade") as StringName
			_selection_meta.text = I18n.t(&"ui.selection.carrying_resource", {"amount": int(entity_state["cargo_amount"]), "capacity": int(RtsSimulation.CARGO_CAPACITY), "resource": I18n.t(StringName("value.%s" % cargo_kind)).to_upper()})
		else:
			_selection_meta.text = I18n.t(&"ui.selection.damage_meta", {"damage": int(stats.get("damage", 0)), "range": "%.1f" % float(stats.get("range", 0.0)), "queued": command_queue.size()})
		_selection_detail.text = I18n.t(FactionCatalog.entity_text_key(kind, &"role"))


func _order_label(entity_state: Dictionary) -> String:
	var order := entity_state.get("order", &"idle") as StringName
	match order:
		&"move": return I18n.t(&"ui.selection.order_move")
		&"attack_move": return I18n.t(&"ui.selection.order_attack_move")
		&"attack": return I18n.t(&"ui.selection.order_attack")
		&"gather":
			var source := simulation.entity(int(entity_state.get("gather_source_id", -1)))
			var resource_kind := source.get("resource_kind", &"jade") as StringName
			return I18n.t(&"ui.selection.order_gather", {"resource": I18n.t(StringName("value.%s" % resource_kind))})
		&"farm": return I18n.t(&"ui.selection.order_farm")
		&"return": return I18n.t(&"ui.selection.order_return_cargo")
		&"claim_egg": return I18n.t(&"ui.selection.order_claim_egg")
		&"return_egg": return I18n.t(&"ui.selection.order_return_egg")
		&"repair": return I18n.t(&"ui.selection.order_repair")
		&"garrison": return I18n.t(&"ui.selection.order_enter_tower")
		&"garrisoned": return I18n.t(&"ui.selection.order_garrisoned")
		&"patrol": return I18n.t(&"ui.selection.order_patrol")
		&"construct", &"constructing": return I18n.t(&"ui.selection.order_construct")
		_: return I18n.t(&"ui.selection.order_idle")


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
		var unit_name := I18n.t(FactionCatalog.entity_text_key(kind))
		tile.text = I18n.t(&"ui.production.item", {"unit": unit_name, "seconds": "%.1f" % float(item["remaining"])})
		tile.tooltip_text = I18n.t(&"ui.production.cancel_tooltip", {"unit": unit_name})
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
			_show_cost_command(button_id, structure_kind, I18n.t(&"ui.command.build"))
	if not structure.is_empty() and float(structure.get("complete", 0.0)) >= 1.0:
		match structure.get("kind"):
			&"stronghold":
				_show_cost_command(&"worker", &"worker", I18n.t(&"ui.command.train"), true)
				_show_stronghold_upgrade_command(structure)
			&"war_camp":
				_show_cost_command(&"vanguard", &"vanguard", I18n.t(&"ui.command.train"), true)
				_show_cost_command(&"mystic", &"mystic", I18n.t(&"ui.command.train"), true)
			&"hunters_lodge":
				if simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"hunter"):
					_show_cost_command(&"hunter", &"hunter", I18n.t(&"ui.command.train"), true)
			&"yaoguai_den": _show_cost_command(&"jadeclaw", &"jadeclaw", I18n.t(&"ui.command.call"), true)
	_set_simple_command(&"move", has_units, I18n.t(&"ui.command.simple_move"))
	_set_simple_command(&"attack_move", has_military, I18n.t(&"ui.command.simple_attack_move"))
	_set_simple_command(&"patrol", has_military, I18n.t(&"ui.command.simple_patrol"))
	_set_simple_command(&"repair", has_worker, I18n.t(&"ui.command.simple_repair"))
	_set_simple_command(&"stop", has_units, I18n.t(&"ui.command.simple_stop"))
	_set_simple_command(&"rally", not structure.is_empty(), I18n.t(&"ui.command.simple_rally"))
	if not structure.is_empty() and simulation.can_demolish_structure(
		RtsSimulation.TEAM_PLAYER,
		selected_structure_id,
	):
		_show_demolish_command(selected_structure_id)
	var production_queue := structure.get("queue", []) as Array if not structure.is_empty() else []
	var cancel_button := _command_buttons[&"cancel_queue"] as HudCommandButton
	cancel_button.set_meta(COMMAND_VISIBLE_META, not production_queue.is_empty())
	cancel_button.disabled = production_queue.is_empty()
	if not production_queue.is_empty():
		cancel_button.set_command_title(I18n.t(&"ui.command.cancel_last"))
		cancel_button.set_cost_markup(I18n.t(&"ui.command.cancel_refund"))
		cancel_button.tooltip_text = I18n.t(&"ui.command.refund_cancel")
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
	var tooltip := I18n.t(&"ui.command.tooltip", {
		"verb": verb,
		"entity": I18n.t(FactionCatalog.entity_text_key(kind)),
		"cost": _long_cost(stats),
	})
	if free_recovery_worker:
		tooltip += "\n" + I18n.t(&"ui.command.recovery_worker")
	if not button.hotkey_text.is_empty():
		tooltip += "\n" + I18n.t(&"ui.command.hotkey", {"hotkey": button.hotkey_text})
	var unavailable := _unavailable_reason(stats, check_population)
	if not unavailable.is_empty():
		tooltip += "\n" + I18n.t(&"ui.command.unavailable", {"reason": unavailable})
	button.tooltip_text = tooltip


func _show_stronghold_upgrade_command(stronghold: Dictionary) -> void:
	var button := _command_buttons[&"stronghold_upgrade"] as HudCommandButton
	var stronghold_id := int(stronghold.get("id", -1))
	var current_level := int(stronghold.get("stronghold_level", RtsSimulation.STRONGHOLD_INITIAL_LEVEL))
	var cost := simulation.stronghold_upgrade_cost(stronghold_id)
	button.set_meta(COMMAND_VISIBLE_META, true)
	if cost.is_empty():
		button.set_command_title(I18n.t(&"ui.command.max_level"))
		button.set_cost_markup("")
		button.disabled = true
		button.tooltip_text = I18n.t(&"ui.command.stronghold_max_tooltip", {
			"level": current_level,
			"population": int(simulation.players[RtsSimulation.TEAM_PLAYER]["population_cap"]),
		})
		return
	var next_level := current_level + 1
	button.set_command_title(I18n.t(&"ui.command.upgrade", {"level": next_level}))
	button.set_cost_markup(_cost_markup(cost))
	button.disabled = not simulation.can_upgrade_stronghold(
		RtsSimulation.TEAM_PLAYER,
		stronghold_id,
	)
	var next_population_cap := (
		int(simulation.players[RtsSimulation.TEAM_PLAYER]["population_cap"])
		+ RtsSimulation.STRONGHOLD_POPULATION_PER_UPGRADE
	)
	var tooltip := I18n.t(&"ui.command.upgrade_tooltip", {
		"level": next_level,
		"cost": _long_cost(cost),
		"population": next_population_cap,
	})
	var unavailable := _unavailable_reason(cost, false)
	if not unavailable.is_empty():
		tooltip += "\n" + I18n.t(&"ui.command.unavailable", {"reason": unavailable})
	button.tooltip_text = tooltip


func _show_demolish_command(structure_id: int) -> void:
	var button := _command_buttons[&"demolish"] as HudCommandButton
	var refund := simulation.demolition_refund(structure_id)
	button.set_meta(COMMAND_VISIBLE_META, true)
	button.set_command_title(I18n.t(&"ui.command.demolish"))
	button.set_cost_markup(_cost_markup(refund))
	button.disabled = false
	button.tooltip_text = I18n.t(&"ui.command.demolish_tooltip", {"refund": _long_cost(refund)})


func _set_simple_command(button_id: StringName, visible: bool, tooltip: String) -> void:
	var button := _command_buttons[button_id] as HudCommandButton
	button.set_meta(COMMAND_VISIBLE_META, visible)
	button.disabled = false
	button.set_cost_markup("")
	button.tooltip_text = tooltip


func _cost_markup(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", &"ui.command.cost_jade_short", "6fd2aa"],
		["lumber_cost", &"ui.command.cost_lumber_short", "d0a25c"],
		["essence_cost", &"ui.command.cost_essence_short", "a974e6"],
		["food_cost", &"ui.command.cost_food_short", "e8c56a"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append("[color=#%s]%s[/color]" % [definition[2], I18n.t(definition[1] as StringName, {"amount": amount})])
	return "  ".join(parts) if not parts.is_empty() else I18n.t(&"ui.command.free")


func _unavailable_reason(stats: Dictionary, check_population: bool) -> String:
	var player := simulation.players[RtsSimulation.TEAM_PLAYER]
	var missing: Array[String] = []
	for definition in [
		["jade_cost", "jade", &"value.jade"],
		["lumber_cost", "lumber", &"value.lumber"],
		["essence_cost", "essence", &"value.essence"],
		["food_cost", "food", &"value.food"],
	]:
		var shortfall := int(stats.get(definition[0], 0)) - int(player.get(definition[1], 0))
		if shortfall > 0:
			missing.append(I18n.t(&"ui.command.missing_resource", {"amount": shortfall, "resource": I18n.t(definition[2] as StringName)}))
	if check_population:
		var population_cost := int(stats.get("population", 0))
		var room := int(player["population_cap"]) - int(player["population"])
		if population_cost > room:
			missing.append(I18n.t(&"ui.command.missing_population", {"amount": population_cost - room}))
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
		var armed_suffix := I18n.t(ARMED_TOOLTIP_SUFFIX_KEY)
		button.set_pressed_no_signal(is_active)
		button.tooltip_text = button.tooltip_text.trim_suffix(armed_suffix)
		if is_active:
			var armed_style := ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE_ACTIVE, ThemeFactory.JADE, 2)
			button.add_theme_stylebox_override(&"normal", armed_style)
			button.add_theme_stylebox_override(&"pressed", armed_style)
			button.tooltip_text += armed_suffix
		else:
			button.add_theme_stylebox_override(&"normal", ThemeFactory.command_button_style(ThemeFactory.BUTTON_SURFACE, ThemeFactory.BUTTON_BORDER))
			button.add_theme_stylebox_override(&"pressed", ThemeFactory.command_button_style(ThemeFactory.GOLD, Color("ffe8a0"), 2))


func _short_cost(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", &"ui.command.cost_jade_short"],
		["lumber_cost", &"ui.command.cost_lumber_short"],
		["essence_cost", &"ui.command.cost_essence_short"],
		["food_cost", &"ui.command.cost_food_short"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append(I18n.t(definition[1] as StringName, {"amount": amount}))
	return " · ".join(parts) if not parts.is_empty() else I18n.t(&"ui.command.free")


func _long_cost(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for definition in [
		["jade_cost", &"ui.command.cost_jade_long"],
		["lumber_cost", &"ui.command.cost_lumber_long"],
		["essence_cost", &"ui.command.cost_essence_long"],
		["food_cost", &"ui.command.cost_food_long"],
	]:
		var amount := int(stats.get(definition[0], 0))
		if amount > 0:
			parts.append(I18n.t(definition[1] as StringName, {"amount": amount}))
	return " · ".join(parts) if not parts.is_empty() else I18n.t(&"ui.command.free")


func _command_build(structure_kind: StringName) -> void:
	battlefield.begin_structure_placement(structure_kind)
	_update_armed_command_styles()


func _command_stop() -> void:
	var units := battlefield.selected_commandable_units()
	if units.is_empty():
		_show_feedback(I18n.t(&"feedback.stop_needs_units"), true)
		return
	if simulation.command_stop(RtsSimulation.TEAM_PLAYER, units):
		_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
	audio_director.play_ui(&"ui_cancel")
	_show_feedback(I18n.t(&"feedback.units_halted"), false)


func _first_selected_production_kind() -> StringName:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		return &""
	var structure := simulation.entity(structure_id)
	var production_list := STRUCTURE_PRODUCTION_LISTS.get(structure.get("kind", &""), []) as Array
	if production_list.is_empty():
		return &""
	var first_kind := production_list[0] as StringName
	return first_kind if simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, first_kind) else &""


func _command_train(kind: StringName) -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback(I18n.t(&"feedback.training_needs_structure"), true)
		return
	if simulation.command_train(RtsSimulation.TEAM_PLAYER, structure_id, kind):
		_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
		if tutorial_director != null:
			tutorial_director.notify_event(&"production_ordered")
		audio_director.play_ui(&"ui_confirm")
		_show_feedback(I18n.t(&"feedback.training_queued", {"unit": I18n.t(FactionCatalog.entity_text_key(kind))}), false)
	else:
		_show_feedback(I18n.t(&"feedback.training_failed"), true)


func _command_upgrade_stronghold() -> void:
	var stronghold_id := battlefield.primary_selected_structure()
	if stronghold_id < 0:
		_show_feedback(I18n.t(&"feedback.upgrade_needs_stronghold"), true)
		return
	if simulation.command_upgrade_stronghold(RtsSimulation.TEAM_PLAYER, stronghold_id):
		_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
		var stronghold := simulation.entity(stronghold_id)
		audio_director.play_ui(&"ui_confirm")
		_show_feedback(
			I18n.t(&"feedback.upgrade_success", {
				"level": int(stronghold.get("stronghold_level", RtsSimulation.STRONGHOLD_INITIAL_LEVEL)),
				"population": int(simulation.players[RtsSimulation.TEAM_PLAYER]["population_cap"]),
			}),
			false,
		)
	else:
		var cost := simulation.stronghold_upgrade_cost(stronghold_id)
		if cost.is_empty():
			_show_feedback(I18n.t(&"feedback.upgrade_maximum"), true)
		else:
			_show_feedback(I18n.t(&"feedback.upgrade_failed"), true)
	_update_hud()


func _command_demolish() -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback(I18n.t(&"feedback.demolish_needs_building"), true)
		return
	var structure := simulation.entity(structure_id)
	var building_name := I18n.t(FactionCatalog.entity_text_key(structure.get("kind", &"war_camp") as StringName))
	var refund := simulation.command_demolish(RtsSimulation.TEAM_PLAYER, structure_id)
	if refund.is_empty():
		_show_feedback(I18n.t(&"feedback.demolish_failed"), true)
		_update_hud()
		return
	_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
	battlefield.select_entities([])
	audio_director.play_ui(&"ui_cancel")
	_show_feedback(
		I18n.t(&"feedback.demolished", {"building": building_name, "refund": _long_cost(refund)}),
		false,
	)
	_update_hud()


func _command_cancel_training() -> void:
	var structure_id := battlefield.primary_selected_structure()
	if structure_id < 0:
		_show_feedback(I18n.t(&"feedback.training_queue_needs_structure"), true)
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
		_show_feedback(I18n.t(&"feedback.training_queue_missing"), true)
		_update_hud()
		return
	_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)
	audio_director.play_ui(&"ui_cancel")
	var costs := cancelled.get("costs", {}) as Dictionary
	var refund_parts: Array[String] = []
	for definition in [
		["jade", &"ui.command.cost_jade_short"],
		["lumber", &"ui.command.cost_lumber_short"],
		["essence", &"ui.command.cost_essence_short"],
		["food", &"ui.command.cost_food_short"],
	]:
		var amount := int(costs.get(definition[0], 0))
		if amount > 0:
			refund_parts.append(I18n.t(definition[1] as StringName, {"amount": amount}))
	var refund_text := " · ".join(refund_parts) if not refund_parts.is_empty() else I18n.t(&"ui.command.free")
	_show_feedback(
		I18n.t(&"feedback.cancelled_training", {
			"unit": I18n.t(FactionCatalog.entity_text_key(cancelled.get("kind", &"worker") as StringName)),
			"refund": refund_text,
		}),
		false,
	)
	_update_hud()


func _on_battle_notice(key: StringName, placeholder_values: Dictionary, team: int) -> void:
	var values := placeholder_values.duplicate()
	if key == &"notice.wildlife_hunted":
		var wildlife_kind := values.get("kind", &"deer") as StringName
		values.erase("kind")
		values["wildlife"] = I18n.t(FactionCatalog.entity_text_key(wildlife_kind))
	if team == RtsSimulation.TEAM_PLAYER or key == &"notice.ai_invasion":
		_show_feedback(I18n.t(key, values), false)
		return
	match key:
		&"notice.den_captured": _show_feedback(I18n.t(&"notice.rival_den_captured"), false)
		&"notice.den_cleared": _show_feedback(I18n.t(&"notice.rival_den_cleared"), false)
		&"notice.wildlife_hunted": _show_feedback(I18n.t(&"notice.rival_wildlife_hunted"), false)
		&"notice.jadeclaw_hunted": _show_feedback(I18n.t(&"notice.rival_jadeclaw_hunted"), false)
		&"notice.egg_claimed", &"notice.egg_hatched", &"notice.shenlong_fallen":
			_show_feedback(I18n.t(&"notice.rival_shenlong"), false)


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
	_pause_button.tooltip_text = I18n.t(&"ui.pause.resume_tooltip") if paused else I18n.t(&"ui.hud.pause")
	if battlefield != null:
		battlefield.set_process(not paused)
	if paused:
		if tutorial_director != null:
			tutorial_director.notify_event(&"pause_opened")
		_show_pause_menu()
	else:
		_pause_overlay.visible = false
	_on_input_method_changed(input_router.method if input_router != null else InputRouter.KEYBOARD_MOUSE)
	audio_director.set_music_state(&"paused" if paused else STATE_MATCH)
	audio_director.play_ui(&"ui_cancel" if paused else &"ui_confirm")
	_show_feedback(I18n.t(&"feedback.pause_on") if paused else I18n.t(&"feedback.pause_off"), false)


func _show_pause_menu() -> void:
	if not paused or _pause_overlay == null:
		return
	_pause_overlay.visible = true
	_pause_menu.visible = true
	_settings_menu.visible = false
	_confirm_menu.visible = false
	_confirm_action = &""
	_resume_button.call_deferred("grab_focus")


func _show_settings_menu() -> void:
	if not paused or _pause_overlay == null:
		return
	_pause_overlay.visible = true
	_pause_menu.visible = false
	_settings_menu.visible = true
	_confirm_menu.visible = false
	_update_audio_controls()
	_update_effect_controls()
	_settings_audio_button.call_deferred("grab_focus")


func _show_abandon_confirmation(action: StringName) -> void:
	if not paused or action not in [&"restart", &"title"]:
		return
	_confirm_action = action
	_pause_menu.visible = false
	_settings_menu.visible = false
	_confirm_menu.visible = true
	_confirm_title.text = I18n.t(
		&"ui.pause.confirm_restart_title" if action == &"restart" else &"ui.pause.confirm_title_title"
	)
	_confirm_body.text = I18n.t(
		&"ui.pause.confirm_restart_body" if action == &"restart" else &"ui.pause.confirm_title_body"
	)
	_confirm_accept_button.call_deferred("grab_focus")


func _cancel_abandon_confirmation() -> void:
	if _confirm_menu == null:
		return
	audio_director.play_ui(&"ui_cancel")
	_show_pause_menu()


func _accept_abandon_confirmation() -> void:
	var action := _confirm_action
	_confirm_action = &""
	if action == &"restart":
		_start_match(selected_faction)
	elif action == &"title":
		_show_title()


func _resign_match() -> void:
	if simulation == null:
		return
	if simulation.command_resign(RtsSimulation.TEAM_PLAYER):
		_apply_tweak_boundary(TWEAK_CATALOG.NEXT_ACTION)


func _toggle_fog_of_war() -> void:
	if battlefield == null:
		return
	tweak_service.set_requested(&"environment.fog.enabled", not battlefield.fog_enabled)
	audio_director.play_ui(&"ui_confirm")
	_show_feedback(I18n.t(&"feedback.fog_enabled") if battlefield.fog_enabled else I18n.t(&"feedback.fog_disabled"), false)


func _toggle_audio() -> void:
	var is_muted := not bool(tweak_service.requested_value(&"audio.master.muted"))
	tweak_service.set_requested(&"audio.master.muted", is_muted)
	_update_audio_controls()
	if not is_muted:
		audio_director.play_ui(&"ui_confirm")


func _cycle_effect_intensity() -> void:
	effect_intensity = &"low" if effect_intensity == &"full" else &"full"
	_apply_effect_settings()


func _toggle_reduced_motion() -> void:
	tweak_service.set_requested(&"ui.reduced_motion", not reduced_motion)


func _cycle_camera_impulse() -> void:
	match camera_impulse:
		&"off":
			camera_impulse = &"major"
		&"major":
			camera_impulse = &"full"
		_:
			camera_impulse = &"off"
	_apply_effect_settings()


func _cycle_damage_numbers() -> void:
	match damage_numbers:
		&"off":
			damage_numbers = &"contextual"
		&"contextual":
			damage_numbers = &"all"
		_:
			damage_numbers = &"off"
	_apply_effect_settings()


func _apply_effect_settings() -> void:
	if battlefield != null:
		battlefield.configure_effects(effect_intensity, reduced_motion, damage_numbers, camera_impulse)
	for raw_button in _command_buttons.values():
		(raw_button as HudCommandButton).set_reduced_motion(reduced_motion)
	_update_effect_controls()


func _update_effect_controls() -> void:
	if _settings_effect_intensity_button != null:
		_settings_effect_intensity_button.text = I18n.t(&"ui.pause.effects", {"value": _setting_value(effect_intensity)})
	if _settings_reduced_motion_button != null:
		_settings_reduced_motion_button.text = I18n.t(&"ui.pause.reduced_motion", {"value": I18n.t(&"value.on") if reduced_motion else I18n.t(&"value.off")})
	if _settings_camera_impulse_button != null:
		_settings_camera_impulse_button.text = I18n.t(&"ui.pause.camera_impulse", {"value": _setting_value(camera_impulse)})
	if _settings_damage_numbers_button != null:
		_settings_damage_numbers_button.text = I18n.t(&"ui.pause.damage_values", {"value": _setting_value(damage_numbers)})


func _setting_value(value: StringName) -> String:
	return I18n.t(StringName("value.%s" % value))


func _update_audio_controls() -> void:
	if _audio_button != null:
		ThemeFactory.set_icon_button_texture(
			_audio_button,
			HUD_UTILITY_ICON_TEXTURES[&"audio_muted" if audio_director.muted else &"audio_on"],
		)
	if _settings_audio_button != null:
		_settings_audio_button.text = I18n.t(&"ui.pause.audio_off") if audio_director.muted else I18n.t(&"ui.pause.audio_on")
		_settings_audio_button.tooltip_text = (
			I18n.t(&"ui.pause.audio_tooltip_disabled") if audio_director.muted
			else I18n.t(&"ui.pause.audio_tooltip_enabled")
		)


func _on_match_ended(result: StringName) -> void:
	if _match_score_recorded or simulation == null:
		return
	_match_score_recorded = true
	if tutorial_director != null:
		tutorial_director.end_run()
	var final_score := simulation.team_score(RtsSimulation.TEAM_PLAYER)
	leaderboard_store.record_match(
		final_score,
		result,
		selected_faction,
		int(simulation.elapsed_time),
		tweak_service.run_is_rank_eligible(),
		tweak_service.run_configuration_marker(),
	)
	if tweak_service.run_is_rank_eligible():
		leaderboard_bridge.submit_current()
	paused = true
	state = STATE_RESULT
	_on_input_method_changed(input_router.method if input_router != null else InputRouter.KEYBOARD_MOUSE)
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
	var title := ThemeFactory.label(I18n.t(&"ui.result.victory") if result == &"victory" else I18n.t(&"ui.result.defeat"), 30, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := ThemeFactory.label(
		I18n.t(&"ui.result.victory_detail") if result == &"victory" else I18n.t(&"ui.result.defeat_detail"),
		17,
		ThemeFactory.PARCHMENT,
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var elapsed_seconds := int(simulation.elapsed_time)
	var elapsed_minutes := floori(simulation.elapsed_time / 60.0)
	var time_label := ThemeFactory.label(I18n.t(&"ui.result.skirmish_time", {"time": "%02d:%02d" % [elapsed_minutes, elapsed_seconds % 60]}), 15, ThemeFactory.MUTED)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(time_label)
	var result_score := ThemeFactory.label(I18n.t(&"ui.hud.score", {"score": final_score}), 23, ThemeFactory.GOLD)
	result_score.name = "ResultScore"
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_score)
	var rematch := ThemeFactory.button(I18n.t(&"ui.result.rematch"))
	_connect_button(rematch, func() -> void: _start_match(selected_faction))
	column.add_child(rematch)
	_result_leaderboard_button = ThemeFactory.button(I18n.t(&"ui.leaderboard"), I18n.t(&"ui.leaderboard_tooltip"))
	_result_leaderboard_button.name = "ResultLeaderboardButton"
	_connect_button(_result_leaderboard_button, func() -> void: _open_leaderboard(_result_leaderboard_button))
	column.add_child(_result_leaderboard_button)
	var choose := ThemeFactory.button(I18n.t(&"ui.result.choose_faction"))
	_connect_button(choose, _show_faction_select)
	column.add_child(choose)
	var title_button := ThemeFactory.button(I18n.t(&"ui.result.return_title"))
	_connect_button(title_button, _show_title, &"ui_cancel")
	column.add_child(title_button)
	if _tweak_layer != null:
		var bottom_inset := 256.0
		_tweak_button.offset_top = -bottom_inset - 46.0
		_tweak_button.offset_bottom = -bottom_inset
		_tweak_layer.move_to_front()
	if _tweak_panel != null:
		_tweak_panel.move_to_front()
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
