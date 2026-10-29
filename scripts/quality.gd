extends RefCounted
## The original quality switch (#86): `MainMenuUI`/`PauseUI.qualityCtlHandle` cycle the stage
## quality HIGH → MEDIUM → LOW → HIGH and keep it in `GameModel.quality` for the session only
## (not in `Cookie`); HIGH when unset. Flash `StageQuality`: HIGH anti-aliases shapes and
## smooths bitmaps, MEDIUM anti-aliases shapes but leaves bitmaps unsmoothed, LOW does neither.
## The Compatibility renderer has no 2D multisampling, so the replica maps bitmap smoothing to
## the default texture filter and shape anti-aliasing to `edges`, the antialiased flag every
## procedural line and arc passes; MSAA is still requested where a renderer supports it.

const LEVELS: Array[StringName] = [&"high", &"medium", &"low"]
const TITLES := {&"high": "HIGH", &"medium": "MEDIUM", &"low": "LOW"}

static var level: StringName = &"high"
## Whether procedural lines and arcs are drawn anti-aliased at the current level.
static var edges := true


static func index() -> int:
	return LEVELS.find(level)


static func cycle() -> StringName:
	level = LEVELS[(index() + 1) % LEVELS.size()]
	return level


## The viewport's 2D multisampling and default texture filter for `quality`.
static func settings(quality: StringName) -> Dictionary:
	match quality:
		&"low": return {"msaa": Viewport.MSAA_DISABLED, "filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "edges": false}
		&"medium": return {"msaa": Viewport.MSAA_2X, "filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "edges": true}
	return {"msaa": Viewport.MSAA_4X, "filter": Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR, "edges": true}


static func apply(viewport: Viewport) -> void:
	if viewport == null: return
	var chosen := settings(level)
	edges = chosen.edges
	# GLES3 warns that 2D MSAA is unsupported; only ask for it where it exists.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility": viewport.msaa_2d = chosen.msaa
	viewport.canvas_item_default_texture_filter = chosen.filter
	_redraw(viewport)


## Procedural drawings cache their draw lists; redraw them with the new edge setting.
static func _redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): _redraw(child)
