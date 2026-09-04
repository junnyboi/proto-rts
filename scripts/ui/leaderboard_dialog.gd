class_name LeaderboardDialog
extends Control

signal global_refresh_requested
signal callsign_saved
signal closed

const MODE_LOCAL := &"local"
const MODE_GLOBAL := &"global"
const DISPLAY_LIMIT := 10

var mode: StringName = MODE_LOCAL
var _store: LeaderboardStore
var _return_focus: Control
var _global_state: StringName = &"native_local"
var _global_entries: Array[Dictionary] = []
var _personal_rank: Dictionary = {}

var callsign_edit: LineEdit
var local_tab: Button
var global_tab: Button
var refresh_button: Button
var close_button: Button
var status_label: Label
var column_header: Label
var row_labels: Array[Label] = []


func _ready() -> void:
	name = "LeaderboardDialog"
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	visible = false


func configure(store: LeaderboardStore) -> void:
	_store = store
	if callsign_edit != null:
		callsign_edit.text = _display_callsign(_store.callsign())
		_refresh_rows()


func open(return_focus: Control = null) -> void:
	_return_focus = return_focus
	mode = MODE_LOCAL
	# GUI hit-testing follows sibling order, so stay above overlays added after us.
	move_to_front()
	visible = true
	if _store != null:
		callsign_edit.text = _display_callsign(_store.callsign())
	_update_tab_styles()
	_refresh_rows()
	local_tab.call_deferred("grab_focus")


func close_dialog() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.call_deferred("grab_focus")


func set_global_state(next_state: StringName, next_entries: Array, next_personal_rank: Dictionary) -> void:
	_global_state = next_state
	_global_entries.clear()
	for raw_entry in next_entries:
		if raw_entry is Dictionary:
			_global_entries.append((raw_entry as Dictionary).duplicate(true))
	_personal_rank = next_personal_rank.duplicate(true)
	if mode == MODE_GLOBAL:
		_refresh_rows()


func set_callsign_sync_state(sync_state: StringName) -> void:
	match sync_state:
		&"syncing":
			status_label.text = I18n.t(&"leaderboard.status_name_syncing")
		&"online":
			status_label.text = I18n.t(&"leaderboard.status_name_synced")
		&"offline":
			status_label.text = I18n.t(&"leaderboard.status_name_offline")
		&"error":
			status_label.text = I18n.t(&"leaderboard.status_name_rejected")
		_:
			status_label.text = I18n.t(&"leaderboard.status_name_local")


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.color = Color(0.0, 0.0, 0.0, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_backdrop_gui_input)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "LeaderboardPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460.0
	panel.offset_top = -330.0
	panel.offset_right = 460.0
	panel.offset_bottom = 330.0
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color("071718fc"), ThemeFactory.GOLD, 2, 12))
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)

	var title := ThemeFactory.label(I18n.t(&"leaderboard.title"), 30, ThemeFactory.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := ThemeFactory.label(I18n.t(&"leaderboard.subtitle"), 14, ThemeFactory.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override(&"separation", 10)
	column.add_child(identity_row)
	var identity_label := ThemeFactory.label(I18n.t(&"leaderboard.name"), 14, ThemeFactory.JADE)
	identity_label.custom_minimum_size.x = 84.0
	identity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity_row.add_child(identity_label)
	callsign_edit = LineEdit.new()
	callsign_edit.name = "CallsignEdit"
	callsign_edit.placeholder_text = I18n.t(&"leaderboard.name_placeholder")
	callsign_edit.max_length = LeaderboardStore.MAX_CALLSIGN_LENGTH
	callsign_edit.custom_minimum_size = Vector2(260.0, 38.0)
	callsign_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	callsign_edit.text_submitted.connect(func(_text: String) -> void: _save_callsign())
	identity_row.add_child(callsign_edit)
	var save_button := ThemeFactory.button(I18n.t(&"leaderboard.save"))
	save_button.name = "SaveCallsignButton"
	save_button.custom_minimum_size.x = 110.0
	save_button.pressed.connect(_save_callsign)
	identity_row.add_child(save_button)

	status_label = ThemeFactory.label("", 13, ThemeFactory.MUTED)
	status_label.name = "LeaderboardStatus"
	status_label.custom_minimum_size.y = 20.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status_label)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override(&"separation", 10)
	column.add_child(tab_row)
	var tab_group := ButtonGroup.new()
	local_tab = ThemeFactory.button(I18n.t(&"leaderboard.local"))
	local_tab.name = "LocalTab"
	local_tab.custom_minimum_size = Vector2(180.0, 40.0)
	local_tab.toggle_mode = true
	local_tab.button_group = tab_group
	local_tab.pressed.connect(func() -> void: _select_mode(MODE_LOCAL))
	tab_row.add_child(local_tab)
	global_tab = ThemeFactory.button(I18n.t(&"leaderboard.global"))
	global_tab.name = "GlobalTab"
	global_tab.custom_minimum_size = Vector2(180.0, 40.0)
	global_tab.toggle_mode = true
	global_tab.button_group = tab_group
	global_tab.pressed.connect(func() -> void: _select_mode(MODE_GLOBAL))
	tab_row.add_child(global_tab)

	column_header = ThemeFactory.label("", 13, ThemeFactory.JADE)
	column_header.name = "ColumnHeader"
	column_header.custom_minimum_size.y = 20.0
	column.add_child(column_header)

	var rows := VBoxContainer.new()
	rows.name = "LeaderboardRows"
	rows.add_theme_constant_override(&"separation", 2)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(rows)
	for index in range(DISPLAY_LIMIT):
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size.y = 31.0
		row_panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_inset_style(ThemeFactory.BUTTON_BORDER if index % 2 == 0 else Color("3f5f59")))
		rows.add_child(row_panel)
		var row_label := ThemeFactory.label("", 14, ThemeFactory.PARCHMENT)
		row_label.name = "RankRow%d" % (index + 1)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row_panel.add_child(row_label)
		row_labels.append(row_label)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override(&"separation", 10)
	column.add_child(action_row)
	refresh_button = ThemeFactory.button(I18n.t(&"leaderboard.refresh"))
	refresh_button.name = "RefreshLeaderboardButton"
	refresh_button.custom_minimum_size.x = 150.0
	refresh_button.pressed.connect(_refresh_pressed)
	action_row.add_child(refresh_button)
	close_button = ThemeFactory.button(I18n.t(&"leaderboard.close"))
	close_button.name = "CloseLeaderboardButton"
	close_button.custom_minimum_size.x = 150.0
	close_button.pressed.connect(close_dialog)
	action_row.add_child(close_button)


func _select_mode(next_mode: StringName) -> void:
	mode = next_mode
	_update_tab_styles()
	_refresh_rows()
	if mode == MODE_GLOBAL:
		global_refresh_requested.emit()


func _update_tab_styles() -> void:
	local_tab.button_pressed = mode == MODE_LOCAL
	global_tab.button_pressed = mode == MODE_GLOBAL


func _refresh_pressed() -> void:
	if mode == MODE_GLOBAL:
		global_refresh_requested.emit()
	else:
		_refresh_rows()


func _save_callsign() -> void:
	if _store == null:
		return
	var stored_callsign := _store.callsign()
	var is_unchanged_placeholder := (
		stored_callsign.begins_with(LeaderboardStore.PLACEHOLDER_NAME_PREFIX)
		and callsign_edit.text == _display_callsign(stored_callsign)
	)
	var validation_error := "" if is_unchanged_placeholder else _store.set_callsign(callsign_edit.text)
	if not validation_error.is_empty():
		var values := {}
		if validation_error == "leaderboard.validation_too_short":
			values["minimum"] = LeaderboardStore.MIN_CALLSIGN_LENGTH
		elif validation_error == "leaderboard.validation_too_long":
			values["maximum"] = LeaderboardStore.MAX_CALLSIGN_LENGTH
		status_label.text = I18n.t(StringName(validation_error), values).to_upper()
		callsign_edit.grab_focus()
		return
	callsign_edit.text = _display_callsign(_store.callsign())
	status_label.text = I18n.t(&"leaderboard.status_name_local")
	_refresh_rows(false)
	callsign_saved.emit()


func _refresh_rows(update_status: bool = true) -> void:
	if _store == null or row_labels.is_empty():
		return
	var display_rows: Array[Dictionary] = []
	var global_format := false
	if mode == MODE_LOCAL:
		display_rows = _store.local_leaderboard(DISPLAY_LIMIT)
		column_header.text = I18n.t(&"leaderboard.column_local")
		if update_status:
			status_label.text = I18n.t(&"leaderboard.status_local_history", {"shown": display_rows.size(), "maximum": LeaderboardStore.MAX_HISTORY})
	else:
		column_header.text = I18n.t(&"leaderboard.column_global")
		if _global_state == &"online":
			display_rows = _global_entries.duplicate(true)
			global_format = true
			if _personal_rank.is_empty():
				status_label.text = I18n.t(&"leaderboard.status_global_online")
			else:
				status_label.text = I18n.t(&"leaderboard.status_global_rank", {"rank": int(_personal_rank["rank"]), "score": _format_number(int(_personal_rank["score"]))})
		else:
			display_rows = _store.local_leaderboard(DISPLAY_LIMIT)
			match _global_state:
				&"syncing":
					status_label.text = I18n.t(&"leaderboard.status_contacting")
				&"error":
					status_label.text = I18n.t(&"leaderboard.status_global_invalid")
				&"offline":
					status_label.text = I18n.t(&"leaderboard.status_global_offline")
				_:
					status_label.text = I18n.t(&"leaderboard.status_web_required")
	for index in range(row_labels.size()):
		var label := row_labels[index]
		if index >= display_rows.size():
			label.text = "—" if index == 0 else ""
			label.add_theme_color_override(&"font_color", ThemeFactory.MUTED)
			continue
		var row := display_rows[index]
		label.text = _format_row(row, global_format)
		label.add_theme_color_override(&"font_color", ThemeFactory.GOLD if int(row.get("rank", index + 1)) == 1 else ThemeFactory.PARCHMENT)


func _format_row(row: Dictionary, global_format: bool) -> String:
	var rank := int(row.get("rank", 0))
	var row_callsign := _display_callsign(String(row.get("callsign", I18n.t(&"leaderboard.unknown")))).to_upper().left(20)
	var score := _format_number(int(row.get("score", 0)))
	var record := I18n.t(&"leaderboard.wins", {"count": int(row.get("victories", 0))}) if global_format else I18n.t(&"leaderboard.result_victory") if row.get("result", "defeat") == "victory" else I18n.t(&"leaderboard.result_defeat")
	if not global_format and not bool(row.get("rank_eligible", true)):
		record = I18n.t(&"leaderboard.result_unranked", {"result": record})
	var faction := _faction_name(String(row.get("faction", "unknown"))).to_upper()
	var elapsed := "—" if global_format else _format_duration(int(row.get("elapsed_seconds", 0)))
	return "#%-5d %-28s %10s   %-11s  %-30s %7s" % [rank, row_callsign, score, record, faction, elapsed]


func _faction_name(faction: String) -> String:
	var faction_id := StringName(faction)
	if faction_id not in FactionCatalog.ORDER:
		return I18n.t(&"value.unknown")
	return I18n.t(FactionCatalog.faction_text_key(faction_id, &"name"))


func _display_callsign(value: String) -> String:
	if value == "UNKNOWN" or value.is_empty():
		return I18n.t(&"leaderboard.unknown")
	if value.begins_with(LeaderboardStore.PLACEHOLDER_NAME_PREFIX):
		return I18n.t(&"leaderboard.forgotten_one", {
			"suffix": value.trim_prefix(LeaderboardStore.PLACEHOLDER_NAME_PREFIX),
		})
	return value


func _format_duration(total_seconds: int) -> String:
	var safe_seconds := maxi(0, total_seconds)
	return "%02d:%02d" % [safe_seconds / 60, safe_seconds % 60]


func _format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return formatted


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_dialog()
		accept_event()
