extends RefCounted
## The renderer and workbench share one manifest; defaults remain native drawings.

signal changed
const Catalog = preload("res://scripts/art/catalog.gd")
const ACTIVE := "res://assets/skins/active.json"
const IMPORTS := "res://assets/skins/imports/"
const DRAFT := "user://art_workbench_draft.json"
var _records: Dictionary = {}
var _history: Array[Dictionary] = []
var _textures: Dictionary = {}


func _init(saved: bool = true) -> void:
	if saved: _records = _read(ACTIVE)


func records() -> Dictionary:
	return _records.duplicate(true)


func entry(id: String) -> Dictionary:
	return _records.get(id, {}).duplicate(true)


func restore_draft() -> void:
	if FileAccess.file_exists(DRAFT):
		_records = _read(DRAFT)
		changed.emit()


func import_image(id: String, path: String) -> String:
	if Catalog.find(id).is_empty(): return "Unknown component."
	var resolved := ProjectSettings.globalize_path(path).replace("\\", "/")
	var research := ProjectSettings.globalize_path("res://.scratch/edition-5-research").replace("\\", "/")
	var evidence := ProjectSettings.globalize_path("res://docs/evidence").replace("\\", "/")
	if resolved.begins_with(research + "/") or resolved.begins_with(evidence + "/"):
		return "Original references are view-only. Import your own replacement artwork."
	if path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp"]:
		return "Choose a PNG, JPG or WebP image."
	var image := Image.new()
	if image.load(path) != OK or image.is_empty(): return "This image could not be opened."
	var folder := ProjectSettings.globalize_path(IMPORTS)
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return "Could not create the asset folder."
	var target := IMPORTS + FileAccess.get_sha256(path) + "." + path.get_extension().to_lower()
	if not FileAccess.file_exists(target):
		if DirAccess.copy_absolute(resolved, ProjectSettings.globalize_path(target)) != OK:
			return "The image could not be copied into this project."
	_remember()
	_records[id] = {"path": target, "label": path.get_file(), "columns": 1, "rows": 1,
		"fps": 8.0, "scale": 1.0, "x": 0.0, "y": 0.0, "tint": "ffffffff"}
	_notify()
	return ""


func configure(id: String, values: Dictionary) -> void:
	if not _records.has(id): return
	var updated: Dictionary = _records[id].duplicate(true)
	for key in values:
		if key in ["columns", "rows", "fps", "scale", "x", "y", "tint"]: updated[key] = values[key]
	updated.columns = clampi(int(updated.columns), 1, 64)
	updated.rows = 4 if int(updated.rows) == 4 else 1
	updated.fps = clampf(float(updated.fps), 0, 35)
	updated.scale = clampf(float(updated.scale), 0.1, 4)
	updated.x = clampf(float(updated.x), -128, 128)
	updated.y = clampf(float(updated.y), -128, 128)
	if updated == _records[id]: return
	_remember()
	_records[id] = updated
	_notify()


func reset_slot(id: String) -> void:
	if not _records.has(id): return
	_remember()
	_records.erase(id)
	_notify()


func undo() -> bool:
	if _history.is_empty(): return false
	_records = _history.pop_back()
	_notify()
	return true


func apply() -> String:
	for id in _records:
		if Catalog.find(id).is_empty() or texture(id) == null: return "Missing or invalid image for " + id
	var error := _write(ACTIVE)
	return "" if error == OK else "Could not save the game manifest (error %d)." % error


func texture(id: String) -> Texture2D:
	var record := entry(id)
	var path: String = record.get("path", "")
	if not path.begins_with(IMPORTS): return null
	if _textures.has(path): return _textures[path]
	if not FileAccess.file_exists(path): return null
	var image := Image.new()
	if image.load(path) != OK or image.is_empty(): return null
	var loaded := ImageTexture.create_from_image(image)
	_textures[path] = loaded
	return loaded


func button_texture(id: String) -> Texture2D:
	var image := texture(id)
	if image == null: return null
	var record := entry(id)
	var first := AtlasTexture.new()
	first.atlas = image
	first.region = Rect2(Vector2.ZERO, Vector2(image.get_size()) / Vector2(record.get("columns", 1), record.get("rows", 1)))
	return first


func draw(canvas: CanvasItem, id: String, rect: Rect2, tick: float = 0,
		facing: Vector2 = Vector2.DOWN, progress: float = -1.0, modulation: Color = Color.WHITE) -> bool:
	var image := texture(id)
	if image == null: return false
	var record := entry(id)
	var columns: int = record.get("columns", 1)
	var rows: int = record.get("rows", 1)
	var frame := mini(columns - 1, floori(clampf(progress, 0, 1) * columns)) if progress >= 0 else posmod(floori(tick * float(record.get("fps", 8)) / 35.0), columns)
	var row := 0
	if rows == 4: row = 0 if facing.y > 0 else 2 if facing.y < 0 else 1 if facing.x > 0 else 3
	var pitch := Vector2(image.get_size()) / Vector2(columns, rows)
	var bounds := rect.size * float(record.get("scale", 1))
	var size := pitch * minf(bounds.x / pitch.x, bounds.y / pitch.y)
	if id in ["ui.background", "ui.frame", "ui.board_frame", "board.floor_even", "board.floor_odd"] or id.begins_with("ui.button_"): size = bounds
	var offset := Vector2(float(record.get("x", 0)), float(record.get("y", 0)))
	canvas.draw_texture_rect_region(image, Rect2(rect.get_center() - size / 2 + offset, size),
		Rect2(Vector2(frame, row) * pitch, pitch), Color(record.get("tint", "ffffffff")) * modulation)
	return true


func _remember() -> void:
	_history.append(_records.duplicate(true))
	if _history.size() > 100: _history.pop_front()


func _notify() -> void:
	_write(DRAFT)
	changed.emit()


func _write(path: String) -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return error
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "overrides": _records}, "\t"))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), absolute)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version") != 1: return {}
	var stored: Variant = parsed.get("overrides", {})
	if not stored is Dictionary: return {}
	var valid := {}
	for id in stored:
		if not id is String or Catalog.find(id).is_empty() or not stored[id] is Dictionary: continue
		var record: Dictionary = stored[id].duplicate(true)
		if not record.get("path", "") is String or not record.get("path", "").begins_with(IMPORTS): continue
		record.columns = clampi(int(record.get("columns", 1)), 1, 64)
		record.rows = 4 if int(record.get("rows", 1)) == 4 else 1
		record.fps = clampf(float(record.get("fps", 8)), 0, 35)
		record.scale = clampf(float(record.get("scale", 1)), 0.1, 4)
		record.x = clampf(float(record.get("x", 0)), -128, 128)
		record.y = clampf(float(record.get("y", 0)), -128, 128)
		record.tint = record.get("tint", "ffffffff") if record.get("tint", "ffffffff") is String else "ffffffff"
		valid[id] = record
	return valid
