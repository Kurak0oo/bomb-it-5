extends SceneTree
## Measures the local pack's `screen.*` sheets so `scripts/art/screen_layout.gd` can be
## filled in without guessing. Local-only: it needs the ignored pack; it is not a check.
##
##     Godot --headless --path . --script res://tools/inspect_screen_art.gd
##     Godot --headless --path . --script res://tools/inspect_screen_art.gd -- --step 10 --ids screen.menu
##
## Prints, per page: sheet size, columns/rows, the plate region (the layout crop when
## there is one), the visible-pixel box, the page rectangle `Skin.screen_frame` fits,
## the sampled edge colour and a summary of the opaque horizontal runs per row.

const VisualSkin = preload("res://scripts/art/skin.gd")
const Layout = preload("res://scripts/art/screen_layout.gd")

var skin: RefCounted
var _step := 20
var _only: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--step" and index + 1 < args.size(): _step = int(args[index + 1])
		if args[index] == "--ids" and index + 1 < args.size(): _only.assign(args[index + 1].split(","))
	skin = VisualSkin.new()
	var seen := {}
	for id in _screen_ids():
		if not _only.is_empty() and id not in _only: continue
		seen[id] = true
		_page(id)
	for id in _only:
		if not seen.has(id): print("%s: no sheet in the local pack" % id)
	quit(0)


func _screen_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ["screen.menu", "screen.settings", "screen.character", "screen.how_to_play",
		"screen.power_ups", "screen.score", "screen.dress_up", "screen.game_over", "screen.game_win"]:
		if skin.has_screen(id): ids.append(id)
	return ids


func _page(id: String) -> void:
	var crop: Rect2 = Layout.crop_from_id(id)
	var plate: AtlasTexture = skin.screen_plate(id, crop)
	var image := plate.atlas.get_image()
	var record: Dictionary = skin.entry(id)
	if record.is_empty(): record = _record(id)
	var frame: Rect2 = skin.screen_frame(id, crop)
	print("== %s" % id)
	print("   sheet %s  columns %s  rows %s" % [image.get_size(), record.get("columns", 1), record.get("rows", 1)])
	print("   region %s  visible %s" % [plate.region, image.get_region(Rect2i(plate.region)).get_used_rect()])
	print("   frame  %s  fill %s" % [frame, skin.screen_fill(id, crop).to_html(false)])
	var box := image.get_region(Rect2i(plate.region)).get_used_rect()
	if box.size.x <= 0: return
	var top := box.position.y + int(plate.region.position.y)
	var left := box.position.x + int(plate.region.position.x)
	var right := left + box.size.x
	for y in range(top, top + box.size.y, _step):
		var runs := _runs(image, y, left, right)
		if not runs.is_empty(): print("   y %4d %s" % [y, "  ".join(runs)])


## Opaque horizontal runs of at least 40 px, as `x0-x1`.
func _runs(image: Image, y: int, left: int, right: int) -> Array[String]:
	var runs: Array[String] = []
	var start := -1
	for x in range(left, right):
		var opaque := image.get_pixel(x, y).a > 0.5
		if opaque and start < 0: start = x
		if not opaque and start >= 0:
			if x - start >= 40: runs.append("%d-%d" % [start, x - 1])
			start = -1
	if start >= 0 and right - start >= 40: runs.append("%d-%d" % [start, right - 1])
	return runs


func _record(id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VisualSkin.ORIGINAL_PACK))
	if parsed is Dictionary: return parsed.get("overrides", {}).get(id, {})
	return {}
