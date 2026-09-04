class_name TutorialCallout
extends PanelContainer

signal skip_requested

var _title: Label
var _progress: Label
var _body: Label
var _input: Label
var _skip: Button
var _callout: Dictionary = {}


func _ready() -> void:
	name = "TutorialCallout"
	z_index = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(360.0, 178.0)
	add_theme_stylebox_override(
		&"panel",
		ThemeFactory.panel_style(Color("071313f6"), Color(ThemeFactory.JADE, 0.92), 2, 12),
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = ThemeFactory.label("", 19, ThemeFactory.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_progress = ThemeFactory.label("", 11, ThemeFactory.MUTED_SAGE)
	header.add_child(_progress)
	_body = ThemeFactory.label("", 13, ThemeFactory.IVORY)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.y = 54.0
	column.add_child(_body)
	_input = ThemeFactory.label("", 12, ThemeFactory.JADE)
	_input.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_input)
	_skip = ThemeFactory.button(I18n.t(&"tutorial.skip"), I18n.t(&"tutorial.skip_tooltip"))
	_skip.name = "SkipTutorialButton"
	_skip.custom_minimum_size = Vector2(132.0, 38.0)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip.pressed.connect(func() -> void: skip_requested.emit())
	column.add_child(_skip)
	visible = false


func show_callout(callout: Dictionary) -> void:
	_callout = callout.duplicate(true)
	if _callout.is_empty():
		visible = false
		return
	_refresh_copy()
	visible = true


func refresh_locale() -> void:
	if not _callout.is_empty():
		_refresh_copy()


func apply_layout(portrait: bool, safe: Rect2, top_inset: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var width := minf(420.0 if not portrait else safe.size.x, safe.size.x)
	var height := 190.0 if not portrait else 206.0
	offset_left = safe.end.x - width
	offset_right = safe.end.x
	offset_top = maxf(safe.position.y, top_inset)
	offset_bottom = offset_top + height


func _refresh_copy() -> void:
	var body_key: StringName = (
		_callout.get("fallback_key", &"") as StringName
		if bool(_callout.get("fallback_active", false))
		else _callout.get("body_key", &"") as StringName
	)
	_title.text = I18n.t(_callout.get("title_key", &"") as StringName)
	_body.text = I18n.t(body_key)
	_input.text = I18n.t(_callout.get("input_key", &"") as StringName)
	_progress.text = I18n.t(&"tutorial.progress", {
		"step": int(_callout.get("step", 1)),
		"total": int(_callout.get("total", 1)),
	})
	_skip.text = I18n.t(&"tutorial.skip")
	_skip.tooltip_text = I18n.t(&"tutorial.skip_tooltip")
	accessibility_name = "%s. %s" % [_title.text, _body.text]
