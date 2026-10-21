extends RefCounted
## Board data entering the round: cells, spawns, portal pairs and skin (ADR 0007).
## The recorded practice instance and rolled layouts share this shape.

const SPAWNS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(15, 1), Vector2i(1, 13), Vector2i(15, 13)]


## Reads a recorded instance CSV (`x,y,tile,portal_pair`).
static func load_instance(path: String, skin: StringName = &"cinema") -> Dictionary:
	var cells: Dictionary = {}
	var pairs: Dictionary = {}
	var csv := FileAccess.open(path, FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 3:
			continue
		var cell := Vector2i(int(row[0]), int(row[1]))
		cells[cell] = StringName(row[2])
		if row.size() >= 4 and row[3] != "":
			pairs.get_or_add(row[3], []).append(cell)
	return make(cells, _link(pairs), skin)


static func make(cells: Dictionary, portals: Dictionary = {}, skin: StringName = &"cinema",
		features: Dictionary = {}, layout: String = "") -> Dictionary:
	var size := Vector2i.ZERO
	for cell in cells:
		size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
	return {"cells": cells, "size": size, "spawns": SPAWNS.duplicate(), "portals": portals,
		"skin": skin, "features": features, "layout": layout}


static func _link(pairs: Dictionary) -> Dictionary:
	var portals: Dictionary = {}
	for key in pairs:
		var ends: Array = pairs[key]
		if ends.size() == 2:
			portals[ends[0]] = ends[1]
			portals[ends[1]] = ends[0]
	return portals
