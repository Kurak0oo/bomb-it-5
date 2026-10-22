extends SceneTree
## Desktop UI verification through real clicks and file selection.
var bench: Control
var failures := 0
var checks := 0
var active_before := ""
var draft_before := ""
var had_draft := false
var fixture_paths: Array[String] = []
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
	_expect(bench.cards.size() == bench.definitions.filter(func(entry): return entry.category == "Effects").size(),
		"category click displays every effect and recovery slot")
	for name in ["Stage sets", "Looks", "Modes", "Screens"]:
		await _click(_text_button(name))
		_expect(bench.cards.size() > 0 and bench.cards.keys().all(func(id): return bench.definitions.any(func(entry): return entry.id == id and entry.category == name)),
			"the %s category lists its new slots" % name)
	await _click(_text_button("Effects"))
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
	_expect(bench.preview_mode.selected == 0, "practice stays the default preview")
	bench.preview_mode.select(3)
	bench.preview_set.select(1 + bench.StageSets.ORDER.find(&"zoo"))
	await _click(bench.find_child("PreviewGame", true, false))
	if is_instance_valid(bench.preview_window):
		var level = bench.preview_window.get_child(0)
		level.set_process(false)
		var shown: Dictionary = level.get_snapshot()
		_expect(shown.mode == &"pac_man" and shown.board_meta.skin == &"zoo" and String(shown.board_meta.layout).contains("_PacMan_"),
			"Preview in game can start a chosen mode on a chosen stage set")
		bench.preview_window.queue_free()
	bench.preview_mode.select(0)
	bench.preview_set.select(0)
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
	await _check_rendering(folder)
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
	fixture_paths.append(bench.draft.entry("effect.bomb").get("path", ""))
	for fixture in fixture_paths:
		if fixture != "" and not active_before.contains(fixture) and not draft_before.contains(fixture):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	var report := FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures,
		"components": bench.definitions.size(), "picker_completion": "public file_selected signal",
		"profiles_restored": FileAccess.get_file_as_string(VisualSkin.ACTIVE) == active_before}, "  "))
	report.close()
	print("%s: %d art workbench UI checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _check_rendering(folder: String) -> void:
	# Render copied public snapshots: this fixture never mutates the live round.
	var library := VisualSkin.new(false)
	library.import_image("actor.human.action", folder.path_join("fixture.png"))
	library.configure("actor.human.action", {"columns": 2})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Node2D.new()
	viewport.add_child(host)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_process(false)
	var snapshot: Dictionary = game.get_snapshot()
	game.queue_free()
	var view = load("res://scripts/game_view.gd").new()
	view.skin = library
	host.add_child(view)
	var cell: Vector2i = snapshot.actors[&"human"].cell
	var at := Vector2(334, 86) + (Vector2(cell) + Vector2.ONE * 0.5) * 36
	for age in [0, 12]:
		var expected := Color("e78dbb") if age == 0 else Color("6bdad0")
		for tick in [5, 105]:
			snapshot.tick = tick
			snapshot.attacks = [{"actor_id": &"human", "kind": &"hammer", "cell": cell,
				"direction": Vector2i.DOWN, "frame": age, "fired": true}]
			view.present(snapshot, true, false)
			await process_frame
			await RenderingServer.frame_post_draw
			var actual := viewport.get_texture().get_image().get_pixelv(Vector2i(at + Vector2(-14, -15)))
			_expect(actual.is_equal_approx(expected), "character action frame %d follows action age at round tick %d" % [age, tick])
	library.reset_slot("actor.human.action")
	var sample = load("res://scripts/art/component_canvas.gd").new()
	sample.skin = library
	host.add_child(sample)
	sample.set_process(false)
	sample.sample_tick = 12
	sample.state.tick = 12
	for id in ["effect.bomb", "attack.hammer", "effect.invincible", "held.hammer", "actor.human.action",
		"item.coin", "effect.horse", "board.zoo.crocodile", "look.human.hat1", "actor.snow.idle"]:
		library.import_image(id, folder.path_join("fixture.png"))
		library.configure(id, {"columns": 2, "fps": 0})
		snapshot.tick = 12
		snapshot.actors[&"human"].position = Vector2.ZERO
		snapshot.actors[&"human"].weapon = &"hammer" if id == "held.hammer" else &""
		snapshot.actors[&"human"].invincible_until = 100 if id == "effect.invincible" else 0
		snapshot.bombs = [{"cell": Vector2i.ZERO}] if id == "effect.bomb" else []
		snapshot.pickups = {Vector2i.ZERO: &"coin"} if id == "item.coin" else {}
		snapshot.actors[&"human"].vehicle = &"horse" if id == "effect.horse" else &""
		snapshot.actors[&"human"].hat = 1 if id == "look.human.hat1" else 0
		snapshot.actors[&"human"].robot = 7 if id == "actor.snow.idle" else 0
		snapshot.features = [{"kind": &"crocodile", "cell": Vector2i(2, 2), "phase": &"closed", "danger": false}] if id == "board.zoo.crocodile" else []
		snapshot.board_meta = {"skin": &"zoo", "size": Vector2i(17, 15)} if id == "board.zoo.crocodile" else {"skin": &"cinema"}
		snapshot.attacks = [{"actor_id": &"human", "kind": &"hammer", "cell": Vector2i.ZERO,
			"direction": Vector2i.DOWN, "frame": 12, "fired": true}] if id in ["attack.hammer", "actor.human.action"] else []
		view.show()
		sample.hide()
		view.present(snapshot, true, false)
		await process_frame
		await RenderingServer.frame_post_draw
		var color := Color("6bdad0") if not snapshot.attacks.is_empty() else Color("e78dbb")
		var in_game := _color_bounds(viewport.get_texture().get_image(), color)
		view.hide()
		sample.show()
		sample.component_id = id
		sample.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var in_inspector := _color_bounds(viewport.get_texture().get_image(), color)
		_expect(in_game.has_area() and in_inspector == in_game,
			"%s inspector matches game placement, size and action phase: %s / %s" % [id, in_inspector, in_game])
		library.reset_slot(id)
	var phases := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for index in 4:
		phases.fill_rect(Rect2i(index * 32, 0, 32, 32), Color(["e78dbb", "63cb74", "f5bd50", "6bdad0"][index]))
	phases.save_png(folder.path_join("phases.png"))
	for case in [["laser", 0], ["laser", 11], ["flamer", 0], ["flamer", 1]]:
		var id: String = "attack." + case[0]
		library.import_image(id, folder.path_join("phases.png"))
		fixture_paths.append(library.entry(id).path)
		library.configure(id, {"columns": 4, "fps": 0})
		var fired: bool = case[1] >= (11 if case[0] == "laser" else 1)
		snapshot.attacks = [{"actor_id": &"human", "kind": StringName(case[0]), "cell": Vector2i.ZERO,
			"direction": Vector2i.DOWN, "frame": case[1], "fired": fired,
			"cells": [Vector2i.ZERO] if fired else [], "started": 0, "ready": 11}]
		view.show()
		sample.hide()
		view.present(snapshot, true, false)
		await process_frame
		await RenderingServer.frame_post_draw
		var color := Color("6bdad0") if case == ["laser", 11] else Color("e78dbb")
		var in_game := _color_bounds(viewport.get_texture().get_image(), color)
		if case == ["laser", 11]: _expect(in_game.has_area(), "laser final animation frame is reachable before recovery ends")
		view.hide()
		sample.show()
		sample.component_id = id
		sample.sample_tick = case[1]
		sample.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(in_game.has_area() and _color_bounds(viewport.get_texture().get_image(), color) == in_game,
			"%s sample matches charge/active phase at age %d" % [id, case[1]])
		library.reset_slot(id)
	viewport.queue_free()


func _color_bounds(image: Image, color: Color) -> Rect2i:
	var first := Vector2i(9999, 9999)
	var last := Vector2i(-1, -1)
	for y in range(20, 270):
		for x in range(260, 500):
			if image.get_pixel(x, y).is_equal_approx(color):
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= 0 else Rect2i()


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
