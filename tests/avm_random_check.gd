extends SceneTree
## The `Math.random` port reproduces draws the reference player recorded after an
## explicit `seed N` (fixture: tests/fixtures/avm_random_draws.json, each entry citing
## its docs/evidence source). Draw n is the n-th AVM2 Math.random call since start.
## Raw draws match exactly; results allow 1e-12 because Godot's JSON parser rounds doubles.

const AvmRandom = preload("res://scripts/simulation/avm_random.gd")
const FIXTURE := "res://tests/fixtures/avm_random_draws.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var by_seed := {}
	for entry in fixture.draws:
		by_seed.get_or_add(int(entry.seed), []).append(entry)
	for seed in by_seed:
		var rng := AvmRandom.new(seed)
		var drawn := 0
		var entries: Array = by_seed[seed]
		entries.sort_custom(func(a, b): return a.draw < b.draw)
		for entry in entries:
			var raw := 0
			var value := 0.0
			while drawn < int(entry.draw):
				raw = rng.next_raw()
				drawn += 1
			value = float(raw) / 2147483648.0
			_check(raw == int(entry.raw), "seed %d draw %d raw %d, recorded %d" % [seed, entry.draw, raw, entry.raw])
			_check(absf(value - float(entry.result)) < 1e-12, "seed %d draw %d result %s, recorded %s" % [seed, entry.draw, value, entry.result])
	var probe := AvmRandom.new(7)
	for i in 1000:
		var v := probe.random()
		if v < 0.0 or v >= 1.0:
			_check(false, "random() out of [0, 1): %s" % v)
			break
	_check(true, "random() stays in [0, 1)")
	print("%s: %d avm random checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
