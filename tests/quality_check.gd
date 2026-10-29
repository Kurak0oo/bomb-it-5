extends SceneTree
## #86: the original quality switch (`qualityCtlHandle`) mapped to edge smoothing.

const App = preload("res://scripts/app.gd")
const Quality = preload("res://scripts/quality.gd")
const SAVE := "user://quality-check-save.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(Quality.level == &"high", "the quality starts HIGH (`GameModel.quality` unset)")
	var seen: Array = []
	for step in 3: seen.append(Quality.cycle())
	_expect(seen == [&"medium", &"low", &"high"], "each press cycles HIGH → MEDIUM → LOW → HIGH")
	var levels := Quality.LEVELS.map(func(level): return Quality.settings(level))
	_expect(levels[0].edges and levels[1].edges and not levels[2].edges, "HIGH and MEDIUM anti-alias shapes, LOW does not")
	_expect(levels[0].filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		and levels[1].filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		and levels[2].filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "only HIGH smooths bitmaps")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var app := App.new()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	_expect(root.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR and Quality.edges,
		"the app applies HIGH at start")
	var switch: Button = app.find_child("QualitySwitch", true, false)
	_expect(switch != null, "the main menu has the quality switch")
	switch.pressed.emit()
	_expect(Quality.level == &"medium" and Quality.edges
		and root.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"pressing it applies MEDIUM to the stage")
	switch.pressed.emit()
	_expect(Quality.level == &"low" and not Quality.edges, "pressing again applies LOW")
	switch.pressed.emit()
	switch.pressed.emit()
	app.show_settings()
	await process_frame
	app.show_main_menu()
	await process_frame
	var again: Button = app.find_child("QualitySwitch", true, false)
	_expect(again.frame == 1, "the switch keeps the session's level on returning to the menu")
	_expect(not FileAccess.file_exists(SAVE) or not FileAccess.get_file_as_string(SAVE).contains("quality"),
		"the level is not saved, as `GameModel.quality` is not in `Cookie`")
	app.queue_free()
	await process_frame
	print("%s: %d quality checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)
