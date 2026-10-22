extends RefCounted
## Builds a round's stage-set map features from board data (`features`: cell -> {kind, detail}).
## Each feature advances in the engine-handler phase: after bomb fuses, blasts and
## weapons, before robot movement (`GameEngine.as` loop; handlers registered at map build).

const Belt = preload("res://scripts/simulation/features/belt.gd")
const ToyHand = preload("res://scripts/simulation/features/toy_hand.gd")
const Crocodile = preload("res://scripts/simulation/features/crocodile.gd")
const Spellbook = preload("res://scripts/simulation/features/spellbook.gd")
## Tiles a robot can walk on besides floor and portal; blasts pass through them too.
const WALKABLE: Array[StringName] = [&"belt", &"crocodile"]


static func create(features: Dictionary, mode: RefCounted, center: Variant, skin: StringName) -> Array:
	var result: Array = []
	var belts := {}
	for cell in features:
		var entry: Dictionary = features[cell]
		match StringName(entry.kind):
			&"belt": belts[cell] = int(entry.detail)
			&"toy_hand": result.append(ToyHand.new(cell, String(entry.detail)))
			&"crocodile": result.append(Crocodile.new(cell))
	# The candy machine and the spellbook sit on the center building (`centerProp`).
	if center != null and skin == &"candy_factory": result.append(Belt.new(belts, center, mode))
	if center != null and skin == &"magic_library": result.append(Spellbook.new(center, mode))
	return result
