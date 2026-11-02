extends "res://tests/test_base.gd"
## Market Buyer and Vendor, the shrine keeper, house pantries and visits (phase 4b).

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Services = preload("res://scripts/sim/services.gd")

const ENTRANCE := Vector2i(0, 5)


## Flat grass 64x24, entrance on the west edge, one street on row 5, plenty of workers.
func _city(street_end := 39) -> City:
	var c := City.new()
	c.grid = Grid.new(64, 24)
	c.treasury = 100000
	c.labor.extra_workers = 100
	c.set_entrance(ENTRANCE)
	c.build_road(ENTRANCE, Vector2i(street_end, 5))
	return c


func _run_days(c: City, days: int) -> void:
	for i in days * Balance.TICKS_PER_DAY:
		c.clock.step()


## A house that already has people (skips waiting for settlers).
func _settled_house(c: City, tile: Vector2i, tier := 1) -> int:
	c.place_building("common_house", tile)
	var house := c.building_at(tile)
	house["tier"] = tier
	c.houses.state[house["id"]]["residents"] = c.houses.capacity(tier)
	return house["id"]


func _granary_with_rice(c: City, tile: Vector2i, loads: int) -> int:
	c.place_building("granary", tile)
	var id: int = c.building_at(tile)["id"]
	c.economy.add(id, "rice", loads)
	return id


func _walkers(c: City, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in c.services.all():
		if w["kind"] == kind:
			result.append(w)
	return result


# --- Buyer ---

func test_buyer_brings_rice_from_the_granary() -> void:
	var c := _city()
	var granary := _granary_with_rice(c, Vector2i(20, 6), 10)
	c.place_building("market", Vector2i(4, 6))
	var market: int = c.building_at(Vector2i(4, 6))["id"]
	c.clock.step()
	check_eq(_walkers(c, "buyer").size(), 1, "the Market sends its Buyer")
	_run_days(c, 25)
	var loads: int = Services.market_data("market")["buyer_loads"]
	check_eq(c.economy.stock(granary, "rice"), 10 - loads, "one Buyer's load left the Granary")
	check(c.economy.stock(market, "rice") + _carried_by_vendors(c) >= loads - 1, "and reached the Market")


func _carried_by_vendors(c: City) -> int:
	var portions := 0
	for w in _walkers(c, "vendor"):
		portions += w["food"]
	return ceili(portions / float(Balance.FOOD_PORTIONS_PER_LOAD))


func test_no_rice_no_buyer_no_vendor() -> void:
	var c := _city()
	c.place_building("granary", Vector2i(20, 6))
	c.place_building("market", Vector2i(4, 6))
	_run_days(c, 20)
	check_eq(c.services.count(), 0, "nobody walks out")
	check_eq(c.status(c.building_at(Vector2i(4, 6)))["key"], "STATUS_NO_RICE_TO_SELL", "the window says why")


func test_no_workers_no_walkers() -> void:
	var c := _city()
	c.labor.extra_workers = 0
	c._recompute_labor()
	_granary_with_rice(c, Vector2i(20, 6), 10)
	c.place_building("market", Vector2i(4, 6))
	c.place_building("seonangdang", Vector2i(10, 6))
	_run_days(c, 20)
	check_eq(c.services.count(), 0, "an empty Market and shrine send nobody")


# --- Vendor ---

func test_vendor_fills_the_pantry_only_where_it_walks() -> void:
	var c := _city()
	var near := _settled_house(c, Vector2i(8, 6))
	var far := _settled_house(c, Vector2i(37, 6)) # more than 30 road tiles from the Market
	c.place_building("market", Vector2i(2, 6))
	c.economy.add(c.building_at(Vector2i(2, 6))["id"], "rice", 8)
	_run_days(c, 40)
	check(c.houses.state[near]["food"] > 0, "the house on the vendor's round has rice")
	check_eq(c.houses.state[far]["food"], 0, "the far house has none")
	check_eq(c.houses.days_since(far, "market"), -1, "no vendor ever passed it")
	check(c.houses.pantry_days(near) <= Balance.PANTRY_DAYS, "the pantry holds at most 30 days")


func test_residents_eat_and_an_empty_pantry_drops_the_house() -> void:
	var c := _city()
	var id := _settled_house(c, Vector2i(8, 6), 2) # 12 people
	c.place_building("well", Vector2i(10, 6))
	c.houses.state[id]["food"] = 24 # two days of rice
	c.houses.visit(id, "seonangdang", 0)
	_run_days(c, 1)
	check_eq(c.houses.state[id]["food"], 12, "twelve people eat twelve portions a day")
	_run_days(c, Balance.HOUSE_DOWN_DAYS - 1)
	check_eq(c.building_at(Vector2i(8, 6))["tier"], 2, "still a Choga House")
	_run_days(c, 1)
	check_eq(c.building_at(Vector2i(8, 6))["tier"], 1, "ten days without rice: back to a hut")


func test_jangseung_turns_the_vendor_back_but_not_the_buyer() -> void:
	var c := _city()
	c.place_building("market", Vector2i(2, 6))
	c.place_building("jangseung", Vector2i(10, 5))
	var house := _settled_house(c, Vector2i(14, 6))
	var granary := _granary_with_rice(c, Vector2i(20, 6), 10)
	for i in 40 * Balance.TICKS_PER_DAY:
		c.clock.step()
		for w in _walkers(c, "vendor"):
			var outward: Array = w["path"].slice(0, w["serve_end"] + 1)
			check(not outward.has(Vector2i(10, 5)), "a vendor never walks past the Jangseung")
	check(c.economy.stock(granary, "rice") < 10, "the Buyer walked past it to the Granary")
	check_eq(c.houses.days_since(house, "market"), -1, "no vendor behind the Jangseung")


func test_jangseung_built_ahead_of_a_walker_turns_it_around() -> void:
	var c := _city(63)
	c.place_building("seonangdang", Vector2i(32, 6))
	_run_days(c, 3)
	var w: Dictionary = _walkers(c, "keeper")[0]
	var here: Vector2i = w["path"][w["index"]]
	var step: Vector2i = w["path"][w["index"] + 1] - here
	var block := here + step * 3 # three tiles ahead on its round
	c.place_building("jangseung", block)
	check_eq(w["serve_end"], -1, "it turns around")
	for i in 60 * Balance.TICKS_PER_DAY:
		c.clock.step()
		if c.services.walkers.has(w["id"]):
			check(w["path"][w["index"]] != block, "and never steps onto the Jangseung")
	check(not c.services.walkers.has(w["id"]), "it got home")


# --- Shrine keeper ---

func test_seonangdang_visit_lasts_30_days() -> void:
	var c := _city()
	var id := _settled_house(c, Vector2i(8, 6))
	c.place_building("seonangdang", Vector2i(6, 6))
	var house := c.building_at(Vector2i(8, 6))
	while c.houses.days_since(id, "seonangdang") < 0 and c.clock.tick < 400:
		c.clock.step()
	check(c.houses.is_met(house, "seonangdang"), "the keeper passed")
	c.demolish(Vector2i(6, 6), Vector2i(6, 6))
	var visit: int = c.houses.state[id]["visits"]["seonangdang"]
	while c.clock.tick < visit + Balance.SERVICE_DAYS * Balance.TICKS_PER_DAY - 1:
		c.clock.step()
	check(c.houses.is_met(house, "seonangdang"), "still counts on day 29")
	c.clock.step()
	check(not c.houses.is_met(house, "seonangdang"), "gone after 30 days")


func test_roaming_walker_turns_home_after_30_road_tiles() -> void:
	var c := _city(63)
	c.place_building("seonangdang", Vector2i(32, 6))
	c.clock.step()
	var keepers := _walkers(c, "keeper")
	check_eq(keepers.size(), 1, "one keeper sets out")
	var w := keepers[0]
	check_eq(w["serve_end"], Balance.WALKER_MAX_ROAD_TILES - 1, "serves 30 road tiles")
	check_eq(w["path"][-1], w["path"][0], "then walks back to the door")
	_run_days(c, 60)
	check(c.services.count() <= Balance.ROAMER_MAX_OUT, "at most four out at once")


# --- Demolish while walking ---

func test_demolish_market_and_roads_while_walkers_are_out() -> void:
	var c := _city()
	_granary_with_rice(c, Vector2i(30, 6), 20)
	c.place_building("market", Vector2i(4, 6))
	c.place_building("seonangdang", Vector2i(10, 6))
	_settled_house(c, Vector2i(14, 6))
	_run_days(c, 8)
	check(c.services.count() > 0, "walkers out")
	c.demolish(Vector2i(12, 5), Vector2i(12, 5)) # cut the street
	_run_days(c, 3)
	c.demolish(Vector2i(4, 6), Vector2i(4, 6)) # the Market
	_run_days(c, 3)
	for w in c.services.all():
		check(w["home"] != c.building_at(Vector2i(4, 6)).get("id", -1), "no walker of a demolished Market")
	check(c.services.count() <= Balance.ROAMER_MAX_OUT, "only shrine keepers are left")


# --- Determinism ---

## A small town with crossings, so walkers make random choices.
func _town() -> City:
	var c := _city()
	c.build_road(Vector2i(6, 5), Vector2i(6, 20))
	c.build_road(Vector2i(20, 5), Vector2i(20, 20))
	c.build_road(Vector2i(6, 12), Vector2i(30, 12))
	c.build_road(Vector2i(6, 20), Vector2i(20, 20))
	_granary_with_rice(c, Vector2i(21, 6), 30)
	c.place_building("market", Vector2i(7, 6))
	c.place_building("seonangdang", Vector2i(10, 13))
	for x in range(7, 19, 2):
		c.place_building("common_house", Vector2i(x, 13))
		c.place_building("common_house", Vector2i(x, 18))
	return c


func test_same_seed_same_rounds() -> void:
	var a := _town()
	var b := _town()
	_run_days(a, 90)
	_run_days(b, 90)
	check(a.services.count() > 0, "walkers out (%d)" % a.services.count())
	check_eq(b.services.walkers, a.services.walkers, "same walkers on the same tiles")
	check_eq(b.houses.state, a.houses.state, "same pantries and visits")
