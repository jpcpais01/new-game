class_name GlowRng
extends RefCounted
## xoshiro128** with 32-bit masked integer maths, so every platform produces
## the same stream. The only randomness the simulation is allowed to use.

const MASK := 0xFFFFFFFF

var _s0 := 0
var _s1 := 0
var _s2 := 0
var _s3 := 0


func _init(seed_value: int = 1) -> void:
	var x := seed_value & MASK
	_s0 = _splitmix(x)
	x = (x + 0x9E3779B9) & MASK
	_s1 = _splitmix(x)
	x = (x + 0x9E3779B9) & MASK
	_s2 = _splitmix(x)
	x = (x + 0x9E3779B9) & MASK
	_s3 = _splitmix(x)
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1
	for i in 8:
		next_u32()


## 32x32 multiply keeping the low 32 bits, without overflowing int64.
static func mul32(a: int, b: int) -> int:
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK


static func _splitmix(x: int) -> int:
	var z := (x + 0x9E3779B9) & MASK
	z = mul32(z ^ (z >> 16), 0x85EBCA6B)
	z = mul32(z ^ (z >> 13), 0xC2B2AE35)
	return z ^ (z >> 16)


## Hash any 32-bit value; handy for deriving seeds.
static func mix32(x: int) -> int:
	return _splitmix(x & MASK)


func next_u32() -> int:
	var result := (_rotl((_s1 * 5) & MASK, 7) * 9) & MASK
	var t := (_s1 << 9) & MASK
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Integer in [0, n).
func range_i(n: int) -> int:
	if n <= 1:
		return 0
	return (next_u32() * n) >> 32


## Float in [0, 1).
func unit() -> float:
	return float(next_u32()) / 4294967296.0


func range_f(a: float, b: float) -> float:
	return a + (b - a) * unit()


func chance(p: float) -> bool:
	return unit() < p


func state() -> Array:
	return [_s0, _s1, _s2, _s3]
