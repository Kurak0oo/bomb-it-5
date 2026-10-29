extends Node2D
## Everything around the visible map on the replica page: the side areas and any screen
## extension beyond the 16:9 page (ReplicaLayout.MAP is left open). Drawn above the board so
## the board's outer ring columns are cropped to half a cell.

const ReplicaLayout = preload("res://scripts/replica_layout.gd")
## Plain extension per stage set when no original background is available.
const PLAIN := {&"birthday_party": Color("6d4a3a"), &"candy_factory": Color("4f7a3e"), &"cinema": Color("3b1f3c"),
	&"zoo": Color("4f6b33"), &"luxury_stores": Color("6b5236"), &"magic_library": Color("3e2a1f")}
## Reaches past any screen extension; the page never scales below 1/4.
const REACH := 4000.0

var stage_set: StringName = &"cinema"
var skin: RefCounted


func set_stage(set_id: StringName) -> void:
	if set_id == stage_set: return
	stage_set = set_id
	queue_redraw()


## The areas this layer covers: everything but the visible map.
static func areas() -> Array[Rect2]:
	var map := ReplicaLayout.MAP
	return [Rect2(-REACH, -REACH, REACH + map.position.x, REACH * 2 + 720),
		Rect2(map.end.x, -REACH, REACH, REACH * 2 + 720),
		Rect2(map.position.x, -REACH, map.size.x, REACH),
		Rect2(map.position.x, map.end.y, map.size.x, REACH)]


func _draw() -> void:
	var color: Color = PLAIN.get(stage_set, PLAIN[&"cinema"])
	for area in areas():
		draw_rect(area, color)
	# The board's edge reads as a frame between map and scenery.
	draw_line(ReplicaLayout.MAP.position, Vector2(ReplicaLayout.MAP.position.x, 720), color.darkened(0.4), 4)
	draw_line(Vector2(ReplicaLayout.MAP.end.x, 0), ReplicaLayout.MAP.end, color.darkened(0.4), 4)
