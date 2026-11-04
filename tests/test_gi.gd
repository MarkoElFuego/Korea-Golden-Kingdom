extends "res://tests/test_base.gd"
## Gi, the life force of the land (phase 8): from the mountain behind, the water in front and
## the ridges on both sides; raised and lowered by buildings; good fortune for houses on high
## Gi, and no Tiled House where it is too low.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const OverlayView = preload("res://scripts/view/overlay_view.gd")


## A small pungsu valley: mountains along the north, forest ridges 12 tiles either side of
## x = 20 (with a pass at y = 10), a river across the south, grass between, and a street
## along y = 10.
func _valley() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 40)
	c.grid.terrain.fill(Terrain.GRASS)
	for y in 40:
		for x in 40:
			var t := Terrain.GRASS
			if y < 3:
				t = Terrain.MOUNTAIN
			elif (x == 8 or x == 32) and y != 10: # a pass for the street
				t = Terrain.FOREST
			elif y == 30:
				t = Terrain.RIVER
			c.grid.set_terrain(Vector2i(x, y), t)
	c.treasury = 100000
	c.labor.extra_workers = 1000
	c.set_entrance(Vector2i(9, 10))
	c.build_road(Vector2i(9, 10), Vector2i(39, 10))
	return c


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


func test_gi_from_the_land() -> void:
	var c := _valley()
	# Right below the mountain (1 step), between both ridges, far from the river.
	var below := Balance.GI_BASE + Balance.GI_MOUNTAIN_BONUS * (1.0 - 1.0 / Balance.GI_MOUNTAIN_REACH) + Balance.GI_ENCLOSED_BONUS
	check_eq(c.gi.at(Vector2i(20, 3)), roundi(below), "below the mountain, guarded by both ridges")
	check(c.gi.at(Vector2i(20, 3)) > c.gi.at(Vector2i(20, 20)), "more below the mountain than out in the valley")
	check(c.gi.at(Vector2i(20, 29)) > c.gi.at(Vector2i(20, 23)), "more by the river than away from it")
	check(c.gi.at(Vector2i(20, 23)) > c.gi.at(Vector2i(37, 23)), "more between the ridges than outside them")
	check_eq(c.gi.at(Vector2i(37, 23)), Balance.GI_BASE, "open land, far from mountain and river: the base")


func test_buildings_raise_and_lower_gi() -> void:
	var c := _valley()
	var before := c.gi.at(Vector2i(14, 13))
	c.place_building("seonangdang", Vector2i(14, 11))
	check_eq(c.gi.at(Vector2i(14, 13)), before + 10, "a Village Shrine raises it")
	c.grid.set_terrain(Vector2i(24, 11), Terrain.ROCKY_HILL)
	c.grid.set_terrain(Vector2i(25, 11), Terrain.ROCKY_HILL)
	c.grid.set_terrain(Vector2i(24, 12), Terrain.ROCKY_HILL)
	c.grid.set_terrain(Vector2i(25, 12), Terrain.ROCKY_HILL)
	var land := c.gi.at(Vector2i(26, 14))
	check_eq(c.place_building("clay_pit", Vector2i(24, 11)), "", "a Clay Pit")
	check_eq(c.gi.at(Vector2i(26, 14)), land - 15, "digging lowers it")
	c.demolish(Vector2i(24, 11), Vector2i(24, 11))
	check_eq(c.gi.at(Vector2i(26, 14)), land, "and it comes back when the pit is gone")


## A Thatched House with everything a Tiled House needs except, maybe, Gi.
func _ready_house(c: City, at: Vector2i) -> int:
	c.place_building("common_house", at)
	var id: int = c.building_at(at)["id"]
	c.buildings.get_instance(id)["tier"] = 2
	var s: Dictionary = c.houses.state[id]
	s["residents"] = Houses.capacity(2)
	s["food"] = Houses.pantry_size(2) * 4
	s["jang"] = Houses.pantry_size(2) * 4
	s["jars_until"] = 100000
	s["visits"] = {"seonangdang": 0}
	c.place_building("well", at + Vector2i(2, 0))
	c.houses.clear_cache()
	return id


func test_low_gi_keeps_a_house_from_becoming_a_tiled_house() -> void:
	var c := _valley()
	var low := _ready_house(c, Vector2i(37, 11)) # outside the ridges: base Gi only
	for x in [34, 38]:
		for y in [14]:
			c.grid.set_terrain(Vector2i(x, y), Terrain.ROCKY_HILL)
			c.grid.set_terrain(Vector2i(x + 1, y), Terrain.ROCKY_HILL)
			c.grid.set_terrain(Vector2i(x, y + 1), Terrain.ROCKY_HILL)
			c.grid.set_terrain(Vector2i(x + 1, y + 1), Terrain.ROCKY_HILL)
			c.place_building("clay_pit", Vector2i(x, y))
	var house := c.buildings.get_instance(low)
	check(c.houses.gi(house) < Balance.GI_LOW, "two clay pits drag it down (%d)" % c.houses.gi(house))
	_days(c, 1)
	check_eq(house["tier"], 2, "no Tiled House here")
	check(c.houses.mood(house)["missing"].has("gi"), "the sign over it shows Gi")
	var good := _ready_house(c, Vector2i(20, 11))
	_days(c, 1)
	check_eq(c.buildings.get_instance(good)["tier"], 3, "the same house on good land rises")


func test_high_gi_holds_a_house_longer() -> void:
	var c := _valley()
	c.place_building("common_house", Vector2i(20, 4)) # right below the mountain
	var id: int = c.building_at(Vector2i(20, 4))["id"]
	var house := c.buildings.get_instance(id)
	house["tier"] = 2
	c.houses.state[id]["residents"] = Houses.capacity(2)
	check(c.houses.gi(house) >= Balance.GI_HIGH, "high Gi (%d)" % c.houses.gi(house))
	_days(c, Balance.HOUSE_DOWN_DAYS + 1)
	check_eq(house["tier"], 2, "still standing after the usual days")
	_days(c, Balance.HOUSE_DOWN_DAYS_HIGH_GI - Balance.HOUSE_DOWN_DAYS)
	check_eq(house["tier"], 1, "good fortune runs out after 20 days")


func test_gi_is_the_same_after_loading() -> void:
	var a := _valley()
	a.place_building("seonangdang", Vector2i(14, 11))
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	check(b.gi.values() == a.gi.values(), "worked out again from the land and buildings")


func test_overlay_colors() -> void:
	check(OverlayView.gi_color(Balance.GI_MYEONGDANG).is_equal_approx(OverlayView.GI_GOLD), "Myeongdang in gold")
	check(OverlayView.gi_color(10).r > OverlayView.gi_color(10).g, "low Gi is red")
	check(OverlayView.gi_color(72).g > OverlayView.gi_color(72).r, "high Gi is green")
