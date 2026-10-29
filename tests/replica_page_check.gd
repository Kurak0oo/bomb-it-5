extends SceneTree
## The replica's mobile-first page (#89-#92; DESIGN.md › Gameplay layout): page fit and safe
## area at phone and tablet sizes, the 48 px full board, and nothing but the map on it.

const ReplicaLayout = preload("res://scripts/replica_layout.gd")
const Fidelity = preload("res://scripts/fidelity.gd")
## Logical viewports under `canvas_items` + `expand` at 720 px height, with safe areas.
## 2532×1170 (iPhone 13/14) has a 47 pt sensor housing on one side and a 21 pt home indicator.
const PHONE := Vector2(2532.0 * 720 / 1170, 720)
const NOTCH := 47.0 * 3 * 720 / 1170
const INDICATOR := 21.0 * 3 * 720 / 1170
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_page_fit()
	await _scene()
	print("%s: %d replica page checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _page_fit() -> void:
	for side in [-1, 1]:
		var safe := Rect2(NOTCH if side < 0 else 0, 0, PHONE.x - NOTCH, PHONE.y - INDICATOR)
		var placed := ReplicaLayout.fit(PHONE, safe)
		var page := Rect2(placed.offset, ReplicaLayout.PAGE * placed.scale)
		_expect(placed.scale == 1.0, "2532×1170 notch %s: the page keeps 1:1" % ("left" if side < 0 else "right"))
		_expect(page.position.x >= safe.position.x and page.end.x <= safe.end.x,
			"2532×1170 notch %s: the page stays clear of the sensor housing" % ("left" if side < 0 else "right"))
		_expect(_inside(_important(page), safe), "2532×1170 notch %s: HUD, controls and map stay in the safe area" % ("left" if side < 0 else "right"))
		_expect(absf(page.get_center().y - 360) < 1, "2532×1170: the page is centred vertically")
	var full := ReplicaLayout.fit(Vector2(1280, 720), Rect2(0, 0, 1280, 720))
	_expect(full.scale == 1.0 and full.offset == Vector2.ZERO, "1920×1080 (16:9): the page fills the screen")
	var tablet := ReplicaLayout.fit(Vector2(1280, 960), Rect2(0, 0, 1280, 960))
	_expect(tablet.scale == 1.0 and tablet.offset == Vector2(0, 120), "2048×1536 (4:3): the page centres with scenery above and below")
	var cramped := ReplicaLayout.fit(Vector2(1280, 720), Rect2(100, 0, 1080, 720))
	_expect(cramped.scale < 1.0 and cramped.offset.x >= 100 and cramped.offset.x + 1280 * cramped.scale <= 1180.5,
		"a safe area narrower than the page scales it down inside the safe area")
	_expect(ReplicaLayout.BOARD.size == Vector2(ReplicaLayout.BOARD_CELLS) * ReplicaLayout.CELL and ReplicaLayout.BOARD.size.y == 720,
		"the whole 17×15 board fills the page height at 48 px cells")
	_expect(ReplicaLayout.MAP.position.x == ReplicaLayout.BOARD.position.x + ReplicaLayout.CELL / 2
		and ReplicaLayout.MAP.end.x == ReplicaLayout.BOARD.end.x - ReplicaLayout.CELL / 2,
		"the outer ring columns are cropped to half a cell")


func _scene() -> void:
	Fidelity.original = true
	var game = load("res://scripts/game.gd").new()
	game.safe_area_override = Rect2(NOTCH, 0, PHONE.x - NOTCH, PHONE.y - INDICATOR)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(false, 42)
	game.fit_page(PHONE)
	_expect(game.position.x >= NOTCH and game.scale == Vector2.ONE, "the scene places the page inside the phone's safe area")
	var view: Node2D = game.view
	var cell_origin: Vector2 = view.position + view.scale * (ReplicaLayout.VIEW_ORIGIN + Vector2(3, 4) * ReplicaLayout.VIEW_PITCH)
	_expect(cell_origin.is_equal_approx(ReplicaLayout.cell_rect(Vector2i(3, 4)).position) and is_equal_approx(view.scale.x * ReplicaLayout.VIEW_PITCH, 48.0),
		"board cells draw at 48 px on the page")
	_expect(view.compact, "the view draws only the board: no titles, captions or hints")
	var visible_buttons: Array = game.buttons.keys().filter(func(key): return game.buttons[key].visible)
	_expect(visible_buttons.is_empty(), "no development buttons appear during play (visible: %s)" % [visible_buttons])
	var covered := true
	for area in game.scenery.areas():
		covered = covered and not area.intersects(ReplicaLayout.MAP)
	_expect(covered and game.scenery.get_index() > view.get_index(), "the scenery covers everything but the map, above the board")
	_expect(game.scenery.stage_set == game.get_snapshot().board_meta.skin, "the scenery follows the round's stage set")
	game.toggle_pause()
	_expect(game.buttons.pause.visible and ReplicaLayout.MAP.encloses(Rect2(game.buttons.pause.position, game.buttons.pause.size)),
		"pause shows RESUME over the map centre")
	game.toggle_pause()
	_expect(not game.buttons.pause.visible, "resuming hides the pause controls")
	game.queue_free()
	await process_frame


## Everything a player must see or touch: HUD strip, map and both control areas, without the
## one ring row each at the top and bottom edge.
func _important(page: Rect2) -> Rect2:
	return Rect2(page.position + Vector2(0, ReplicaLayout.CELL), Vector2(page.size.x, page.size.y - ReplicaLayout.CELL * 2))


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)
