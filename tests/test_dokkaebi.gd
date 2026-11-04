extends "res://tests/test_base.gd"
## Dokkaebi (phase 9): night thieves of low-Gi quarters. A warning first (fires in the
## hills), then a night when they walk to a storage and carry goods away. Guardian Posts
## make them rarer and turn them back on the road; an offering at a Village Shrine appeases
## them, and then they sometimes leave Silver.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const GRANARY_AT := Vector2i(20, 11)


## Open grass (Gi 40), a forest along the west edge, a street along y = 10 and a Granary
## below it holding 10 loads of rice.
func _town(seed_value := Balance.DEFAULT_MAP_SEED) -> City:
	var c := City.new(seed_value)
	c.grid = Grid.new(40, 24)
	for y in 24:
		for x in 40:
			c.grid.set_terrain(Vector2i(x, y), Terrain.FOREST if x < 2 else Terrain.GRASS)
	c.treasury = 100000
	c.labor.extra_workers = 1000
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	c.place_building("granary", GRANARY_AT)
	c.economy.add(_granary(c)["id"], "rice", 10)
	return c


func _granary(c: City) -> Dictionary:
	return c.building_at(GRANARY_AT)


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


## Runs until every dokkaebi has gone (at most 40 days).
func _until_dawn(c: City) -> void:
	for i in 40 * Balance.TICKS_PER_DAY:
		if c.dokkaebi.raids.is_empty():
			return
		c.clock.step()


func test_chance_follows_gi_and_posts() -> void:
	var c := _town()
	var granary := _granary(c)
	check_eq(c.gi.of_area(granary["origin"], granary["size"]), 40, "open grass")
	check_near(c.dokkaebi.chance(granary), 0.25, "Gi 40: one season in four")
	c.place_building("jangseung", Vector2i(24, 10))
	var gi: int = c.gi.of_area(granary["origin"], granary["size"])
	check_eq(c.dokkaebi.posts_near(granary), 1, "one post near")
	check_near(c.dokkaebi.chance(granary), (50 - gi) * 0.025 * 0.5, "a post halves it (and raises the Gi)")
	c.place_building("seonangdang", Vector2i(18, 9))
	check(c.gi.of_area(granary["origin"], granary["size"]) >= Balance.DOKKAEBI_SAFE_GI, "a shrine lifts the Gi")
	check_eq(c.dokkaebi.chance(granary), 0.0, "Gi 50 and up: never")


func test_none_in_the_first_year_or_a_small_village() -> void:
	var c := _town()
	c.labor.population = 100
	for i in 20:
		c.dokkaebi.season_start()
	check(c.dokkaebi.raids.is_empty(), "never in the first year")
	c.clock.tick = Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR * Balance.TICKS_PER_DAY
	c.labor.population = 10
	for i in 20:
		c.dokkaebi.season_start()
	check(c.dokkaebi.raids.is_empty(), "never in a small village")
	c.labor.population = 100
	for i in 20:
		c.dokkaebi.season_start()
	check_eq(c.dokkaebi.raids.size(), 1, "in a big enough town in the second year they come, one night at a time")


func test_same_seed_same_nights() -> void:
	var nights: Array[String] = []
	for run in 2:
		var c := _town()
		c.clock.tick = Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR * Balance.TICKS_PER_DAY
		c.labor.population = 100
		var seasons := ""
		for i in 16:
			c.dokkaebi.season_start()
			seasons += "x" if not c.dokkaebi.raids.is_empty() else "."
			c.dokkaebi.raids.clear()
		nights.append(seasons)
	check_eq(nights[0], nights[1], "the same seed gives the same nights")
	check(nights[0].contains("x") and nights[0].contains("."), "some seasons yes, some no (%s)" % nights[0])


func test_warning_then_night_then_theft() -> void:
	var c := _town()
	var id: int = _granary(c)["id"]
	check(c.dokkaebi.plan_raid(_granary(c)), "they will come")
	var fire: Vector2i = c.dokkaebi.fires()[0]
	check_eq(c.grid.get_terrain(fire), Terrain.FOREST, "fires show in the forest")
	check_eq(c.dokkaebi.advice()["key"], "ADVICE_DOKKAEBI_COMING", "the advisor warns")
	check_eq(c.dokkaebi.advice()["args"][1], Balance.DOKKAEBI_WARNING_DAYS, "five days ahead")
	_days(c, Balance.DOKKAEBI_WARNING_DAYS - 0.5)
	check(not c.dokkaebi.is_night(), "not yet")
	_days(c, 0.5)
	check(c.dokkaebi.is_night(), "night falls")
	var count := c.dokkaebi.walkers.size()
	check(count >= Balance.DOKKAEBI_COUNT_MIN and count <= Balance.DOKKAEBI_COUNT_MAX, "2 or 3 dokkaebi (%d)" % count)
	_until_dawn(c)
	check(c.dokkaebi.walkers.is_empty() and not c.dokkaebi.is_night(), "they are gone by morning")
	var stolen: int = c.economy.stolen.get("rice", 0)
	check_eq(stolen, count * Balance.DOKKAEBI_LOADS, "each carried away two loads")
	check_eq(c.economy.stock(id, "rice") + stolen, 10, "no rice vanished uncounted")
	check_eq(c.dokkaebi.note(id)["key"], "DOKKAEBI_NOTE_TOOK", "the Granary window tells of it")
	check_eq(c.dokkaebi.note(id)["args"][0], stolen, "with how many loads")
	_days(c, Balance.DOKKAEBI_NOTE_DAYS + 1)
	check(c.dokkaebi.note(id).is_empty(), "old news fades")


func test_guardian_posts_turn_them_back() -> void:
	var c := _town()
	var id: int = _granary(c)["id"]
	c.place_building("jangseung", Vector2i(10, 10)) # between the forest and the Granary
	c.dokkaebi.plan_raid(_granary(c))
	_days(c, Balance.DOKKAEBI_WARNING_DAYS)
	check(c.dokkaebi.walkers.size() > 0, "they set off")
	_until_dawn(c)
	check_eq(c.economy.stock(id, "rice"), 10, "nothing stolen")
	check_eq(c.dokkaebi.note(id)["key"], "DOKKAEBI_NOTE_TURNED", "the posts turned them back")


func test_offering_appeases_them() -> void:
	var c := _town()
	var id: int = _granary(c)["id"]
	c.place_building("seonangdang", Vector2i(24, 9))
	var shrine: int = c.building_at(Vector2i(24, 9))["id"]
	var silver := c.treasury
	check_eq(c.make_offering(shrine), "", "an offering of buckwheat jelly")
	check_eq(c.treasury, silver - Balance.OFFERING_COST, "for 50 Silver")
	check_eq(c.dokkaebi.offering_days(shrine), Balance.OFFERING_DAYS, "it lasts a year")
	check_eq(c.make_offering(shrine), "REASON_OFFERING_MADE", "one at a time")
	check_eq(c.make_offering(id), "REASON_UNKNOWN_BUILDING", "only at a shrine")
	check(c.dokkaebi.appeased(_granary(c)), "the shrine covers the Granary")
	c.dokkaebi.plan_raid(_granary(c))
	silver = c.treasury
	_days(c, Balance.DOKKAEBI_WARNING_DAYS)
	_until_dawn(c)
	check_eq(c.economy.stock(id, "rice"), 10, "nothing stolen")
	var note: Dictionary = c.dokkaebi.note(id)
	check(note["key"] == "DOKKAEBI_NOTE_GIFT" or note["key"] == "DOKKAEBI_NOTE_APPEASED", "they left in good spirits")
	var gift := Balance.OFFERING_GIFT if note["key"] == "DOKKAEBI_NOTE_GIFT" else 0
	check_eq(c.treasury - silver, gift, "and maybe left Silver")


func test_offering_and_gifts_happen_sometimes() -> void:
	var gifts := 0
	for run in 12:
		var c := _town(1000 + run)
		c.place_building("seonangdang", Vector2i(24, 9))
		c.make_offering(c.building_at(Vector2i(24, 9))["id"])
		c.dokkaebi.plan_raid(_granary(c))
		_days(c, Balance.DOKKAEBI_WARNING_DAYS)
		_until_dawn(c)
		if c.dokkaebi.note(_granary(c)["id"])["key"] == "DOKKAEBI_NOTE_GIFT":
			gifts += 1
	check(gifts > 0 and gifts < 12, "Silver sometimes, not always (%d of 12)" % gifts)


func test_offering_ends_with_the_shrine() -> void:
	var c := _town()
	c.place_building("seonangdang", Vector2i(24, 9))
	c.make_offering(c.building_at(Vector2i(24, 9))["id"])
	c.demolish(Vector2i(24, 9), Vector2i(24, 9))
	check(not c.dokkaebi.appeased(_granary(c)), "no shrine, no offering")


func test_replay_with_offering() -> void:
	var a := _town()
	a.place_building("seonangdang", Vector2i(24, 9))
	a.make_offering(a.building_at(Vector2i(24, 9))["id"])
	var b := _town()
	b.replay(a.command_log.slice(a.command_log.size() - 2), a.clock.tick)
	check_eq(b.dokkaebi.offerings, a.dokkaebi.offerings, "the offering is a logged command")


func test_save_in_the_middle_of_the_night() -> void:
	var a := _town()
	a.dokkaebi.plan_raid(_granary(a))
	_days(a, Balance.DOKKAEBI_WARNING_DAYS + 0.8)
	check(a.dokkaebi.is_night(), "dokkaebi on the road")
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	check(b != null, "loads")
	_until_dawn(a)
	_until_dawn(b)
	var id: int = _granary(a)["id"]
	check_eq(b.economy.stock(id, "rice"), a.economy.stock(id, "rice"), "the same night after loading")
	check_eq(b.economy.stolen, a.economy.stolen, "the same theft")
	check_eq(b.dokkaebi.note(id), a.dokkaebi.note(id), "the same news")
