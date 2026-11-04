extends "res://tests/test_base.gd"
## The MVP scenario (phase 10): goals one after another, buildings unlocked by them, the
## scheduled first dokkaebi night, victory, saving and replays.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const Scenario = preload("res://scripts/data/scenario.gd")
const Objectives = preload("res://scripts/sim/objectives.gd")
const DemoTown = preload("res://scripts/sim/demo_town.gd")


## Open grass with a forest on the west edge; the valley entrance at (2, 10).
func _valley() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 24)
	for y in 24:
		for x in 40:
			c.grid.set_terrain(Vector2i(x, y), Terrain.FOREST if x < 2 else Terrain.GRASS)
	c.treasury = 100000
	c.set_entrance(Vector2i(2, 10))
	c.start_scenario()
	return c


func _days(c: City, days: float) -> void:
	for i in roundi(days * Balance.TICKS_PER_DAY):
		c.clock.step()


func _goal(id: String) -> int:
	for i in Scenario.GOALS.size():
		if Scenario.GOALS[i]["id"] == id:
			return i
	return -1


func test_buildings_unlock_with_goals() -> void:
	var c := _valley()
	check_eq(c.objectives.index, 0, "the first goal")
	check_eq(c.check_building("common_house", Vector2i(10, 11)), "", "houses from the start")
	check_eq(c.check_building("well", Vector2i(10, 11)), "", "wells from the start")
	check_eq(c.check_building("market", Vector2i(10, 11)), "REASON_LOCKED", "a Market waits for its goal")
	check_eq(c.place_building("market", Vector2i(10, 11)), "REASON_LOCKED", "and cannot be placed")
	check_eq(Objectives.unlocked_by("market"), _goal("rice"), "the rice goal opens it")
	var free := City.new()
	check(free.is_unlocked("market"), "free play: everything open")


func test_first_goals_by_playing() -> void:
	var c := _valley()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	_days(c, 1)
	check_eq(c.objectives.index, _goal("homes"), "a road into the valley")
	check_eq(c.objectives.done_at.size(), 1, "the first goal is done")
	for x in range(6, 30, 4):
		c.place_building("common_house", Vector2i(x, 11))
	c.place_building("well", Vector2i(8, 13))
	var p := c.objectives.progress()
	check_eq(p[0]["need"], 6, "six houses wanted")
	_days(c, 40)
	check_eq(c.objectives.index, _goal("rice"), "homes, a well and 30 people")
	check(c.is_unlocked("market") and c.is_unlocked("granary") and c.is_unlocked("rice_paddy"), "rice buildings open")
	check(not c.is_unlocked("seonangdang"), "the shrine still waits")


func test_goals_wait_until_every_condition_holds() -> void:
	var c := _valley()
	c.objectives._begin(_goal("homes"))
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	for x in range(6, 30, 4):
		c.place_building("common_house", Vector2i(x, 11))
	_days(c, 40)
	check_eq(c.objectives.index, _goal("homes"), "no well yet: the goal waits")
	check(not c.objectives.progress()[1]["done"], "the well line is not ticked")


func test_scheduled_dokkaebi_night() -> void:
	var c := _valley()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	c.objectives.unlocked["granary"] = true
	c.labor.extra_workers = 1000
	c.place_building("granary", Vector2i(20, 11))
	c.economy.add(c.building_at(Vector2i(20, 11))["id"], "rice", 10)
	check(not c.objectives.dokkaebi_allowed(), "no random dokkaebi before the scenario teaches them")
	c.clock.tick = Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR * Balance.TICKS_PER_DAY
	c.labor.population = 100
	for i in 20:
		c.dokkaebi.season_start()
	check(c.dokkaebi.raids.is_empty(), "the season roll stays quiet")
	c.objectives._begin(_goal("dokkaebi"))
	_days(c, Scenario.EVENT_DELAY_DAYS + 1)
	check_eq(c.dokkaebi.raids.size(), 1, "the advisor's dokkaebi are on their way")
	check_eq(c.objectives.index, _goal("dokkaebi"), "the goal waits for the night")
	_days(c, Balance.DOKKAEBI_WARNING_DAYS + 30)
	check(c.dokkaebi.raids.is_empty(), "the night has passed")
	check_eq(c.objectives.index, _goal("breathes"), "the goal is done")
	check(c.objectives.dokkaebi_allowed(), "from now on they may come on their own")


func test_victory() -> void:
	var c := _valley()
	c.objectives._begin(Scenario.GOALS.size() - 1)
	c.objectives.done_at.resize(Scenario.GOALS.size() - 1)
	check(not c.objectives.won(), "not yet")
	# Pretend the last goal holds: 300 people and ten Tiled Houses.
	for i in 10:
		c.place_building("common_house", Vector2i(4 + i * 3, 12))
	for id: int in c.houses.state:
		c.buildings.get_instance(id)["tier"] = 3
	c.labor.population = 300
	check(c.objectives.daily(), "the last goal is done")
	check(c.objectives.won(), "the scenario is won")
	check(c.objectives.progress().is_empty(), "nothing more to show")
	check(not c.objectives.daily(), "and it stays won")


func test_save_and_load_keep_the_scenario() -> void:
	var a := _valley()
	a.build_road(Vector2i(2, 10), Vector2i(38, 10))
	_days(a, 2)
	a.objectives.advice_seen = 1
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	check(b.objectives != null, "still a scenario")
	check_eq(b.objectives.index, a.objectives.index, "the same goal")
	check_eq(b.objectives.unlocked, a.objectives.unlocked, "the same buildings open")
	check_eq(b.objectives.advice_seen, 1, "the advisor does not repeat itself")
	check_eq(b.check_building("market", Vector2i(10, 12)), "REASON_LOCKED", "locks hold after loading")
	var free: City = SaveGame.city_from_bytes(SaveGame.pack(City.new()))["city"]
	check(free.objectives == null, "free play stays free")


func test_replay_starts_the_scenario() -> void:
	var a := City.new()
	a.start_scenario()
	a.build_road(a.entrance, a.entrance + Vector2i(12, 0))
	for i in 20:
		a.clock.step()
	var b := City.new()
	b.replay(a.command_log, a.clock.tick)
	check(b.objectives != null, "the replay plays the scenario")
	check_eq(b.objectives.index, a.objectives.index, "and reaches the same goal")


## The demo town (every chain built) plays through the first goals by itself.
func test_demo_town_plays_the_first_goals() -> void:
	var c := DemoTown.build()
	c.start_scenario()
	_days(c, 100)
	check(c.objectives.index >= _goal("jang"), "road, homes, rice, shrine and clay done (at goal %d)" % c.objectives.index)
	check(c.is_unlocked("jangdokdae"), "Fermentation Yard open")
