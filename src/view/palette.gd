class_name PrismPalette
extends RefCounted
## Colours and shared look constants for the whole game.

const BG_TOP := Color("0b0a1d")
const BG_BOTTOM := Color("1b1140")
const PANEL := Color(0.09, 0.08, 0.2, 0.86)
const PANEL_EDGE := Color(0.55, 0.5, 1.0, 0.22)
const SLOT := Color(1, 1, 1, 0.045)
const SLOT_EDGE := Color(1, 1, 1, 0.07)
const TEXT := Color("f4f1ff")
const TEXT_DIM := Color(0.78, 0.75, 0.95, 0.62)
const GOLD := Color("ffd166")
const ACCENT := Color("8f7bff")

# Gem colours, index 1..6 (0 is unused / empty).
const GEMS := [
	Color(0, 0, 0, 0),
	Color("ff4d6d"),  # ruby
	Color("ffb238"),  # amber
	Color("3ee38a"),  # emerald
	Color("35cfff"),  # topaz blue
	Color("9c6bff"),  # amethyst
	Color("ff6bd5"),  # rose
]

const GEM_NAMES := ["", "Ruby", "Amber", "Emerald", "Topaz", "Amethyst", "Rose"]


static func gem(i: int) -> Color:
	return GEMS[clampi(i, 0, GEMS.size() - 1)]


## A smooth rainbow sampled by t in [0, 1).
static func rainbow(t: float, sat := 0.75, val := 1.0) -> Color:
	return Color.from_hsv(fposmod(t, 1.0), sat, val)
