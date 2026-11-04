extends "res://tests/test_base.gd"
## The building window shows what a building reaches ("Show range"), what each of its
## walkers is doing, and frames it on the map while its walkers are marked.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const SelectionView = preload("res://scripts/view/selection_view.gd")
const WalkerView = preload("res://scripts/view/walker_view.gd")


func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.labor.extra_workers = 1000
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	return c


## A house with people already living in it.
func _house(c: City, at: Vector2i) -> int:
	c.place_building("common_house", at)
	var id: int = c.building_at(at)["id"]
	c.buildings.get_instance(id)["tier"] = 1
	c.houses.state[id]["residents"] = Houses.capacity(1)
	c.houses.state[id]["food"] = Houses.pantry_size(1)
	c.houses.clear_cache()
	return id


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


func test_a_well_shows_the_houses_it_waters() -> void:
	var c := _city()
	c.place_building("well", Vector2i(10, 6))
	var near := _house(c, Vector2i(12, 6))
	var far := _house(c, Vector2i(30, 6))
	var reach: Dictionary = c.range_of(c.building_at(Vector2i(10, 6)))
	check(reach["tiles"].has(Vector2i(13, 7)), "the well's tiles")
	check_eq(reach["houses"].get(near, false), true, "the house beside it is watered")
	check(not reach["houses"].has(far), "the far house is out of range")


func test_a_market_shows_which_houses_have_food() -> void:
	var c := _city()
	c.place_building("market", Vector2i(2, 6))
	var market: int = c.building_at(Vector2i(2, 6))["id"]
	var house := _house(c, Vector2i(8, 6))
	c.houses.state[house]["food"] = 0
	check_eq(c.range_of(c.buildings.get_instance(market))["houses"].get(house), false, "an empty pantry")
	c.economy.add(market, "rice", 8)
	_days(c, 6)
	check_eq(c.range_of(c.buildings.get_instance(market))["houses"].get(house), true, "the vendor has filled it")


func test_the_window_says_what_each_walker_does() -> void:
	var c := _city()
	c.place_building("market", Vector2i(2, 6))
	var market: int = c.building_at(Vector2i(2, 6))["id"]
	_house(c, Vector2i(8, 6))
	c.economy.add(market, "rice", 4)
	c.place_building("granary", Vector2i(20, 6))
	c.economy.add(c.building_at(Vector2i(20, 6))["id"], "rice", 10)
	_days(c, 1)
	var keys: Array = c.walkers_of(market).map(func(w: Dictionary) -> String: return w["key"])
	check(keys.has("WALKER_VENDOR_OUT"), "a vendor on the streets (%s)" % [keys])
	check(keys.has("WALKER_BUYER_FETCH"), "the buyer going for rice")
	c.place_building("storehouse", Vector2i(30, 6))
	c.economy.add(c.building_at(Vector2i(30, 6))["id"], "clay", 2)
	c.place_building("onggi_kiln", Vector2i(26, 6))
	_days(c, 1)
	var kiln: Array = c.walkers_of(c.building_at(Vector2i(26, 6))["id"])
	check_eq(kiln.size(), 1, "the kiln has one walker out")
	check_eq(kiln[0]["key"], "WALKER_FETCHER_FETCH", "its fetcher")
	check_eq(kiln[0]["args"], ["GOOD_CLAY"], "going for Clay")


func test_selection_frames_the_building_and_shows_its_range() -> void:
	var c := _city()
	c.place_building("well", Vector2i(10, 6))
	_house(c, Vector2i(12, 6))
	var house := _house(c, Vector2i(30, 6))
	var v := SelectionView.new()
	v.setup(c)
	v.select(c.building_at(Vector2i(10, 6))["id"])
	check(v.has_range(), "a well has a range")
	v.set_show_range(true)
	check_eq(v.house_counts(), {"served": 1, "not": 0}, "one watered house in range")
	v.select(house)
	check(not v.has_range(), "a house has none")
	v.select(0)
	v.free()


func test_the_buildings_walkers_are_marked() -> void:
	var c := _city()
	c.place_building("market", Vector2i(2, 6))
	var market: int = c.building_at(Vector2i(2, 6))["id"]
	_house(c, Vector2i(8, 6))
	c.economy.add(market, "rice", 8)
	c.place_building("seonangdang", Vector2i(14, 6))
	_days(c, 1)
	var v := WalkerView.new()
	v.setup(c)
	v.highlight_home = market
	v._process(0.0)
	check_eq(v._layers["mark"].multimesh.instance_count, c.walkers_of(market).size(), "one marker per walker of the market")
	check(c.walkers_of(market).size() > 0, "and it has some out")
	v.free()
