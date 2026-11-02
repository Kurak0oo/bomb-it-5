extends RefCounted
## Flash Player's `Math.random`, ported from avmplus `MathUtils.cpp` (`RandomFastNext`,
## `RandomPureHasher`, `MathUtils::random`), as the pinned Ruffle reproduces it in
## `core/src/avm_rng.rs` and `core/src/avm2/globals/math.rs`. With the reference
## player's `seed N`, the same seed yields the same draws (tests/avm_random_check.gd).
## GDScript ints are 64-bit; `_i32` wraps every step to Flash's signed 32-bit math.

const C1 := 1376312589
const C2 := 789221
const C3 := 15731
const K_RANDOM_PURE_MAX := 0x7FFFFFFF
const U_XOR_MASK := 0x48000000

var _u_value := 0


func _init(seed: int) -> void:
	assert(seed > 0 and seed <= 0xFFFFFFFF, "the original RNG needs a nonzero 32-bit seed")
	_u_value = seed


## `RandomFastNext`: one step of the 32-bit linear-feedback register.
func _random_fast_next() -> int:
	if _u_value & 1:
		_u_value = (_u_value >> 1) ^ U_XOR_MASK
	else:
		_u_value = _u_value >> 1
	return _i32(_u_value)


## `RandomPureHasher`. Each shift-xor step subtracts the *input's* arithmetic shift.
static func _random_pure_hasher(i_seed: int) -> int:
	i_seed = _i32((_i32(i_seed << 13) ^ i_seed) - (i_seed >> 21))
	var i_result := _i32(i_seed * i_seed)
	i_result = _i32(i_result * C3)
	i_result = _i32(i_result + C2)
	i_result = _i32(i_result * i_seed)
	i_result = _i32(i_result + C1)
	i_result &= K_RANDOM_PURE_MAX
	i_result = _i32(i_result + i_seed)
	return _i32((_i32(i_result << 13) ^ i_result) - (i_result >> 21))


## `GenerateRandomNumber`: the raw 31-bit draw.
func next_raw() -> int:
	var a_num := _random_fast_next()
	a_num = _random_pure_hasher(_i32(a_num * 71))
	return a_num & K_RANDOM_PURE_MAX


## AS3 `Math.random()`: raw / 2^31, so results lie in [0, 1).
func random() -> float:
	return float(next_raw()) / float(K_RANDOM_PURE_MAX + 1)


static func _i32(value: int) -> int:
	value &= 0xFFFFFFFF
	return value - 0x100000000 if value & 0x80000000 else value
