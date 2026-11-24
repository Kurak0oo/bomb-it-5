extends RefCounted
## The six edition 5 stage sets (`GameStage`, `AbstractGameMode.initMap`, map-data classes).
## A set is offered once every special tile in its layouts is ported (#58, #63-#66).

## Source `UIManager.gamePlay` rotation order.
const ORDER: Array[StringName] = [&"birthday_party", &"candy_factory", &"cinema", &"zoo",
	&"luxury_stores", &"magic_library"]
## `fixed_choices` and `soft_choices` are the art lists `<Set>MapData.init` draws two from each
## round (`_fixedArr`, `_unfixedArr`); see docs/evidence/edition-5-stage-tiles.md.
## `begin_num` and `fixed_prop_num` are each `<Set>MapData`'s `beginNum` and `fixedPropNum`:
## `MapMaster.createRow` draws a box from `_brick5` frame `beginNum - 1 + fixed choice`,
## `soft choice + beginNum + fixedPropNum - 1`, or `beginNum + 23` (wall and centre).
const SETS := {
	&"birthday_party": {"begin_num": 1, "fixed_prop_num": 4, "title": "BIRTHDAY PARTY", "prefix": "BirthdayParty", "vehicles": [&"horse", &"moto"], "features": [&"toy_hand"], "fixed_choices": [1, 2, 3], "soft_choices": [1, 2, 3, 4, 5, 6, 7, 8]},
	&"candy_factory": {"begin_num": 25, "fixed_prop_num": 4, "title": "CANDY FACTORY", "prefix": "CandyFactory", "vehicles": [&"moto", &"car"], "features": [&"belt"], "fixed_choices": [1, 2, 4], "soft_choices": [1, 2, 3, 4, 5, 6]},
	&"cinema": {"begin_num": 49, "fixed_prop_num": 4, "title": "CINEMA", "prefix": "Cinema", "vehicles": [&"moto", &"car"], "features": [&"portal"], "fixed_choices": [1, 3], "soft_choices": [1, 2, 3, 4]},
	&"zoo": {"begin_num": 73, "fixed_prop_num": 7, "title": "ZOO", "prefix": "Zoo", "vehicles": [&"horse", &"dragon"], "features": [&"crocodile"], "fixed_choices": [1, 5], "soft_choices": [1, 2, 3, 4]},
	&"luxury_stores": {"begin_num": 97, "fixed_prop_num": 4, "title": "LUXURY SHOP", "prefix": "LuxuryStores", "vehicles": [&"car"], "features": [], "fixed_choices": [1, 3], "soft_choices": [1, 2, 3, 4, 5, 6]},
	&"magic_library": {"begin_num": 121, "fixed_prop_num": 5, "title": "MAGIC LIBRARY", "prefix": "MagicLibrary", "vehicles": [&"horse", &"moto"], "features": [&"spellbook"], "fixed_choices": [1, 2, 4], "soft_choices": [1, 2, 3]},
}
## Features the round implements; a set needing anything else stays unavailable.
const SUPPORTED_FEATURES: Array[StringName] = [&"portal", &"belt", &"toy_hand", &"crocodile", &"spellbook"]
const SUPPORTED_VEHICLES: Array[StringName] = [&"moto", &"car", &"horse", &"dragon"]


static func available(set_id: StringName) -> bool:
	var entry: Dictionary = SETS[set_id]
	return entry.features.all(func(feature): return feature in SUPPORTED_FEATURES) \
		and entry.vehicles.all(func(vehicle): return vehicle in SUPPORTED_VEHICLES)


static func available_sets() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in ORDER:
		if available(id): result.append(id)
	return result


static func title(set_id: StringName) -> String:
	return SETS[set_id].title


static func vehicles(set_id: StringName) -> Array:
	return SETS[set_id].vehicles
