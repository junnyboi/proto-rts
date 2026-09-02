extends SceneTree

const OUTPUT := "res://captures/cursor-system.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var background := ColorRect.new()
	background.color = Color("071416")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var content := VBoxContainer.new()
	content.position = Vector2(56.0, 30.0)
	content.size = Vector2(1168.0, 660.0)
	content.add_theme_constant_override(&"separation", 16)
	background.add_child(content)

	var title := ThemeFactory.label("THE JADE COMMAND RELIC", 28, ThemeFactory.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := ThemeFactory.label(
		"17 native, browser-safe cursor states · rendered at the shipped 64 × 64 resolution",
		15,
		ThemeFactory.MUTED,
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	content.add_child(grid)
	for state in CursorSystem.ORDER:
		grid.add_child(_cursor_card(state))

	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT)
	var result := image.save_png(path)
	if result != OK:
		push_error("failed to save cursor gallery: %s" % error_string(result))
		quit(1)
		return
	print("PASS cursor_visual_capture: %s" % path)
	quit(0)


func _cursor_card(state: StringName) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(184.0, 154.0)
	card.add_theme_stylebox_override(
		&"panel",
		ThemeFactory.panel_style(Color("102628"), Color("31514e"), 1, 8),
	)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 4)
	card.add_child(column)
	var art := TextureRect.new()
	art.texture = CursorSystem.texture_for(state)
	art.custom_minimum_size = Vector2(76.0, 76.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(art)
	var name_label := ThemeFactory.label(CursorSystem.label_for(state).to_upper(), 14, ThemeFactory.PARCHMENT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var id_label := ThemeFactory.label(String(state), 11, ThemeFactory.JADE)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(id_label)
	return card
