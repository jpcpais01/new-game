class_name PrismRng
extends RefCounted
## Deterministic, platform-independent PRNG (xoshiro128**).
##
## Every value lives in the unsigned 32-bit range and every multiplication is
## split so it never overflows a 64-bit int. The same seed gives the same
## sequence on every device, engine version and build, which is what makes
## replays, resumable runs, daily challenges and future online play possible.

const MASK32 := 0xFFFFFFFF

var _s0: int
var _s1: int
var _s2: int
var _s3: int


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	# Expand the (up to 64-bit) seed into four well-mixed 32-bit words.
	var lo := seed_value & MASK32
	var hi := (seed_value >> 32) & MASK32
	var x := mix32(lo ^ 0x9E3779B9)
	_s0 = mix32(x ^ hi)
	_s1 = mix32(_s0 ^ 0x85EBCA6B)
	_s2 = mix32(_s1 ^ lo ^ 0xC2B2AE35)
	_s3 = mix32(_s2 ^ hi ^ 0x27D4EB2F)
	if (_s0 | _s1 | _s2 | _s3) == 0:
		_s0 = 1


func get_state() -> Array:
	return [_s0, _s1, _s2, _s3]


func set_state(state: Array) -> void:
	_s0 = int(state[0]) & MASK32
	_s1 = int(state[1]) & MASK32
	_s2 = int(state[2]) & MASK32
	_s3 = int(state[3]) & MASK32


## Next raw unsigned 32-bit value.
func next_u32() -> int:
	var result := mul32(_rotl(mul32(_s1, 5), 7), 9)
	var t := (_s1 << 9) & MASK32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Uniform integer in [0, n). Unbiased (rejection sampling).
func next_int(n: int) -> int:
	if n <= 1:
		return 0
	var limit := (MASK32 + 1) - ((MASK32 + 1) % n)
	var v := next_u32()
	while v >= limit:
		v = next_u32()
	return v % n


## Uniform integer in [lo, hi] (inclusive).
func range_int(lo: int, hi: int) -> int:
	return lo + next_int(hi - lo + 1)


## True with probability percent / 100 (integer maths only).
func chance(percent: int) -> bool:
	return next_int(100) < percent


## Index picked from a list of non-negative integer weights.
func pick_weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll := next_int(total)
	for i in weights.size():
		roll -= int(weights[i])
		if roll < 0:
			return i
	return weights.size() - 1


## Fisher-Yates shuffle, in place.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & MASK32


## (a * b) mod 2^32 without ever overflowing 64-bit ints.
static func mul32(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK32


## murmur3 finaliser: a strong 32-bit integer hash.
static func mix32(h: int) -> int:
	h &= MASK32
	h ^= h >> 16
	h = mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h


## FNV-1a over the UTF-8 bytes of a string. Stable across engine versions,
## unlike String.hash().
static func hash_string(text: String) -> int:
	var h := 0x811C9DC5
	for b in text.to_utf8_buffer():
		h ^= b
		h = mul32(h, 0x01000193)
	return h
