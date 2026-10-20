extends SceneTree
## Desktop UI verification through real clicks and file selection.
var bench: Control
var failures := 0
var checks := 0
var active_before := ""
var draft_before := ""
var had_draft := false
const VisualSkin = preload("res://scripts/art/skin.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	active_before = FileAccess.get_file_as_string(VisualSkin.ACTIVE)
	had_draft = FileAccess.file_exists(VisualSkin.DRAFT)
	if had_draft: draft_before = FileAccess.get_file_as_string(VisualSkin.DRAFT)
	root.size = Vector2i(1600, 900)
	bench = load("res://scenes/art_workbench.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	await process_frame
	await _capture("overview")
	await _click(_text_button("Effects"))
	_expect(bench.cards.size() == 12, "category click displays every effect and recovery slot")
	await _click(bench.cards["effect.bomb"].button)
	_expect(bench.selected == "effect.bomb", "component card click selects its inspector")
	await _capture("bomb-inspector")
	# Distinct, disposable verification artwork, not a proposed game art direction.
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("e78dbb"))
	image.fill_rect(Rect2i(32, 0, 32, 32), Color("6bdad0"))
	var folder := ProjectSettings.globalize_path("res://.scratch/art-workbench-check")
	image.save_png(folder.path_join("fixture.png"))
	await _click(bench.find_child("Replace", true, false))
	_expect(bench.file_dialog.visible, "Replace opens the desktop image chooser")
	# The OS/engine picker is outside this scene's mouse-routing seam. Complete
	# selection through its public signal; all project buttons receive real clicks.
	bench.file_dialog.file_selected.emit(folder.path_join("fixture.png"))
	bench.file_dialog.hide()
	_expect(not bench.draft.entry("effect.bomb").is_empty(), "choosing an image creates a draft replacement")
	_expect(FileAccess.get_file_as_string(VisualSkin.ACTIVE) == active_before, "import leaves applied game art unchanged")
	bench.form.columns.value = 2
	bench.form.scale.value = 1.25
	_expect(bench.draft.entry("effect.bomb").get("columns") == 2 and bench.draft.entry("effect.bomb").get("scale") == 1.25,
		"sprite controls update the selected draft")
	await _capture("replacement-draft")
	await _click(bench.find_child("PreviewGame", true, false))
	_expect(is_instance_valid(bench.preview_window), "Preview in game opens the actual game")
	if is_instance_valid(bench.preview_window):
		var game = bench.preview_window.get_child(0)
		game.set_process(false)
		_expect(game.get_snapshot().board.size() == 255 and game.visual_skin.entry("effect.bomb").get("columns") == 2,
			"game preview uses the real fixed board and the draft skin")
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		game.get_viewport().push_input(key, true)
		game.advance_time(1.0 / 35.0)
		_expect(game.get_snapshot().bombs.any(func(bomb): return bomb.actor_id == &"human"),
			"the real game still accepts bomb input with a draft replacement")
		await process_frame
		await RenderingServer.frame_post_draw
		bench.preview_window.get_texture().get_image().save_png(folder.path_join("real-game-preview.png"))
		bench.preview_window.queue_free()
	await process_frame
	await _click(bench.find_child("Apply", true, false))
	var loaded = VisualSkin.new()
	_expect(loaded.entry("effect.bomb").columns == 2, "Apply persists art for a fresh game launch")
	await _click(bench.find_child("ResetSlot", true, false))
	_expect(bench.draft.entry("effect.bomb").is_empty(), "Use default removes the selected draft override")
	await _click(bench.find_child("Undo", true, false))
	_expect(not bench.draft.entry("effect.bomb").is_empty(), "Undo restores the replaced component")
	bench.file_dialog.file_selected.emit("res://docs/evidence/reference-2026-10-19/cinema-observed-01/opening-board.png")
	_expect(bench.status.text.begins_with("Original references are view-only"), "reference art cannot be installed from the research folder")
	# Always restore the user's profile before finishing this graphical check.
	var active := FileAccess.open(VisualSkin.ACTIVE, FileAccess.WRITE)
	active.store_string(active_before)
	active.close()
	if had_draft:
		var draft := FileAccess.open(VisualSkin.DRAFT, FileAccess.WRITE)
		draft.store_string(draft_before)
		draft.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(VisualSkin.DRAFT))
	var fixture: String = bench.draft.entry("effect.bomb").get("path", "")
	if fixture != "" and not active_before.contains(fixture) and not draft_before.contains(fixture):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	var report := FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures,
		"components": bench.definitions.size(), "picker_completion": "public file_selected signal",
		"profiles_restored": FileAccess.get_file_as_string(VisualSkin.ACTIVE) == active_before}, "  "))
	report.close()
	print("%s: %d art workbench UI checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _text_button(prefix: String) -> Button:
	for node in bench.find_children("*", "Button", true, false):
		if node.text.begins_with(prefix): return node
	return null


func _click(control: Control) -> void:
	assert(control != null)
	await _click_at(control.get_viewport(), control.get_global_rect().get_center())


func _click_at(viewport: Viewport, at: Vector2) -> void:
	var input := InputEventMouseButton.new()
	input.button_index = MOUSE_BUTTON_LEFT
	input.position = at
	input.pressed = true
	viewport.push_input(input, true)
	input = input.duplicate()
	input.pressed = false
	viewport.push_input(input, true)
	await process_frame
	await process_frame


func _expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://.scratch/art-workbench-check")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
	print("CAPTURE: ", label)
