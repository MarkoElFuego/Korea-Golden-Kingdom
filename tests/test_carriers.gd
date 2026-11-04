extends "res://tests/test_base.gd"
## Road network, storage and carriers (phase 3).

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")


## Flat fertile valley 40x20 with one east-west street on row 5.
func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 20)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.labor.extra_workers = 100000 # these tests are about carriers, not about staffing
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	return c


func _run_days(c: City, days: int) -> void:
	for i in days * Balance.TICKS_PER_DAY:
		c.clock.step()


func _total_stock(c: City, good: String) -> int:
	var n := 0
	for id: int in c.economy.state:
		n += c.economy.stock(id, good)
	return n


## Every load ever produced is in a store, on a carrier or a buyer, went out with a Market
## vendor, or was destroyed by demolish.
func _check_conservation(c: City, label: String) -> void:
	for good in Goods.ids():
		var produced: int = c.economy.produced.get(good, 0)
		var accounted: int = _total_stock(c, good) + c.carriers.carried(good) + c.services.carried(good) 			+ c.economy.sold.get(good, 0) + c.economy.lost.get(good, 0) + c.economy.stolen.get(good, 0)
		check_eq(accounted, produced, "%s: %s conserved" % [label, good])


func _id_at(c: City, tile: Vector2i) -> int:
	return c.building_at(tile)["id"]


func test_path_follows_roads_and_passes_jangseung() -> void:
	var c := _city()
	c.place_building("jangseung", Vector2i(10, 5))
	var path := c.network.path(Vector2i(0, 5), Vector2i(20, 5))
	check_eq(path.size(), 21, "straight along the street")
	check(path.has(Vector2i(10, 5)), "carriers walk past a Jangseung")
	check(c.network.path(Vector2i(0, 5), Vector2i(0, 10)).is_empty(), "no road, no path")


func test_network_rebuilds_only_when_roads_change() -> void:
	var c := _city()
	var before := c.network.rebuild_count
	c.place_building("granary", Vector2i(20, 6))
	check_eq(c.network.rebuild_count, before, "a building does not touch the network")
	c.build_road(Vector2i(5, 6), Vector2i(5, 12))
	check_eq(c.network.rebuild_count, before + 1, "a new road does")
	check_eq(c.network.path(Vector2i(0, 5), Vector2i(5, 12)).size(), 6 + 7, "and it is used at once")
	c.demolish(Vector2i(5, 8), Vector2i(5, 8))
	check(c.network.path(Vector2i(0, 5), Vector2i(5, 12)).is_empty(), "demolished road cuts the path")


func test_rice_goes_to_the_granary() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	c.place_building("granary", Vector2i(20, 6))
	var granary := _id_at(c, Vector2i(20, 6))
	_run_days(c, 8)
	check_eq(c.carriers.count(), 1, "first load ready after 8 days, a carrier sets out")
	check_eq(c.carriers.all()[0]["cargo"], "rice", "carrying rice")
	_run_days(c, 40)
	# ~17 tiles each way at 1.5 tiles/s: a round trip takes ~23 days, one carrier at a time.
	check_eq(c.economy.stock(granary, "rice"), 2, "two loads arrived in the Granary")
	_check_conservation(c, "after 48 days")


func test_granary_refuses_wood() -> void:
	var c := _city()
	c.grid.set_terrain(Vector2i(4, 9), Terrain.FOREST)
	check_eq(c.place_building("woodcutter", Vector2i(2, 6)), "", "woodcutter near the forest")
	c.place_building("granary", Vector2i(20, 6))
	_run_days(c, 30)
	check_eq(c.carriers.count(), 0, "no carrier: nobody takes wood")
	var woodcutter := c.building_at(Vector2i(2, 6))
	check_eq(c.economy.stock(woodcutter["id"], "wood"), Balance.PRODUCER_STORE, "store full, production stopped")
	check_eq(c.economy.produced["wood"], Balance.PRODUCER_STORE, "nothing made after that")
	check_eq(c.status(woodcutter)["key"], "STATUS_NO_STOREHOUSE", "the window says why")


func test_nearest_storage_by_road() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(10, 6))
	c.place_building("granary", Vector2i(30, 6)) # older, far
	c.place_building("granary", Vector2i(15, 6)) # newer, near
	_run_days(c, 8)
	check_eq(c.carriers.all()[0]["target"], _id_at(c, Vector2i(15, 6)), "goes to the nearer Granary")


func test_full_storage_is_skipped() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(10, 6))
	c.place_building("granary", Vector2i(15, 6))
	c.place_building("granary", Vector2i(30, 6))
	c.economy.add(_id_at(c, Vector2i(15, 6)), "rice", 32)
	_run_days(c, 8)
	check_eq(c.carriers.all()[0]["target"], _id_at(c, Vector2i(30, 6)), "near one is full, goes on")


func test_storehouse_slots() -> void:
	var c := _city()
	c.place_building("storehouse", Vector2i(20, 6))
	var store := c.building_at(Vector2i(20, 6))
	check_eq(c.economy.free_space(store, "wood"), 32, "empty: 8 slots x 4")
	check_eq(c.economy.free_space(store, "rice"), 0, "rice belongs in a Granary")
	c.economy.add(store["id"], "wood", 5) # two slots: 4 + 1
	check_eq(c.economy.free_space(store, "wood"), 3 + 6 * 4, "wood: rest of its slot + empty slots")
	check_eq(c.economy.free_space(store, "clay"), 6 * 4, "clay: only empty slots")


func test_no_storage_stops_production() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	_run_days(c, 60)
	var paddy := c.building_at(Vector2i(2, 6))
	check_eq(c.economy.stock(paddy["id"], "rice"), Balance.PRODUCER_STORE, "store holds 2 loads")
	check_eq(c.status(paddy)["key"], "STATUS_NO_GRANARY", "the window says why")


func test_storage_demolished_on_the_way() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	c.place_building("granary", Vector2i(30, 6))
	c.place_building("granary", Vector2i(20, 6))
	_run_days(c, 9)
	check_eq(c.carriers.all()[0]["target"], _id_at(c, Vector2i(20, 6)), "heading to the near Granary")
	c.demolish(Vector2i(21, 7), Vector2i(21, 7))
	check_eq(c.carriers.all()[0]["target"], _id_at(c, Vector2i(30, 6)), "turns to the other Granary")
	_check_conservation(c, "right after")
	_run_days(c, 40)
	check(c.economy.stock(_id_at(c, Vector2i(30, 6)), "rice") >= 1, "rice arrives there")
	_check_conservation(c, "later")


func test_only_storage_demolished_carrier_brings_load_home() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	c.place_building("granary", Vector2i(30, 6))
	_run_days(c, 10)
	c.demolish(Vector2i(31, 7), Vector2i(31, 7))
	check_eq(c.carriers.all()[0]["state"], "return", "walks back")
	_run_days(c, 40)
	check_eq(c.carriers.count(), 0, "home again")
	var paddy := c.building_at(Vector2i(2, 6))
	check_eq(c.economy.stock(paddy["id"], "rice"), Balance.PRODUCER_STORE, "load is back in the store")
	_check_conservation(c, "after the trip")


func test_road_demolished_under_the_carrier() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	c.place_building("granary", Vector2i(30, 6))
	_run_days(c, 9)
	var here: Vector2i = c.carriers.all()[0]["path"][c.carriers.all()[0]["index"]]
	c.demolish(here, here)
	check_eq(c.carriers.count(), 0, "the carrier leaves the map")
	check_eq(c.economy.stock(c.building_at(Vector2i(2, 6))["id"], "rice"), 1, "its load went back home")
	_check_conservation(c, "after the road was cut")


func test_producer_demolished_while_carrier_is_out() -> void:
	var c := _city()
	c.place_building("rice_paddy", Vector2i(2, 6))
	c.place_building("granary", Vector2i(30, 6))
	_run_days(c, 9)
	c.demolish(Vector2i(3, 7), Vector2i(3, 7))
	_run_days(c, 30)
	check_eq(c.carriers.count(), 0, "carrier delivered and left")
	check_eq(c.economy.stock(_id_at(c, Vector2i(30, 6)), "rice"), 1, "its load still arrived")
	_check_conservation(c, "after the farm was gone")


func test_long_random_city_conserves_goods_and_replays() -> void:
	var a := City.new(Balance.DEFAULT_MAP_SEED)
	a.treasury = 100000
	a.labor.extra_workers = 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var types: Array[String] = ["rice_paddy", "granary", "storehouse", "woodcutter", "clay_pit", "market", "common_house"]
	for i in 400:
		var t := Vector2i(rng.randi_range(4, 59), rng.randi_range(8, 50))
		match rng.randi_range(0, 4):
			0, 1:
				a.build_road(t, t + Vector2i(rng.randi_range(-12, 12), rng.randi_range(-12, 12)))
			2:
				if rng.randf() < 0.3:
					a.demolish(t, t)
			_:
				a.place_building(types[rng.randi_range(0, types.size() - 1)], t, rng.randi_range(0, 3))
		for k in rng.randi_range(0, 30):
			a.clock.step()
	for k in 3000:
		a.clock.step()
	var total := 0
	for good in Goods.ids():
		total += a.economy.produced.get(good, 0)
	check(total > 20, "the city produced something (%d loads)" % total)
	_check_conservation(a, "random city")
	var b := City.new(Balance.DEFAULT_MAP_SEED)
	b.treasury = 100000
	b.labor.extra_workers = 100000
	b.replay(a.command_log, a.clock.tick)
	check_eq(b.economy.produced, a.economy.produced, "replay: same production")
	check_eq(b.economy.state, a.economy.state, "replay: same stores")
	check_eq(b.carriers.walkers, a.carriers.walkers, "replay: same carriers in the same places")
