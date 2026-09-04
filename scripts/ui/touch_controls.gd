class_name TouchControls
extends Control

signal workers_requested
signal army_requested
signal move_requested
signal attack_requested
signal context_requested
signal cancel_requested

const PANEL_SIZE := Vector2(188.0, 164.0)

var _panel: PanelContainer


func _ready() -> void:
	name = "TouchControls"
	z_index = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "TouchControlDock"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(&"panel", ThemeFactory.hud_deck_style(ThemeFactory.JADE))
	add_child(_panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 5)
	grid.add_theme_constant_override(&"v_separation", 5)
	_panel.add_child(grid)
	_add_button(grid, &"touch.workers", workers_requested)
	_add_button(grid, &"touch.army", army_requested)
	_add_button(grid, &"touch.move", move_requested)
	_add_button(grid, &"touch.attack", attack_requested)
	_add_button(grid, &"touch.order", context_requested)
	_add_button(grid, &"touch.cancel", cancel_requested)
	visible = false


func apply_layout(safe: Rect2, bottom_inset: float) -> void:
	_panel.position = Vector2(
		safe.end.x - PANEL_SIZE.x,
		safe.end.y - bottom_inset - PANEL_SIZE.y,
	)
	_panel.size = PANEL_SIZE


func occupied_height() -> float:
	return PANEL_SIZE.y


func _add_button(grid: GridContainer, key: StringName, action_signal: Signal) -> void:
	var button := ThemeFactory.button(I18n.t(key), I18n.t(StringName("%s_tooltip" % String(key))))
	button.name = "%sTouchButton" % String(key).get_slice(".", 1).capitalize()
	button.custom_minimum_size = Vector2(86.0, ResponsiveLayout.MIN_TOUCH_TARGET)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void: action_signal.emit())
	grid.add_child(button)
