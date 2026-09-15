extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("font_rendering_test requires a native renderer; omit --headless")
		quit(1)
		return
	var reduced := ThemeFactory.CJK_FONT
	var report := JSON.parse_string(FileAccess.get_file_as_string("res://assets/runtime/fonts/font-report.json")) as Dictionary
	var text := ""
	var count := 0
	for raw_codepoint: String in report["requested_codepoints"]:
		var codepoint := raw_codepoint.trim_prefix("U+").hex_to_int()
		if raw_codepoint in report["source_unsupported_codepoints"]:
			continue
		if not reduced.has_char(codepoint):
			push_error("Bundled full font lacks required character %s" % raw_codepoint)
			quit(1)
			return
		if codepoint < 33 or codepoint in [0x2028, 0x2029]:
			continue
		text += String.chr(codepoint)
		count += 1
		if count % 24 == 0:
			text += "\n"
	var original_path := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
	if not ResourceLoader.exists(original_path):
		print("PASS font_rendering_test: full font coverage; SKIP original comparison because source archive is not installed")
		quit(0)
		return
	var original := load(original_path) as FontFile
	for font_size: int in [12, 17, 24, 48]:
		var viewports: Array[SubViewport] = []
		for font: FontFile in [original, reduced]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1600, 2800)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.disable_3d = true
			var background := ColorRect.new()
			background.color = Color.BLACK
			background.size = Vector2(1600, 2800)
			viewport.add_child(background)
			var label := Label.new()
			label.position = Vector2(16, 16)
			label.text = text
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", Color.WHITE)
			viewport.add_child(label)
			root.add_child(viewport)
			viewports.append(viewport)
		for frame in range(3):
			await process_frame
		for viewport: SubViewport in viewports:
			var label := viewport.get_child(1) as Label
			if label.get_minimum_size().x + 16 > viewport.size.x or label.get_minimum_size().y + 16 > viewport.size.y:
				push_error("Font comparison canvas is too small for the expanded glyph set")
				quit(1)
				return
		await RenderingServer.frame_post_draw
		var before := viewports[0].get_texture().get_image()
		var after := viewports[1].get_texture().get_image()
		if before.get_data() != after.get_data():
			var capture_dir := OS.get_environment("FONT_CAPTURE_DIR")
			if not capture_dir.is_empty():
				DirAccess.make_dir_recursive_absolute(capture_dir)
				before.save_png(capture_dir.path_join("original-%d.png" % font_size))
				after.save_png(capture_dir.path_join("full-%d.png" % font_size))
			push_error("Font pixels differ at %dpx" % font_size)
			quit(1)
			return
		print("PASS font_rendering_test: %d characters have identical pixels at %dpx" % [count, font_size])
		for viewport: SubViewport in viewports:
			viewport.queue_free()
		await process_frame
	quit(0)
