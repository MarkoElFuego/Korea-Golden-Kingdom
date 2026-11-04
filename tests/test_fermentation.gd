extends "res://tests/test_base.gd"
## Fermentation (phase 7a): Onggi Jars become the Jangdokdae's jars, Soybeans and Salt go
## into them, Jang is Fresh after 10 days and Ripe two seasons later, the player may keep
## Fresh Jang to ripen, and the game says what the yard is waiting for.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const CityView = preload("res://scripts/view/city_view.gd")

const YARD := Vector2i(12, 6)
const STOREHOUSE := Vector2i(8, 6)
const SOY := Vector2i(15, 6)
const SALT := Vector2i(19, 6)


## A street along y = 5 with plenty of workers and a shore for Salt Pans.
func _town() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	for y in range(6, 9):
		for x in range(19, 22):
			c.grid.set_terrain(Vector2i(x, y), Terrain.SHORE)
	c.treasury = 100000
	c.labor.extra_workers = 1000
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(39, 5))
	c.place_building("jangdokdae", YARD)
	return c


func _yard(c: City) -> int:
	return c.building_at(YARD)["id"]


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


## A yard that already has `jars` jars and inputs for them.
func _stocked(c: City, jars: int, soybeans: int, salt: int) -> void:
	var y := _yard(c)
	if jars > 0:
		c.economy.add(y, "onggi_jars", jars)
	if soybeans > 0:
		c.economy.add(y, "soybeans", soybeans)
	if salt > 0:
		c.economy.add(y, "salt", salt)


func test_onggi_jars_become_jars_in_the_yard() -> void:
	var c := _town()
	c.place_building("storehouse", STOREHOUSE)
	c.economy.add(c.building_at(STOREHOUSE)["id"], "onggi_jars", 3)
	check_eq(c.status(c.buildings.get_instance(_yard(c)))["key"], "STATUS_FETCHER_SOON", "jars in the Storehouse: the fetcher will go")
	_days(c, 20)
	check_eq(c.fermentation.counts(_yard(c))["jars"], 3, "three jars on the terrace")
	check_eq(c.economy.stock(c.building_at(STOREHOUSE)["id"], "onggi_jars"), 0, "all taken from the Storehouse")
	check_eq(c.economy.used.get("onggi_jars", 0), 3, "each load became one jar")


func test_no_more_jars_than_the_yard_holds() -> void:
	var c := _town()
	c.economy.add(_yard(c), "onggi_jars", 2)
	_days(c, 1)
	var space: int = c.economy.input_space(c.buildings.get_instance(_yard(c)), "onggi_jars")
	check_eq(space, 6, "room for six more of eight")
	c.economy.add(_yard(c), "onggi_jars", 7)
	_days(c, 1)
	check_eq(c.fermentation.counts(_yard(c))["jars"], 8, "eight at most")
	check_eq(c.economy.stock(_yard(c), "onggi_jars"), 1, "the ninth waits")


func test_soybeans_and_salt_become_fresh_then_ripe_jang() -> void:
	var c := _town()
	_stocked(c, 3, 2, 2)
	_days(c, 1)
	var n: Dictionary = c.fermentation.counts(_yard(c))
	check_eq(n["brewing"], 2, "two jars filled")
	check_eq(n["empty"], 1, "one waits for more")
	check_eq(c.economy.used.get("soybeans", 0), 2, "one Soybeans per jar")
	check_eq(c.economy.used.get("salt", 0), 2, "one Salt per jar")
	_days(c, 9)
	check_eq(c.fermentation.counts(_yard(c))["brewing"], 2, "not Fresh before 10 days")
	_days(c, 1)
	check_eq(c.fermentation.counts(_yard(c))["fresh"], 2, "Fresh after 10 days")
	check_eq(c.economy.produced.get("jang", 0), 2, "two loads of Jang made")
	_days(c, 59)
	check_eq(c.fermentation.counts(_yard(c))["ripe"], 0, "not Ripe before two more seasons")
	_days(c, 1)
	check_eq(c.fermentation.counts(_yard(c))["ripe"], 2, "Ripe two seasons after Fresh")


func test_fields_send_soybeans_and_salt_to_the_jangdokdae() -> void:
	var c := _town()
	c.economy.add(_yard(c), "onggi_jars", 4)
	check_eq(c.place_building("soybean_field", SOY), "", "Soybean Field")
	check_eq(c.place_building("salt_pans", SALT), "", "Salt Pans")
	_days(c, 30)
	var n: Dictionary = c.fermentation.counts(_yard(c))
	check(n["brewing"] + n["fresh"] >= 2, "jars filled from the fields (%d)" % (n["brewing"] + n["fresh"]))
	check(c.status(c.buildings.get_instance(c.building_at(SOY)["id"]))["key"] != "STATUS_NO_JANGDOKDAE", "the field has somewhere to send")


func test_ripe_only_keeps_fresh_jang_in_the_jar() -> void:
	var c := _town()
	_stocked(c, 2, 2, 2)
	_days(c, 12)
	var y := _yard(c)
	check_eq(c.fermentation.ready(y), 2, "Fresh Jang may go")
	c.set_ripe_only(y, true)
	check_eq(c.fermentation.ready(y), 0, "kept to ripen")
	check_eq(c.command_log.back()[1], "ripe_only", "the choice is a player command")
	_days(c, 60)
	check_eq(c.fermentation.ready(y), 2, "Ripe Jang may go")
	check(c.economy.state[y]["ripe_only"], "the choice stays")


func test_the_yard_says_what_it_waits_for() -> void:
	var c := _town()
	var y := c.buildings.get_instance(_yard(c))
	var st: Dictionary = c.status(y)
	check_eq(st["key"], "STATUS_NO_JARS", "no jars anywhere")
	check(st["stopped"], "stands still")
	check_eq(st["good"], "onggi_jars", "about Onggi Jars")
	_stocked(c, 2, 2, 0)
	_days(c, 1)
	st = c.status(y)
	check_eq(st["key"], "STATUS_JARS_WAIT_FOR", "jars wait")
	check_eq(st["good"], "salt", "for Salt")
	check(st["stopped"], "nothing brews")
	c.economy.add(_yard(c), "salt", 2)
	_days(c, 1)
	check_eq(c.status(y)["key"], "STATUS_JANGDOKDAE", "brewing")
	check_eq(c.supply.stopped().size(), 0, "nothing stands still")
	_days(c, 10)
	check_eq(c.status(y)["key"], "STATUS_JARS_ALL_FULL", "every jar holds Jang")
	for row in c.supply.report():
		if row["good"] == "jang":
			check_eq(row["stored"], 2, "the Goods window counts Jang in the jars")
			check_eq(row["makers"], 1, "one Jangdokdae")


func test_soybeans_wait_when_the_yard_has_no_room() -> void:
	var c := _town()
	c.place_building("soybean_field", SOY)
	_days(c, 30)
	var field := c.buildings.get_instance(c.building_at(SOY)["id"])
	check_eq(c.status(field)["key"], "STATUS_JANGDOKDAE_NO_ROOM", "the yard (without jars) has no room")


func test_jars_and_goods_are_all_accounted_for() -> void:
	var c := _town()
	c.place_building("soybean_field", SOY)
	c.place_building("salt_pans", SALT)
	c.place_building("storehouse", STOREHOUSE)
	c.economy.add(c.building_at(STOREHOUSE)["id"], "onggi_jars", 5)
	_days(c, 50)
	for good in ["soybeans", "salt", "onggi_jars"]:
		var n := 0
		for s: Dictionary in c.economy.state.values():
			n += s["stock"].get(good, 0)
		n += c.carriers.carried(good) + c.services.carried(good) + c.economy.used.get(good, 0) + c.economy.lost.get(good, 0) + c.economy.stolen.get(good, 0)
		check_eq(n, c.economy.produced.get(good, 0) + (5 if good == "onggi_jars" else 0), good + " all accounted for")
	var n: Dictionary = c.fermentation.counts(_yard(c))
	check_eq(n["brewing"] + n["fresh"] + n["ripe"], c.economy.used.get("salt", 0), "one jar of Jang per Salt used")


func test_a_saved_yard_ripens_the_same() -> void:
	var a := _town()
	_stocked(a, 4, 2, 2)
	a.place_building("soybean_field", SOY)
	a.place_building("salt_pans", SALT)
	_days(a, 7.4)
	a.set_ripe_only(_yard(a), true)
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	_days(a, 80)
	_days(b, 80)
	check(a.fermentation.counts(_yard(a))["ripe"] > 0, "Jang ripened")
	check_eq(b.economy.state, a.economy.state, "jars and goods")
	check_eq(b.carriers.walkers, a.carriers.walkers, "carriers")


func test_jars_are_drawn_with_their_lids() -> void:
	var c := _town()
	_stocked(c, 3, 1, 1)
	_days(c, 1)
	var v := CityView.new()
	v.setup(c)
	check_eq(v.goods_boxes("jar"), 3, "three jars on the terrace")
	check_eq(v.goods_boxes("lid_brewing"), 1, "one closed and brewing")
	_days(c, 10)
	check_eq(v.goods_boxes("lid_fresh"), 1, "its lid turns light when Fresh")
	v.free()


func test_jars_that_reach_a_storehouse_later_are_still_found() -> void:
	var c := _town()
	c.place_building("storehouse", STOREHOUSE)
	_days(c, 3) # the fetcher looks and finds nothing, again and again
	check_eq(c.status(c.buildings.get_instance(_yard(c)))["key"], "STATUS_NO_JARS", "nothing to fetch yet")
	c.economy.add(c.building_at(STOREHOUSE)["id"], "onggi_jars", 2)
	_days(c, 20)
	check_eq(c.fermentation.counts(_yard(c))["jars"], 2, "the new jars are fetched")
