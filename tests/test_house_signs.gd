extends "res://tests/test_base.gd"
## Signs over houses: a face for the mood and an icon for each need the house lacks.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const HouseSigns = preload("res://scripts/view/house_signs.gd")
const HouseIcons = preload("res://scripts/view/house_icons.gd")


func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	return c


func _house(c: City, at: Vector2i, tier: int) -> Dictionary:
	c.place_building("common_house", at)
	var house := c.building_at(at)
	house["tier"] = tier
	var s: Dictionary = c.houses.state[house["id"]]
	s["residents"] = Houses.capacity(tier)
	s["food"] = Houses.pantry_size(tier)
	c.houses.clear_cache()
	return house


func test_moods() -> void:
	var c := _city()
	c.place_building("well", Vector2i(10, 6))
	c.place_building("common_house", Vector2i(30, 6))
	check_eq(c.houses.mood(c.building_at(Vector2i(30, 6)))["mood"], "", "a vacant lot has no mood")
	var hut := _house(c, Vector2i(12, 6), 1)
	check_eq(c.houses.mood(hut), {"mood": "neutral", "missing": ["seonangdang"] as Array[String]},
		"a hut with all it needs wants a shrine for the next tier")
	var dry := _house(c, Vector2i(20, 6), 1)
	check_eq(c.houses.mood(dry), {"mood": "sad", "missing": ["water"] as Array[String]}, "no well near: sad")
	var giwa := _house(c, Vector2i(8, 6), 3)
	var s: Dictionary = c.houses.state[giwa["id"]]
	s["visits"] = {"seonangdang": c.clock.tick}
	s["jang"] = 100
	s["jars_until"] = c.clock.tick + 1000
	check_eq(c.houses.mood(giwa)["mood"], "happy", "a Tiled House with everything is happy")


func test_signs_follow_the_mode() -> void:
	var c := _city()
	c.place_building("well", Vector2i(10, 6))
	_house(c, Vector2i(12, 6), 1) # neutral: one face, one icon (shrine)
	_house(c, Vector2i(20, 6), 1) # sad: one face, two icons (water, shrine is not its tier) -> face + water
	var v := HouseSigns.new()
	v.setup(c)
	var icons := v.signs().map(func(s: Dictionary) -> int: return int(s["icon"]))
	check_eq(icons.size(), 4, "two faces and their missing needs")
	check(icons.has(HouseIcons.INDEX["sad"]) and icons.has(HouseIcons.INDEX["water"]), "a sad face and a drop")
	check(icons.has(HouseIcons.INDEX["neutral"]) and icons.has(HouseIcons.INDEX["seonangdang"]), "a plain face and a shrine")
	check_eq(v.next_mode(), "all", "H: every house")
	check_eq(v.next_mode(), "off", "H again: off")
	check_eq(v.signs().size(), 0, "nothing drawn")
	check_eq(v.next_mode(), "problems", "and back to problems only")
	v.free()


func test_placeholder_icons_are_drawn() -> void:
	var img := HouseIcons.placeholder_image()
	check_eq(img.get_size(), Vector2i(256, 256), "a 4 x 4 atlas of 64 px icons")
	var happy := img.get_pixel(32, 50) # lower cheek of the happy face
	check(happy.is_equal_approx(HouseIcons.MOOD_COLORS["happy"]), "the happy face is green")
	var corner := img.get_pixel(1, 1)
	check_eq(corner.a, 0.0, "outside the round tag is see-through")
