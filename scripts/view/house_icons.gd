extends RefCounted
## Icons for the signs over houses: a face for the mood and one icon per missing need, all in
## one atlas of 4 x 4 cells (docs/art-bible.md, "Ikonice kuća"). The owner's
## art/ui/house_icons.png is used when it exists; until then this draws placeholder icons
## from simple shapes, on round hanji-paper tags.

const ATLAS_PATH := "res://art/ui/house_icons.png"
const CELL := 64 # pixels
const CELLS := 4 # per row and column

## Atlas cell of every icon (row by row from the top left).
const INDEX := {
	"happy": 0, "neutral": 1, "sad": 2,
	"road": 3, "water": 4, "food": 5, "seonangdang": 6, "jang": 7, "onggi_jars": 8,
}

const PAPER := Color("#ece6d8")
const INK := Color("#3a2e22")
const MOOD_COLORS := {"happy": Color("#55803a"), "neutral": Color("#d9a83a"), "sad": Color("#b8473a")}


static func atlas() -> Texture2D:
	if ResourceLoader.exists(ATLAS_PATH):
		var owner_atlas := load(ATLAS_PATH) as Texture2D
		if owner_atlas:
			return owner_atlas
	return ImageTexture.create_from_image(placeholder_image())


static func placeholder_image() -> Image:
	var img := Image.create(CELL * CELLS, CELL * CELLS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for mood: String in MOOD_COLORS:
		var o := _origin(mood)
		_disk(img, o + Vector2(32, 32), 29, INK)
		_disk(img, o + Vector2(32, 32), 26, MOOD_COLORS[mood])
		_disk(img, o + Vector2(23, 26), 4, INK)
		_disk(img, o + Vector2(41, 26), 4, INK)
		_mouth(img, o, {"happy": 1.0, "neutral": 0.0, "sad": -1.0}[mood])
	for need: String in ["road", "water", "food", "seonangdang", "jang", "onggi_jars"]:
		var o := _origin(need)
		_disk(img, o + Vector2(32, 32), 29, INK)
		_disk(img, o + Vector2(32, 32), 26, PAPER)
		match need:
			"road": # a strip of packed earth with a dashed middle
				_rect(img, o + Vector2(12, 24), Vector2(40, 16), Color("#b9a27a"))
				for x in [16, 28, 40]:
					_rect(img, o + Vector2(x, 31), Vector2(8, 2), INK)
			"water": # a drop
				_disk(img, o + Vector2(32, 38), 11, Color("#3d7fb0"))
				_triangle(img, o + Vector2(32, 14), o + Vector2(22, 34), o + Vector2(42, 34), Color("#3d7fb0"))
			"food": # a bowl heaped with rice
				_disk(img, o + Vector2(32, 30), 12, Color("#f4efe2"))
				_rect(img, o + Vector2(16, 32), Vector2(32, 4), Color("#8a5c35"))
				_half_disk(img, o + Vector2(32, 36), 16, Color("#8a5c35"))
			"seonangdang": # a stone cairn with a red and a blue ribbon
				_disk(img, o + Vector2(32, 44), 12, Color("#8f8a80"))
				_disk(img, o + Vector2(32, 31), 9, Color("#a19c92"))
				_disk(img, o + Vector2(32, 21), 6, Color("#b5b0a6"))
				_rect(img, o + Vector2(42, 22), Vector2(4, 14), Color("#b8473a"))
				_rect(img, o + Vector2(18, 24), Vector2(4, 12), Color("#3d5a99"))
			"jang": # a squat crock of dark paste with a lid
				_rect(img, o + Vector2(20, 26), Vector2(24, 22), Color("#3e2616"))
				_disk(img, o + Vector2(32, 26), 12, Color("#5a3a22"))
				_rect(img, o + Vector2(22, 18), Vector2(20, 5), Color("#a07a55"))
			"onggi_jars": # a tall onggi jar
				_disk(img, o + Vector2(32, 36), 14, Color("#6b4a32"))
				_rect(img, o + Vector2(24, 14), Vector2(16, 12), Color("#6b4a32"))
				_rect(img, o + Vector2(22, 12), Vector2(20, 4), Color("#a07a55"))
	img.generate_mipmaps()
	return img


static func _origin(key: String) -> Vector2:
	var i: int = INDEX[key]
	@warning_ignore("integer_division")
	return Vector2((i % CELLS) * CELL, (i / CELLS) * CELL)


static func _disk(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _half_disk(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _rect(img: Image, pos: Vector2, size: Vector2, color: Color) -> void:
	img.fill_rect(Rect2i(Vector2i(pos), Vector2i(size)), color)


static func _triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var box := Rect2(a, Vector2.ZERO).expand(b).expand(c)
	for y in range(int(box.position.y), int(box.end.y) + 1):
		for x in range(int(box.position.x), int(box.end.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			if (d1 >= 0 and d2 >= 0 and d3 >= 0) or (d1 <= 0 and d2 <= 0 and d3 <= 0):
				img.set_pixel(x, y, color)


## A smile (1), a straight line (0) or a frown (-1).
static func _mouth(img: Image, o: Vector2, curve: float) -> void:
	for i in 21:
		var x := 22.0 + i
		var t := (x - 32.0) / 10.0
		var y := 42.0 + curve * (4.0 * (1.0 - t * t) - 2.0) # the middle dips for a smile
		img.fill_rect(Rect2i(int(o.x + x), int(o.y + y), 1, 3), INK)
