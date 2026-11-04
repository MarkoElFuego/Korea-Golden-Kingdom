extends "res://tests/test_base.gd"
## Production (phase 6): the Onggi Kiln turns Clay and Wood into Onggi Jars, carriers bring
## inputs to the kiln before the Storehouse, the kiln's fetcher goes for what it lacks,
## Soybeans and Salt wait for the Jangdokdae, and the game says where goods are missing.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const KILN := Vector2i(12, 6)
const STOREHOUSE := Vector2i(16, 6) # next to the kiln
const CLAY_PIT := Vector2i(2, 6)
const WOODCUTTER := Vector2i(6, 6)


## A street along y = 5 with plenty of workers; rocky hill and forest at the west end.
func _town(workers := 1000) -> City:
	var c := City.new()
	c.grid = Grid.new(40, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	for y in range(6, 8):
		for x in range(2, 4):
			c.grid.set_terrain(Vector2i(x, y), Terrain.ROCKY_HILL)
	for x in range(6, 8):
		c.grid.set_terrain(Vector2i(x, 9), Terrain.FOREST)
	c.treasury = 100000
	c.labor.extra_workers = workers
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	return c


func _id(c: City, tile: Vector2i) -> int:
	return c.building_at(tile)["id"]


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


## Every load of `good` ever made or brought in is somewhere: in a building, on a back,
## used up by a workshop, sold, or lost with a demolished building.
func _accounted(c: City, good: String) -> int:
	var n := 0
	for s: Dictionary in c.economy.state.values():
		n += s["stock"].get(good, 0)
	return n + c.carriers.carried(good) + c.services.carried(good) + c.economy.used.get(good, 0) \
		+ c.economy.sold.get(good, 0) + c.economy.lost.get(good, 0) + c.economy.stolen.get(good, 0)


# --- The kiln ---

func test_kiln_makes_jars_from_clay_and_wood() -> void:
	var c := _town()
	c.place_building("storehouse", STOREHOUSE)
	c.place_building("onggi_kiln", KILN)
	var store := _id(c, STOREHOUSE)
	c.economy.add(store, "clay", 4)
	c.economy.add(store, "wood", 4)
	_days(c, 40)
	var jars: int = c.economy.produced.get("onggi_jars", 0)
	check(jars >= 3, "jars made (%d)" % jars)
	check_eq(c.economy.used.get("clay", 0), c.economy.used.get("wood", 0), "one Clay and one Wood per load")
	check(c.economy.used["clay"] - jars <= 1, "inputs are used for loads made (one may be in the kiln)")
	check_eq(_accounted(c, "clay"), 4, "no Clay appears or vanishes")
	check_eq(_accounted(c, "wood"), 4, "no Wood appears or vanishes")
	check(c.economy.stock(store, "onggi_jars") > 0, "jars carried to the Storehouse")


func test_carriers_bring_inputs_to_the_kiln_first() -> void:
	var c := _town()
	c.place_building("clay_pit", CLAY_PIT)
	c.place_building("storehouse", Vector2i(8, 6)) # nearer to the pit than the kiln
	c.place_building("onggi_kiln", Vector2i(14, 6))
	var kiln := _id(c, Vector2i(14, 6))
	var store := _id(c, Vector2i(8, 6))
	_days(c, 7) # the first load of Clay is on its way
	check_eq(c.economy.produced.get("clay", 0), 1, "the pit made Clay")
	check_eq(c.economy.incoming(kiln, "clay"), 1, "it goes to the kiln")
	check_eq(c.economy.stock(store, "clay"), 0, "not to the nearer Storehouse")
	_days(c, 60)
	check_eq(c.economy.incoming(kiln, "clay"), Balance.WORKSHOP_INPUT_STORE, "the kiln (without Wood) is full")
	check(c.economy.stock(store, "clay") > 0, "so Clay goes to the Storehouse")


func test_fetcher_goes_only_for_what_the_kiln_lacks() -> void:
	var c := _town()
	c.place_building("storehouse", STOREHOUSE)
	c.place_building("onggi_kiln", KILN)
	var kiln := _id(c, KILN)
	c.economy.add(_id(c, STOREHOUSE), "wood", 4)
	c.economy.add(kiln, "clay", 2)
	_days(c, 0.5)
	check(c.services.buyer_out(kiln), "out of Wood: the fetcher goes")
	check_eq(c.economy.incoming(kiln, "wood"), Balance.WORKSHOP_INPUT_STORE, "the loads it goes for are announced")
	_days(c, 6) # walkers cover 1.5 road tiles a day: four tiles there, four back
	check(not c.services.buyer_out(kiln), "back home")
	check(c.economy.used.get("wood", 0) + c.economy.stock(kiln, "wood") == Balance.WORKSHOP_INPUT_STORE,
		"it brought two loads of Wood")
	var sent_again := false
	var guard := 0
	while c.economy.incoming(kiln, "wood") > 0 and guard < 30 * Balance.TICKS_PER_DAY:
		sent_again = sent_again or c.services.buyer_out(kiln)
		c.clock.step()
		guard += 1
	check(not sent_again, "it does not go while the kiln still has Wood")
	_days(c, 0.2)
	check(c.services.buyer_out(kiln), "and goes again when the last load is used")


func test_kiln_works_at_the_speed_of_its_workers() -> void:
	var c := _town(0)
	c.place_building("onggi_kiln", KILN)
	var kiln := _id(c, KILN)
	c.economy.add(kiln, "clay", 2)
	c.economy.add(kiln, "wood", 2)
	_days(c, 10)
	check_eq(c.economy.produced.get("onggi_jars", 0), 0, "no workers, no jars")
	check_eq(c.economy.used.get("clay", 0), 0, "and no inputs used")
	var st: Dictionary = c.status(c.buildings.get_instance(kiln))
	check_eq(st["key"], "STATUS_NO_WORKERS", "the window says why")
	check(st["stopped"], "a stopped building")
	c.labor.extra_workers = 3 # half of the six
	c._recompute_labor()
	_days(c, 11.5)
	check_eq(c.economy.produced.get("onggi_jars", 0), 0, "at half speed a load takes 12 days")
	check_eq(c.status(c.buildings.get_instance(kiln))["key"], "STATUS_PRODUCING_SLOW", "working slowly")
	_days(c, 1)
	check_eq(c.economy.produced.get("onggi_jars", 0), 1, "and here it is")


# --- Where goods are missing ---

func test_the_game_says_which_input_is_missing() -> void:
	var c := _town()
	c.place_building("storehouse", STOREHOUSE)
	c.place_building("onggi_kiln", KILN)
	var kiln := _id(c, KILN)
	c.economy.add(_id(c, STOREHOUSE), "wood", 4)
	_days(c, 6)
	var st: Dictionary = c.status(c.buildings.get_instance(kiln))
	check_eq(st["key"], "STATUS_NO_INPUT", "no Clay anywhere")
	check_eq(st["good"], "clay", "about Clay")
	check(st["stopped"], "the kiln stands still")
	check_eq(c.supply.stopped().size(), 1, "one stopped building in the city")
	var jars := _row(c, "onggi_jars")
	check_eq(jars["makers"], 1, "one kiln")
	check_eq(jars["idle"], 1, "and it is stopped")
	check_eq(jars["note"]["key"], "STATUS_NO_INPUT", "the Goods window says why")
	check_eq(_row(c, "clay")["note"]["key"], "NOTE_NO_MAKER", "and that nothing makes Clay")
	check_eq(_row(c, "wood")["stored"], 2, "Wood in storage: 4 less the 2 the fetcher took")
	c.economy.add(_id(c, STOREHOUSE), "clay", 2)
	check_eq(c.status(c.buildings.get_instance(kiln))["key"], "STATUS_FETCHER_SOON", "Clay found: the fetcher will go")


func test_goods_window_counts_this_year() -> void:
	var c := _town()
	c.place_building("clay_pit", CLAY_PIT)
	c.place_building("storehouse", Vector2i(5, 6))
	_days(c, 30)
	var clay := _row(c, "clay")
	check(clay["year"] >= 5, "made this year (%d)" % clay["year"])
	check_eq(clay["makers"], 1, "one Clay Pit")
	check_eq(clay["idle"], 0, "working")
	check_eq(clay["stored"] + clay["moving"] + c.economy.stock(_id(c, CLAY_PIT), "clay"), clay["year"], "all of it is somewhere")
	c.economy.new_year()
	check_eq(_row(c, "clay")["year"], 0, "a new year starts from zero")


func _row(c: City, good: String) -> Dictionary:
	for row in c.supply.report():
		if row["good"] == good:
			return row
	return {}


# --- Soybeans and Salt ---

func test_soybeans_and_salt_wait_for_the_jangdokdae() -> void:
	var c := _town()
	for y in range(6, 9):
		for x in range(30, 33):
			c.grid.set_terrain(Vector2i(x, y), Terrain.SHORE)
	c.place_building("storehouse", STOREHOUSE)
	c.place_building("granary", Vector2i(24, 6))
	check_eq(c.place_building("soybean_field", Vector2i(20, 6)), "", "Soybean Field")
	check_eq(c.place_building("salt_pans", Vector2i(30, 6)), "", "Salt Pans on the shore")
	_days(c, 30)
	for spot: Array in [[Vector2i(20, 6), "soybeans"], [Vector2i(30, 6), "salt"]]:
		var id := _id(c, spot[0])
		check_eq(c.economy.stock(id, spot[1]), Balance.PRODUCER_STORE, "%s: two loads wait at home" % spot[1])
		var st: Dictionary = c.status(c.buildings.get_instance(id))
		check_eq(st["key"], "STATUS_NO_JANGDOKDAE", spot[1] + ": waits for a Jangdokdae")
		check(st["stopped"], spot[1] + ": stopped while full")
	check_eq(c.carriers.count(), 0, "no carrier walks off with them")


# --- Saving ---

func test_a_saved_chain_plays_on_the_same() -> void:
	var a := _town()
	a.place_building("clay_pit", CLAY_PIT)
	a.place_building("woodcutter", WOODCUTTER)
	a.place_building("storehouse", STOREHOUSE)
	a.place_building("onggi_kiln", Vector2i(26, 6))
	a.place_building("onggi_kiln", KILN)
	a.economy.add(_id(a, STOREHOUSE), "wood", 3)
	_days(a, 23.3)
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	_days(a, 40)
	_days(b, 40)
	check(a.economy.produced.get("onggi_jars", 0) > 0, "the chain works")
	check_eq(b.economy.state, a.economy.state, "goods")
	check_eq(b.economy.used, a.economy.used, "inputs used")
	check_eq(b.carriers.walkers, a.carriers.walkers, "carriers")
	check_eq(b.services.walkers, a.services.walkers, "fetchers")
	for good in ["clay", "wood", "onggi_jars"]:
		check_eq(_accounted(a, good), a.economy.produced.get(good, 0) + (3 if good == "wood" else 0), good + " all accounted for")
