class_name Art
extends RefCounted
## Loads and caches every texture and font the views use.

static var _cache := {}


static func res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func tex(path: String) -> Texture2D:
	return res(path) as Texture2D


static func gem(color: int) -> Texture2D:
	return tex("res://assets/tiles/gem_%d.png" % clampi(color, 1, PrismPieces.COLORS))


static func white() -> Texture2D:
	return tex("res://assets/tiles/white.png")


static func ghost() -> Texture2D:
	return tex("res://assets/tiles/ghost.png")


static func slot() -> Texture2D:
	return tex("res://assets/tiles/slot.png")


static func glow() -> Texture2D:
	return tex("res://assets/tiles/glow.png")


static func spark() -> Texture2D:
	return tex("res://assets/tiles/spark.png")


static func ring() -> Texture2D:
	return tex("res://assets/tiles/ring.png")


static func beam() -> Texture2D:
	return tex("res://assets/tiles/beam.png")


static func icon(name: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % name)


static func font_bold() -> Font:
	return res("res://assets/fonts/Fredoka-Bold.ttf") as Font


static func font() -> Font:
	return res("res://assets/fonts/Fredoka-Medium.ttf") as Font
