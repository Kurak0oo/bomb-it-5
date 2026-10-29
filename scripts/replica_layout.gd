extends RefCounted
## The replica's mobile-first gameplay page under the `original` profile (DESIGN.md › Gameplay
## layout, L1/L2 and M1–M6; docs/design/replica-layout-zones.png). Pure geometry: the scene
## applies it, checks call it directly.

## The page every element is placed on; it keeps 16:9 and centres on any screen (L2).
const PAGE := Vector2(1280, 720)
## 48 px cells: the 15-row board fills the page height (M1).
const CELL := 48.0
const BOARD_CELLS := Vector2i(17, 15)
## The whole board, centred on the page.
const BOARD := Rect2(232, 0, 816, 720)
## The visible map: the outer ring columns are cropped to half a cell, as the mockup shows.
const MAP := Rect2(256, 0, 768, 720)
## Side areas for scenery and controls (zones 5 and 6).
const LEFT := Rect2(0, 0, 256, 720)
const RIGHT := Rect2(1024, 0, 256, 720)
## Native board geometry the view draws in (GameView.ORIGIN / PITCH).
const VIEW_ORIGIN := Vector2(334, 86)
const VIEW_PITCH := 36.0


## Scale and offset that place the page in the viewport: centred, never larger than 1:1 of
## the logical page, and kept inside `safe` (notch, Dynamic Island, home indicator).
## The top and bottom rows hold only the board's cropped outer ring, so up to one cell of
## each may sit under a top or bottom inset (the home indicator) without shrinking the page.
static func fit(viewport: Vector2, safe: Rect2) -> Dictionary:
	if safe.size.x <= 0 or safe.size.y <= 0: safe = Rect2(Vector2.ZERO, viewport)
	var top := minf(safe.position.y, CELL)
	var bottom := minf(viewport.y - safe.end.y, CELL)
	safe = safe.grow_individual(0, maxf(0, top), 0, maxf(0, bottom))
	var scale := minf(1.0, minf(safe.size.x / PAGE.x, safe.size.y / PAGE.y))
	var size := PAGE * scale
	var offset := (viewport - size) * 0.5
	offset.x = clampf(offset.x, safe.position.x, safe.end.x - size.x)
	offset.y = clampf(offset.y, safe.position.y, safe.end.y - size.y)
	return {"scale": scale, "offset": offset.round()}


## The window's safe area in logical viewport units; the whole viewport off-device.
static func safe_area(viewport: Vector2) -> Rect2:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0 or window.y <= 0 or DisplayServer.get_name() == "headless": return Rect2(Vector2.ZERO, viewport)
	var screen := DisplayServer.window_get_current_screen()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var origin := Vector2(DisplayServer.window_get_position()) - Vector2(DisplayServer.screen_get_position(screen))
	var local := Rect2(safe.position - origin, safe.size).intersection(Rect2(Vector2.ZERO, window))
	if local.size.x <= 0 or local.size.y <= 0: return Rect2(Vector2.ZERO, viewport)
	var ratio := viewport / window
	return Rect2(local.position * ratio, local.size * ratio)


## The transform that draws the native 36 px board as the 48 px page board.
static func view_scale() -> float:
	return CELL / VIEW_PITCH


static func view_position() -> Vector2:
	return BOARD.position - VIEW_ORIGIN * view_scale()


## Page rectangle of a board cell.
static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD.position + Vector2(cell) * CELL, Vector2.ONE * CELL)
