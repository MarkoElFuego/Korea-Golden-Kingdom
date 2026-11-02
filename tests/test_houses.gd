extends "res://tests/test_base.gd"
## Houses, settlers, the labour pool and the seasonal tax (phases 4a and 4b).

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const WalkerMotion = preload("res://scripts/sim/walker_motion.gd")

const ENTRANCE := Vector2i(0, 5)


## Flat grass 40x24, entrance on the west edge, one street on row 5.
func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 24)
	c.treasury = 100000
	c.set_entrance(ENTRANCE)
	c.build_road(ENTRANCE, Vector2i(39, 5))
	return c


func _run_days(c: City, days: int) -> void:
	for i in days * Balance.TICKS_PER_DAY:
		c.clock.step()


func _house(c: City, tile: Vector2i) -> Dictionary:
	return c.building_at(tile)


func _residents(c: City, tile: Vector2i) -> int:
	return c.houses.state[_house(c, tile)["id"]]["residents"]


# --- Valley entrance ---

func test_map_has_an_entrance_on_the_west_edge() -> void:
	for s: int in [Balance.DEFAULT_MAP_SEED, 1, 42]:
		var c := City.new(s)
		check_eq(c.entrance.x, 0, "seed %d: on the west edge" % s)
		check(c.grid.is_road(c.entrance), "seed %d: it is a road" % s)
		check(_buildable_path(c.grid, c.entrance, Vector2i(32, 30)), "seed %d: a road can reach the valley from it" % s)


func _buildable_path(grid: Grid, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		if t == to:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := t + d
			if grid.in_bounds(n) and not seen.has(n) and Terrain.DEFAULT_BUILDABLE.has(grid.get_terrain(n)):
				seen[n] = true
				queue.append(n)
	return false


func test_entrance_cannot_be_demolished() -> void:
	var c := _city()
	c.demolish(ENTRANCE, ENTRANCE + Vector2i(2, 0))
	check(c.grid.is_road(ENTRANCE), "entrance stays")
	check(not c.grid.is_road(ENTRANCE + Vector2i(1, 0)), "the road next to it goes")


# --- Settlers ---

func test_settlers_turn_a_lot_into_a_choga_hut() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(8, 6))
	check_eq(_house(c, Vector2i(8, 6))["tier"], 0, "vacant lot")
	_run_days(c, 1)
	check_eq(c.settlers.count(), 1, "a group of settlers is walking in")
	check_eq(c.settlers.all()[0]["people"], 6, "six of them")
	_run_days(c, 10)
	check_eq(_house(c, Vector2i(8, 6))["tier"], 1, "now a Choga Hut")
	check_eq(_residents(c, Vector2i(8, 6)), 6, "six residents")
	check_eq(c.population(), 6, "city population")


func test_no_road_to_the_entrance_no_settlers() -> void:
	var c := _city()
	c.build_road(Vector2i(20, 15), Vector2i(30, 15))
	c.place_building("common_house", Vector2i(24, 16))
	_run_days(c, 10)
	check_eq(c.settlers.count(), 0, "nobody can walk there")
	check(not c.settlers.entrance_connected, "the advisor asks for a road to the entrance")
	c.build_road(Vector2i(20, 5), Vector2i(20, 15))
	_run_days(c, 3)
	check(c.settlers.entrance_connected, "connected now")
	check_eq(c.settlers.count(), 1, "settlers set out")


func test_oldest_house_first() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(20, 6))
	c.place_building("common_house", Vector2i(4, 6))
	_run_days(c, 1)
	check_eq(c.settlers.all()[0]["target"], _house(c, Vector2i(20, 6))["id"], "first lot built gets settlers first")
	_run_days(c, 20)
	check_eq(_residents(c, Vector2i(20, 6)), 6, "first house full")
	check_eq(_residents(c, Vector2i(4, 6)), 6, "second house full too")


func test_house_demolished_while_settlers_walk() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(30, 6))
	c.place_building("common_house", Vector2i(10, 6))
	_run_days(c, 1)
	c.demolish(Vector2i(30, 6), Vector2i(30, 6))
	check_eq(c.settlers.all()[0]["target"], _house(c, Vector2i(10, 6))["id"], "they pick the other house")
	_run_days(c, 20)
	check_eq(_residents(c, Vector2i(10, 6)), 6, "and move in")
	check_eq(c.houses.state[_house(c, Vector2i(10, 6))["id"]]["incoming"], 0, "nobody counted twice")


func test_road_cut_under_settlers_frees_the_house_for_the_next_group() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(30, 6))
	_run_days(c, 3)
	check_eq(c.settlers.count(), 1, "settlers on the way")
	var at: Vector2i = WalkerMotion.here(c.settlers.all()[0])
	c.demolish(at, at) # the road under their feet
	check_eq(c.settlers.count(), 0, "they leave the valley")
	check_eq(c.houses.state[_house(c, Vector2i(30, 6))["id"]]["incoming"], 0, "the house stops waiting for them")
	c.build_road(at, at)
	_run_days(c, 30)
	check_eq(_residents(c, Vector2i(30, 6)), 6, "the next group moves in")


# --- Tiers ---

## A house at (8, 6) with a Well, a Seonangdang and a Market on a short street
## (0..19, so every roaming walker passes the house), and rice in a staffed Granary.
func _comfortable_city() -> City:
	var c := _city()
	c.demolish(Vector2i(20, 5), Vector2i(39, 5))
	c.labor.extra_workers = 50
	c.place_building("common_house", Vector2i(8, 6))
	c.place_building("well", Vector2i(10, 6))
	c.place_building("seonangdang", Vector2i(11, 6))
	c.place_building("market", Vector2i(12, 6))
	c.place_building("granary", Vector2i(16, 6))
	c.economy.add(c.building_at(Vector2i(16, 6))["id"], "rice", 30)
	return c


## Runs day by day until `done` is true (at most `days`). Returns the days it took.
func _run_until(c: City, done: Callable, days: int) -> int:
	for d in days:
		if done.call():
			return d
		_run_days(c, 1)
	return days


func test_house_rises_to_choga_house() -> void:
	var c := _comfortable_city()
	var days := _run_until(c, func() -> bool: return _house(c, Vector2i(8, 6))["tier"] == 2, 60)
	check(days < 60, "Choga House after %d days" % days)
	_run_days(c, 20)
	check_eq(_residents(c, Vector2i(8, 6)), 12, "more settlers fill the bigger house")


func test_tier_3_waits_for_jang_and_onggi() -> void:
	var c := _comfortable_city()
	_run_days(c, 60)
	var house := _house(c, Vector2i(8, 6))
	check_eq(house["tier"], 2, "stays a Choga House")
	check(not c.houses.is_met(house, "jang"), "Jang is not in the valley yet")
	check(not c.houses.is_met(house, "onggi_jars"), "nor Onggi Jars")


func test_no_seonangdang_no_choga_house() -> void:
	var c := _comfortable_city()
	c.demolish(Vector2i(11, 6), Vector2i(11, 6))
	_run_days(c, 60)
	check_eq(_house(c, Vector2i(8, 6))["tier"], 1, "stays a Choga Hut")


func test_house_drops_a_tier_after_10_days_without_water() -> void:
	var c := _comfortable_city()
	_run_until(c, func() -> bool: return _residents(c, Vector2i(8, 6)) == 12, 80)
	check_eq(_residents(c, Vector2i(8, 6)), 12, "full Choga House")
	c.demolish(Vector2i(10, 6), Vector2i(10, 6)) # the Well
	_run_days(c, Balance.HOUSE_DOWN_DAYS - 1)
	check_eq(_house(c, Vector2i(8, 6))["tier"], 2, "still a Choga House after 9 days")
	_run_days(c, 1)
	check_eq(_house(c, Vector2i(8, 6))["tier"], 1, "drops on day 10")
	check_eq(_residents(c, Vector2i(8, 6)), 6, "six people move away")


func test_needs_add_up() -> void:
	check_eq(Houses.needs_for(1), ["road", "water", "food"] as Array[String], "tier 1")
	check_eq(Houses.needs_for(2), ["road", "water", "food", "seonangdang"] as Array[String], "tier 2 keeps tier 1")
	check_eq(Houses.capacity(0), 6, "a lot waits for a hut's worth of people")
	check_eq(Houses.capacity(2), 12, "Choga House")


# --- Labour ---

func test_workers_are_40_percent_and_go_in_build_order() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(8, 6))
	c.place_building("common_house", Vector2i(10, 6))
	c.place_building("storehouse", Vector2i(20, 6)) # 6 workers, built first
	c.place_building("granary", Vector2i(30, 6)) # 8 workers
	_run_days(c, 25)
	check_eq(c.population(), 12, "two huts")
	check_eq(c.labor.workforce, 4, "40% of 12")
	check_eq(c.labor.assigned[c.building_at(Vector2i(20, 6))["id"]], 4, "first building gets all four")
	check_eq(c.labor.assigned[c.building_at(Vector2i(30, 6))["id"]], 0, "the Granary gets nobody")
	check_eq(c.labor.needed, 14, "buildings need 6 + 8")


func test_few_workers_slow_production() -> void:
	var c := _city()
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.labor.extra_workers = 2 # a third of a Rice Paddy's 6 workers
	c.place_building("rice_paddy", Vector2i(10, 6))
	var paddy := c.building_at(Vector2i(10, 6))
	_run_days(c, 23)
	check_eq(c.economy.produced.get("rice", 0), 0, "not ready after 23 days")
	_run_days(c, 1)
	check_eq(c.economy.produced.get("rice", 0), 1, "a third of the workers: 24 days instead of 8")
	c.labor.extra_workers = 6
	c._recompute_labor()
	_run_days(c, 8)
	check_eq(c.economy.produced.get("rice", 0), 2, "full staff: 8 days again")
	check_eq(c.status(paddy)["key"], "STATUS_NO_GRANARY", "status still works")


func test_no_workers_no_production_and_storage_takes_nothing() -> void:
	var c := _city()
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.place_building("rice_paddy", Vector2i(10, 6))
	c.place_building("granary", Vector2i(20, 6))
	_run_days(c, 30)
	check_eq(c.economy.produced.get("rice", 0), 0, "nobody works the field")
	check_eq(c.economy.free_space(c.building_at(Vector2i(20, 6)), "rice"), 0, "an empty Granary takes nothing")


# --- Tax ---

func test_tax_at_the_end_of_each_season() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(8, 6))
	c.place_building("common_house", Vector2i(10, 6))
	_run_days(c, 25)
	var silver := c.treasury
	_run_days(c, Balance.DAYS_PER_SEASON - 25)
	check_eq(c.treasury, silver + 12 * Balance.TAX_PER_RESIDENT, "12 residents pay 2 Silver each")


# --- Determinism ---

func test_city_with_settlers_replays_the_same() -> void:
	var a := _city()
	a.labor.extra_workers = 20
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var types: Array[String] = ["common_house", "common_house", "well", "granary", "seonangdang", "market"]
	for i in 120:
		var t := Vector2i(rng.randi_range(1, 37), rng.randi_range(0, 21))
		match rng.randi_range(0, 3):
			0:
				a.build_road(t, Vector2i(t.x, 5))
			1:
				if rng.randf() < 0.2:
					a.demolish(t, t)
			_:
				a.place_building(types[rng.randi_range(0, types.size() - 1)], t, rng.randi_range(0, 3))
		for k in rng.randi_range(0, 40):
			a.clock.step()
	_run_days(a, 120)
	check(a.population() > 20, "people moved in (%d)" % a.population())
	var b := _city()
	b.labor.extra_workers = 20
	b.replay(a.command_log.slice(1), a.clock.tick) # skip the setup street both cities share
	check_eq(b.houses.state, a.houses.state, "same houses")
	check_eq(b.population(), a.population(), "same population")
	check_eq(b.treasury, a.treasury, "same treasury")
	check_eq(b.settlers.walkers, a.settlers.walkers, "same settlers on the road")
	check_eq(b.services.walkers, a.services.walkers, "same vendors, keepers and buyers")
