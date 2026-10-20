extends "res://scripts/game_view.gd"
## Isolated visual samples only; the Play Preview button uses the real game.

const Catalog = preload("res://scripts/art/catalog.gd")
var component_id := "effect.bomb"
var facing := Vector2.DOWN
var sample_tick := 12.0
var playing := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	state = {"tick": 12, "attacks": [], "actors": {}, "session": {"game_over": false}}
	for id in IDS:
		state.actors[id] = {"position": Vector2.ZERO, "cell": Vector2i.ZERO, "alive": true,
			"facing": Vector2.DOWN, "velocity": Vector2.ZERO, "vehicle": &"", "shield": 0,
			"protected_until": 0, "invincible_until": 0, "blink_until": 0, "transit_until": 0,
			"weapon": &"", "ammo": 2, "capacity": 1, "power": 1, "speed": 1.6,
			"score": 0, "lives": 3, "death_frame": 12}
	if not skin.changed.is_connected(queue_redraw): skin.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if playing: sample_tick += delta * 35
	var bounds := focus_rect()
	var available := get_viewport_rect().size - Vector2.ONE * 24
	var zoom := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	scale = Vector2.ONE * clampf(zoom, 0.02, 6)
	position = get_viewport_rect().size / 2 - bounds.get_center() * scale
	state.tick = floori(sample_tick)
	queue_redraw()


func focus_rect() -> Rect2:
	var definition := Catalog.find(component_id)
	var size: Vector2 = definition.get("size", Vector2(44, 44))
	if component_id == "board.marquee": return Rect2(ORIGIN + Vector2(7, 6) * PITCH, Vector2.ONE * 108)
	var tiles := {"board.seat": Vector2(2, 2), "board.spotlight": Vector2(2, 4),
		"board.clapper": Vector2(2, 3), "board.popcorn": Vector2(2, 2),
		"board.portal_green": Vector2(8, 1), "board.portal_purple": Vector2(4, 7)}
	if tiles.has(component_id): return Rect2(ORIGIN + tiles[component_id] * PITCH, Vector2.ONE * PITCH)
	if component_id.ends_with(".death"): return Rect2(ORIGIN + Vector2(-10, -36), Vector2(56, 80))
	if component_id.begins_with("actor.") and not component_id.ends_with("portrait"):
		return Rect2(ORIGIN + Vector2(-5, -12), Vector2(46, 52))
	return Rect2(ORIGIN + Vector2.ONE * 18 - size / 2, size)


func _draw() -> void:
	if state.is_empty(): return
	var bounds := focus_rect()
	var definition := Catalog.find(component_id)
	var size: Vector2 = definition.get("size", Vector2(44, 44))
	var target := Rect2(ORIGIN + Vector2.ONE * 18 - size / 2, size)
	if component_id.begins_with("board."): target = bounds
	if component_id.begins_with("actor.") and not component_id.ends_with("portrait"):
		target.position.y -= 2
		if component_id.ends_with("death"): target.position.y -= sin(posmod(floori(sample_tick), 60) / 60.0 * PI) * 25
	if skin.draw(self, component_id, target, sample_tick, facing, 0 if component_id.begins_with("ui.button_") else -1): return
	var group := component_id.get_slice(".", 0)
	var kind := component_id.get_slice(".", 1)
	var at := ORIGIN + Vector2.ONE * 18
	match group:
		"board":
			match kind:
				"marquee":
					_marquee()
				"floor_even", "floor_odd":
					draw_rect(bounds, Color("5c3555") if kind == "floor_even" else Color("53304d"))
				"wall": _tile(Vector2i.ZERO, &"solid")
				"seat": _sample_tile(Vector2i(2, 2), &"solid")
				"spotlight": _sample_tile(Vector2i(2, 4), &"solid")
				"clapper": _sample_tile(Vector2i(2, 3), &"soft")
				"popcorn": _sample_tile(Vector2i(2, 2), &"soft")
				"portal_green": _sample_tile(Vector2i(8, 1), &"portal")
				"portal_purple": _sample_tile(Vector2i(4, 7), &"portal")
		"actor":
			var index: int = IDS.find(StringName(kind))
			var pose := component_id.get_slice(".", 2)
			if pose == "portrait":
				draw_circle(at, 19, COLORS[index].darkened(0.1))
				_label(at + Vector2(-13, 6), "P1" if index == 0 else "AI", 17, Color("173649"))
			else:
				var actor: Dictionary = state.actors[IDS[index]].duplicate(true)
				actor.facing = facing
				actor.alive = pose != "death"
				actor.velocity = Vector2.RIGHT if pose == "walk" else Vector2.ZERO
				actor.death_frame = posmod(floori(sample_tick), 60)
				_actor(actor, index)
		"item", "held":
			draw_circle(at, 13, Color("d1fff0"))
			draw_arc(at, 13, 0, TAU, 28, Color("60b4a4"), 2, true)
			var caption: String = ITEM_NAMES.get(StringName(kind), "?")
			_label(at + Vector2(-caption.length() * 4.0, 5), caption, 13, Color("173c40"))
		"attack":
			_attack({"kind": StringName(kind), "cell": Vector2i.ZERO, "direction": Vector2i(facing),
				"frame": posmod(floori(sample_tick), 24), "fired": true, "cells": [Vector2i.ZERO],
				"started": 0, "ready": 11})
		"projectile":
			draw_line(at - facing * 15, at, Color("ee9958"), 6, true)
			draw_circle(at, 6 if kind == "triple" else 9, Color("ffdf8d"))
		"effect":
			match kind:
				"bomb", "mine": _bomb(at, kind == "mine")
				"flame":
					draw_circle(at, 17, Color("ed7040"))
					draw_circle(at + Vector2(0, -2), 12, Color("ffd473"))
					draw_circle(at + Vector2(-2, -4), 6, Color("fff1b6"))
				"car", "moto", "car_recovery", "moto_recovery":
					_box(Rect2(at + Vector2(-16, 1), Vector2(32, 17)), Color("d77f68") if kind.ends_with("recovery") else Color("3c8890"), Color("b9dfca"), 6)
					draw_circle(at + Vector2(-10, 15), 5, Color("203347"))
					draw_circle(at + Vector2(10, 15), 5, Color("203347"))
				_: draw_arc(at, 19, sample_tick * 0.1 if kind == "transit" else 0, TAU, 32,
					Color("ffd778") if kind.begins_with("invincible") else Color("d2eeb1"), 2, true)
		"control":
			var radius := bounds.size.x / 2 - 3
			draw_circle(at, radius, Color(0.6, 0.8, 1, 0.18))
			draw_arc(at, radius, 0, TAU, 64, Color("8cceea"), 2, true)
			if kind.begins_with("action"):
				_label(at + Vector2(-28, 7), "BOMB", 20, Color("ffdda0"))
		"ui":
			_box(bounds, Color("234e62") if kind == "roster" else Color("214c60"), Color("7fb6b7"), 9)
			if kind.begins_with("button"): _label(at + Vector2(-34, 6), "BUTTON", 18)
		"outcome":
			_label(at + Vector2(-28, 7), "WIN" if kind == "won" else "END", 18, Color("ffd989"))


func _sample_tile(cell: Vector2i, tile: StringName) -> void:
	_tile(cell, tile)
