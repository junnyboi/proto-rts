class_name TweakPanel
extends Control

signal value_requested(id: StringName, value: Variant)
signal reset_requested(id: StringName)
signal reset_all_requested
signal close_requested

const CATALOG := preload("res://config/tweaks/catalog.gd")

var _service: TweakService
var _category: StringName = &"ALL"
var _search_text := ""
var _rows: Dictionary = {}
var _editors: Dictionary = {}
var _value_labels: Dictionary = {}
var _status_label: Label
var _rows_container: VBoxContainer
var _search: LineEdit
var _close_button: Button


func _ready() -> void:
	name = "TweakPanel"
	z_index = 300
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	visible = false


func configure(service: TweakService) -> void:
	_service = service
	refresh()


func open() -> void:
	move_to_front()
	visible = true
	refresh()
	_search.call_deferred("grab_focus")


func close_panel() -> void:
	if not visible:
		return
	visible = false
	close_requested.emit()


func refresh() -> void:
	if _service == null or _rows.is_empty():
		return
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		var editor := _editors.get(id) as Control
		var requested: Variant = _service.requested_value(id)
		if editor is BaseButton:
			(editor as BaseButton).set_pressed_no_signal(bool(requested))
			(editor as BaseButton).text = I18n.t(&"value.on") if bool(requested) else I18n.t(&"value.off")
		elif editor is SpinBox:
			(editor as SpinBox).set_value_no_signal(float(requested))
		var active: Variant = _service.active_value(id)
		var value_label := _value_labels[id] as Label
		if _same_value(requested, active):
			value_label.text = I18n.t(&"tweak.row.active", {"value": _format_value(descriptor, active)})
			value_label.add_theme_color_override(&"font_color", ThemeFactory.JADE)
		else:
			value_label.text = I18n.t(&"tweak.row.pending", {
				"requested": _format_value(descriptor, requested),
				"active": _format_value(descriptor, active),
				"boundary": I18n.t(_apply_mode_key(descriptor["apply_mode"] as StringName)),
			})
			value_label.add_theme_color_override(&"font_color", ThemeFactory.GOLD)
	_update_filter()
	_update_status()


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_on_backdrop_input)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "TweakPanelFrame"
	panel.anchor_left = 0.05
	panel.anchor_top = 0.04
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override(&"panel", ThemeFactory.panel_style(Color("071718fc"), ThemeFactory.GOLD, 2, 10))
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)

	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading_copy)
	var title := ThemeFactory.label(I18n.t(&"tweak.title"), 28, ThemeFactory.GOLD)
	heading_copy.add_child(title)
	var subtitle := ThemeFactory.label(I18n.t(&"tweak.subtitle"), 13, ThemeFactory.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_copy.add_child(subtitle)
	_close_button = ThemeFactory.button(I18n.t(&"tweak.close"), I18n.t(&"tweak.close_tooltip"))
	_close_button.name = "CloseTweakPanelButton"
	_close_button.accessibility_name = I18n.t(&"tweak.close_accessible")
	_close_button.custom_minimum_size = Vector2(112.0, 42.0)
	_close_button.pressed.connect(close_panel)
	heading_row.add_child(_close_button)

	_search = LineEdit.new()
	_search.name = "TweakSearch"
	_search.placeholder_text = I18n.t(&"tweak.search_placeholder")
	_search.accessibility_name = I18n.t(&"tweak.search_accessible")
	_search.custom_minimum_size.y = 40.0
	_search.text_changed.connect(_on_search_changed)
	column.add_child(_search)

	var categories := HFlowContainer.new()
	categories.name = "TweakCategories"
	categories.add_theme_constant_override(&"h_separation", 6)
	categories.add_theme_constant_override(&"v_separation", 6)
	column.add_child(categories)
	var category_group := ButtonGroup.new()
	for category: StringName in [&"ALL"] + CATALOG.CATEGORIES:
		var button := ThemeFactory.button(I18n.t(_category_key(category)))
		button.name = "TweakCategory%s" % String(category).capitalize()
		button.custom_minimum_size = Vector2(132.0, 36.0)
		button.toggle_mode = true
		button.button_group = category_group
		button.set_pressed_no_signal(category == &"ALL")
		button.pressed.connect(_select_category.bind(category))
		categories.add_child(button)

	var separator := HSeparator.new()
	column.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.name = "TweakScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows_container = VBoxContainer.new()
	_rows_container.name = "TweakRows"
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override(&"separation", 7)
	scroll.add_child(_rows_container)
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		_build_row(descriptor)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 10)
	column.add_child(footer)
	_status_label = ThemeFactory.label("", 13, ThemeFactory.JADE)
	_status_label.name = "TweakSaveStatus"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_status_label)
	var reset_all := ThemeFactory.button(I18n.t(&"tweak.reset_all"), I18n.t(&"tweak.reset_all_tooltip"))
	reset_all.name = "ResetAllTweaksButton"
	reset_all.custom_minimum_size = Vector2(150.0, 42.0)
	reset_all.pressed.connect(func() -> void: reset_all_requested.emit())
	footer.add_child(reset_all)


func _build_row(descriptor: Dictionary) -> void:
	var id := descriptor["id"] as StringName
	var row := PanelContainer.new()
	row.name = "TweakRow%s" % String(id).replace(".", "_").to_pascal_case()
	row.add_theme_stylebox_override(&"panel", ThemeFactory.hud_inset_style(_category_color(descriptor["category"] as StringName)))
	_rows_container.add_child(row)
	_rows[id] = row

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 12)
	row.add_child(layout)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.custom_minimum_size.x = 390.0
	layout.add_child(copy)
	var title_row := HBoxContainer.new()
	copy.add_child(title_row)
	var title := ThemeFactory.label(I18n.t(descriptor["label_key"] as StringName), 16, ThemeFactory.PARCHMENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var badge := ThemeFactory.label(I18n.t(_apply_mode_key(descriptor["apply_mode"] as StringName)), 11, ThemeFactory.GOLD)
	badge.add_theme_stylebox_override(&"normal", ThemeFactory.badge_style())
	badge.custom_minimum_size.x = 120.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(badge)
	var description := ThemeFactory.label(I18n.t(descriptor["description_key"] as StringName), 12, ThemeFactory.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	var current := ThemeFactory.label("", 11, ThemeFactory.JADE)
	copy.add_child(current)
	_value_labels[id] = current

	var editor: Control
	if descriptor["type"] == &"bool":
		var check := CheckButton.new()
		check.custom_minimum_size = Vector2(118.0, 42.0)
		check.accessibility_name = I18n.t(descriptor["label_key"] as StringName)
		check.toggled.connect(func(value: bool) -> void: value_requested.emit(id, value))
		editor = check
	else:
		var number := SpinBox.new()
		number.custom_minimum_size = Vector2(150.0, 42.0)
		number.min_value = float(descriptor["min"])
		number.max_value = float(descriptor["max"])
		number.step = float(descriptor["step"])
		number.allow_greater = false
		number.allow_lesser = false
		number.update_on_text_changed = true
		number.suffix = I18n.t(descriptor["unit_key"] as StringName)
		number.accessibility_name = I18n.t(descriptor["label_key"] as StringName)
		number.value_changed.connect(func(value: float) -> void: value_requested.emit(id, value))
		editor = number
	layout.add_child(editor)
	_editors[id] = editor

	var reset := ThemeFactory.button(I18n.t(&"tweak.reset"), I18n.t(&"tweak.reset_tooltip"))
	reset.custom_minimum_size = Vector2(92.0, 42.0)
	reset.pressed.connect(func() -> void: reset_requested.emit(id))
	layout.add_child(reset)


func _select_category(category: StringName) -> void:
	_category = category
	_update_filter()


func _on_search_changed(next_text: String) -> void:
	_search_text = next_text.strip_edges().to_lower()
	_update_filter()


func _update_filter() -> void:
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		var category_match: bool = _category == &"ALL" or descriptor["category"] == _category
		var haystack := "%s %s %s %s" % [
			String(id),
			I18n.t(descriptor["label_key"] as StringName),
			I18n.t(descriptor["description_key"] as StringName),
			" ".join(descriptor.get("tags", PackedStringArray())),
		]
		(_rows[id] as Control).visible = category_match and (_search_text.is_empty() or haystack.to_lower().contains(_search_text))


func _update_status() -> void:
	var pending := _service.pending_count()
	if pending > 0:
		_status_label.text = I18n.t(&"tweak.status.pending", {"count": pending})
		_status_label.add_theme_color_override(&"font_color", ThemeFactory.GOLD)
	elif not _service.is_run_active():
		_status_label.text = I18n.t(&"tweak.status.saved_ready")
		_status_label.add_theme_color_override(&"font_color", ThemeFactory.JADE)
	elif _service.run_is_rank_eligible():
		_status_label.text = I18n.t(&"tweak.status.saved_ranked")
		_status_label.add_theme_color_override(&"font_color", ThemeFactory.JADE)
	else:
		_status_label.text = I18n.t(&"tweak.status.saved_unranked")
		_status_label.add_theme_color_override(&"font_color", ThemeFactory.DANGER)


func _format_value(descriptor: Dictionary, value: Variant) -> String:
	if descriptor["type"] == &"bool":
		return I18n.t(&"value.on") if bool(value) else I18n.t(&"value.off")
	var number := "%.2f" % float(value)
	while number.contains(".") and (number.ends_with("0") or number.ends_with(".")):
		number = number.trim_suffix("0") if number.ends_with("0") else number.trim_suffix(".")
	return I18n.t(&"tweak.value_with_unit", {
		"value": number,
		"unit": I18n.t(descriptor["unit_key"] as StringName),
	})


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_panel()
		accept_event()


func _category_key(category: StringName) -> StringName:
	return StringName("tweak.category.%s" % String(category).to_lower())


func _apply_mode_key(mode: StringName) -> StringName:
	return StringName("tweak.apply.%s" % String(mode).to_lower())


func _category_color(category: StringName) -> Color:
	match category:
		CATALOG.UI: return ThemeFactory.JADE
		CATALOG.GAMEPLAY: return ThemeFactory.GOLD
		CATALOG.AUDIO: return ThemeFactory.ESSENCE
		CATALOG.PLAYER: return Color("78dfb7")
		CATALOG.ENEMIES: return ThemeFactory.DANGER
		_: return Color("77c6ff")


func _same_value(left: Variant, right: Variant) -> bool:
	if (left is float or left is int) and (right is float or right is int):
		return is_equal_approx(float(left), float(right))
	return left == right
