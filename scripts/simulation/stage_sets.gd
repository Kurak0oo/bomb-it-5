extends RefCounted
## The six edition 5 stage sets (`GameStage`, `AbstractGameMode.initMap`, map-data classes).
## A set is offered once every special tile in its layouts is ported (#58, #63-#66).

## Source `UIManager.gamePlay` rotation order.
const ORDER: Array[StringName] = [&"birthday_party", &"candy_factory", &"cinema", &"zoo",
	&"luxury_stores", &"magic_library"]
const SETS := {
	&"birthday_party": {"title": "BIRTHDAY PARTY", "prefix": "BirthdayParty", "vehicles": [&"horse", &"moto"], "features": [&"toy_hand"]},
	&"candy_factory": {"title": "CANDY FACTORY", "prefix": "CandyFactory", "vehicles": [&"moto", &"car"], "features": [&"belt"]},
	&"cinema": {"title": "CINEMA", "prefix": "Cinema", "vehicles": [&"moto", &"car"], "features": [&"portal"]},
	&"zoo": {"title": "ZOO", "prefix": "Zoo", "vehicles": [&"horse", &"dragon"], "features": [&"crocodile"]},
	&"luxury_stores": {"title": "LUXURY SHOP", "prefix": "LuxuryStores", "vehicles": [&"car"], "features": []},
	&"magic_library": {"title": "MAGIC LIBRARY", "prefix": "MagicLibrary", "vehicles": [&"horse", &"moto"], "features": [&"spellbook"]},
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
