extends "res://tests/test_base.gd"
## Phase 7b: the Market keeps rice, Jang and Onggi Jars; its Buyer takes Jang from the
## Jangdokdae (Ripe first, and Fresh only when the player lets it go); vendors leave Jang and
## jars at houses from tier 2; with both a Choga House becomes a Giwa House.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const MARKET := Vector2i(2, 6)
const YARD := Vector2i(14, 6)


func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.labor.extra_workers = 1000
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	return c


func _id(c: City, at: Vector2i) -> int:
	return c.building_at(at)["id"]


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


## A Jangdokdae whose jars already hold Jang: `ripe` Ripe, `fresh` Fresh.
func _yard(c: City, ripe: int, fresh: int) -> int:
	c.place_building("jangdokdae", YARD)
	var id := _id(c, YARD)
	var now: int = c.clock.tick
	for i in ripe:
		c.economy.state[id]["jars"].append({"state": "ripe", "at": now})
	for i in fresh:
		c.economy.state[id]["jars"].append({"state": "fresh", "at": now})
	return id


## A lived-in house at `tier` with full pantry and a recent shrine visit.
func _house(c: City, at: Vector2i, tier: int) -> int:
	c.place_building("common_house", at)
	var id := _id(c, at)
	c.buildings.get_instance(id)["tier"] = tier
	var s: Dictionary = c.houses.state[id]
	s["residents"] = Houses.capacity(tier)
	s["food"] = Houses.pantry_size(tier)
	s["visits"] = {"seonangdang": c.clock.tick}
	c.houses.clear_cache()
	return id


func test_the_buyer_takes_ripe_jang_first() -> void:
	var c := _city()
	var yard := _yard(c, 2, 3)
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.economy.add(market, "rice", 16) # the rice stall is full: Jang is what it lacks most
	_days(c, 1)
	check_eq(c.walkers_of(market)[0]["args"], ["GOOD_RIPE_JANG"], "the Buyer goes for Ripe Jang")
	_days(c, 25)
	check_eq(c.economy.stock(market, "ripe_jang") + c.economy.sold.get("ripe_jang", 0), 2,
		"two loads of Ripe Jang reached the Market (some already out with vendors)")
	var n: Dictionary = c.fermentation.counts(yard)
	check_eq(n["ripe"], 0, "taken from the jars")
	check(n["brewing"] + n["empty"] >= 2, "those jars are empty again (or already refilled)")


func test_ripe_only_keeps_fresh_jang_from_the_market() -> void:
	var c := _city()
	var yard := _yard(c, 0, 3)
	c.set_ripe_only(yard, true)
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.economy.add(market, "rice", 16)
	_days(c, 30)
	check_eq(c.economy.stock(market, "jang"), 0, "no Fresh Jang leaves the yard")
	check_eq(c.fermentation.counts(yard)["fresh"], 3, "it stays in the jars")
	check_eq(c.status(c.buildings.get_instance(market))["key"], "STATUS_MARKET_LACKS", "the Market says it has none")
	c.set_ripe_only(yard, false)
	_days(c, 25)
	check(c.economy.stock(market, "jang") > 0, "let go, Fresh Jang reaches the Market")


func test_vendors_bring_jang_and_jars_to_houses_from_tier_2() -> void:
	var c := _city()
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.economy.add(market, "rice", 8)
	c.economy.add(market, "ripe_jang", 2)
	c.economy.add(market, "onggi_jars", 1)
	var choga := _house(c, Vector2i(6, 6), 2)
	var hut := _house(c, Vector2i(8, 6), 1)
	_days(c, 8)
	check(c.houses.state[choga]["jang"] > 0, "the Choga House gets Jang")
	check(c.houses.jars_days(choga) > 300, "and a set of jars for a year")
	check_eq(c.houses.state[hut]["jang"], 0, "the hut does not want Jang yet")
	check_eq(c.houses.jars_days(hut), 0, "nor jars")


func test_a_load_of_ripe_jang_goes_twice_as_far() -> void:
	var c := _city()
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.economy.add(market, "jang", 1)
	c.economy.add(market, "ripe_jang", 1)
	var w := {"home": market, "food": 0, "jang_ripe": 0, "jang_fresh": 0, "jars": 0}
	c.services._load_vendor(w)
	check_eq(w["jang_fresh"], Balance.JANG_PORTIONS_FRESH, "a Fresh load")
	check_eq(w["jang_ripe"], 2 * w["jang_fresh"], "a Ripe load: twice as many portions")
	var h := _house(c, Vector2i(6, 6), 2)
	c.houses.state[h]["jang"] = 0
	check_eq(c.houses.give_jang(h, 10000), Houses.pantry_size(2), "a house takes a pantry's worth")


func test_a_choga_house_with_jang_and_jars_becomes_a_giwa_house() -> void:
	var c := _city()
	c.place_building("well", Vector2i(10, 4))
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.place_building("seonangdang", Vector2i(9, 6))
	var house := _house(c, Vector2i(6, 6), 2)
	c.economy.add(market, "rice", 8)
	c.economy.add(market, "ripe_jang", 2)
	c.economy.add(market, "onggi_jars", 1)
	_days(c, 8)
	check_eq(c.buildings.get_instance(house)["tier"], 3, "a Giwa House")
	check_eq(Houses.capacity(3), 20, "room for twenty")
	c.houses.state[house]["jang"] = 0
	c.economy.add(market, "ripe_jang", -c.economy.stock(market, "ripe_jang"))
	_days(c, Balance.HOUSE_DOWN_DAYS + 1)
	check_eq(c.buildings.get_instance(house)["tier"], 2, "without Jang it falls back")


func test_jang_is_all_accounted_for() -> void:
	var c := _city()
	_yard(c, 2, 3)
	c.place_building("market", MARKET)
	var market := _id(c, MARKET)
	c.economy.add(market, "rice", 16)
	for x in [6, 8, 10]:
		_house(c, Vector2i(x, 6), 2)
	_days(c, 80)
	for good in ["jang", "ripe_jang"]:
		var n := 0
		for s: Dictionary in c.economy.state.values():
			n += s["stock"].get(good, 0)
			for jar: Dictionary in s.get("jars", []):
				if c.economy.jar_good(s["type"], jar["state"]) == good:
					n += 1
		n += c.services.carried(good) + c.economy.sold.get(good, 0) + c.economy.used.get(good, 0) + c.economy.lost.get(good, 0)
		var start := 3 if good == "jang" else 2
		check_eq(n, start + c.economy.produced.get(good, 0), good + " all accounted for")


func test_a_saved_market_plays_on_the_same() -> void:
	var a := _city()
	_yard(a, 2, 3)
	a.place_building("market", MARKET)
	a.economy.add(_id(a, MARKET), "rice", 12)
	for x in [6, 8, 10]:
		_house(a, Vector2i(x, 6), 2)
	_days(a, 9.3)
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	_days(a, 40)
	_days(b, 40)
	check_eq(b.houses.state, a.houses.state, "houses")
	check_eq(b.economy.state, a.economy.state, "goods and jars")
	check_eq(b.services.walkers, a.services.walkers, "vendors and buyers")
