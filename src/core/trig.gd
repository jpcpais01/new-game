class_name Trig
extends RefCounted
## Deterministic trigonometry for the simulation. Angles are integers in
## [0, STEPS). The table is built with +, *, / and sqrt only (all exactly
## rounded in IEEE 754), so it is identical on every device, unlike the
## platform's sin/cos/atan2.

const STEPS := 1024
const MASK := STEPS - 1
const QUARTER := STEPS / 4
const HALF := STEPS / 2
const TAU_F := 6.283185307179586

static var _cos := PackedFloat64Array()
static var _sin := PackedFloat64Array()


static func _build() -> void:
	# Halve pi/2 eight times -> 2*pi/1024, via half-angle formulas.
	var c := 0.0
	var s := 1.0
	for i in 8:
		c = sqrt((1.0 + c) * 0.5)
		s = s / (2.0 * c)
	_cos.resize(STEPS)
	_sin.resize(STEPS)
	var x := 1.0
	var y := 0.0
	for k in QUARTER + 1:
		_cos[k] = x
		_sin[k] = y
		var nx := x * c - y * s
		y = x * s + y * c
		x = nx
	_cos[QUARTER] = 0.0
	_sin[QUARTER] = 1.0
	for k in range(1, QUARTER):
		# Second quadrant mirrors the first.
		_cos[HALF - k] = -_cos[k]
		_sin[HALF - k] = _sin[k]
	_cos[HALF] = -1.0
	_sin[HALF] = 0.0
	for k in range(1, HALF):
		_cos[HALF + k] = _cos[HALF - k]
		_sin[HALF + k] = -_sin[HALF - k]


static func cos_i(a: int) -> float:
	if _cos.is_empty():
		_build()
	return _cos[a & MASK]


static func sin_i(a: int) -> float:
	if _cos.is_empty():
		_build()
	return _sin[a & MASK]


## Angle index of the vector (x, y). Polynomial atan, max error ~0.3 steps.
static func angle_of(x: float, y: float) -> int:
	var ax := absf(x)
	var ay := absf(y)
	if ax == 0.0 and ay == 0.0:
		return 0
	var t := minf(ax, ay) / maxf(ax, ay)
	var a := t * (0.7853981633974483 + 0.273 * (1.0 - t))
	if ay > ax:
		a = 1.5707963267948966 - a
	if x < 0.0:
		a = 3.141592653589793 - a
	if y < 0.0:
		a = TAU_F - a
	return int(a * (float(STEPS) / TAU_F) + 0.5) & MASK


## Angle index -> radians, for views only.
static func to_rad(a: int) -> float:
	return float(a & MASK) * (TAU_F / float(STEPS))
