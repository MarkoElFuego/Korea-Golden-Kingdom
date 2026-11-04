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
const Coverage = preload("res://scripts/sim/coverage.gd")


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


# --- The advisor's pointing finger (menu glow, arrow on the map) ---

## A valley with every kind of land: fertile plain, rocky hill, forest and shore.
func _land() -> City:
	var c := _valley()
	for y in range(13, 20):
		for x in range(20, 30):
			c.grid.set_terrain(Vector2i(x, y), Terrain.FERTILE_PLAIN)
	for y in range(3, 6):
		for x in range(20, 24):
			c.grid.set_terrain(Vector2i(x, y), Terrain.ROCKY_HILL)
	for y in range(18, 24):
		for x in range(34, 40):
			c.grid.set_terrain(Vector2i(x, y), Terrain.SHORE)
	c.gi.mark_dirty()
	return c


func _check_spot(c: City, type: String) -> void:
	var s: Dictionary = c.objectives.guide.find_spot(type)
	check(not s.is_empty(), "%s: a spot is found" % type)
	if s.is_empty():
		return
	var reason := c.check_building(type, s["origin"])
	check(reason == "" or reason == "REASON_NOT_ENOUGH_SILVER", "%s: it can stand there (%s)" % [type, reason])


func test_the_first_goal_points_to_the_entrance() -> void:
	var c := _valley()
	var g = c.objectives.guide
	check_eq(g.todo(), ["road"] as Array[String], "the Road button glows")
	check_eq(g.spot()["origin"], c.entrance, "the arrow points at the valley entrance")
	c.build_road(Vector2i(2, 10), Vector2i(35, 10))
	check(g.todo().is_empty(), "enough road: nothing glows")
	check(g.spot().is_empty(), "and no arrow")


func test_homes_glow_until_built_and_spots_are_buildable() -> void:
	var c := _valley()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	_days(c, 1)
	var g = c.objectives.guide
	check_eq(g.todo(), ["common_house", "well"] as Array[String], "houses and a well glow")
	for i in 6:
		var s: Dictionary = g.spot()
		check_eq(s["type"], "common_house", "the arrow shows a house lot")
		check(Coverage.has_road_access(c.grid, s["origin"], s["size"]), "beside the road")
		check_eq(c.place_building("common_house", s["origin"]), "", "and it can be built right there")
	check_eq(g.todo(), ["well"] as Array[String], "six lots: only the well still glows")
	check_eq(c.place_building("well", g.spot()["origin"]), "", "the well goes where the arrow says")
	check(g.todo().is_empty(), "everything for this goal is built")


func test_spots_on_the_right_land() -> void:
	var c := _land()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	c.build_road(Vector2i(22, 6), Vector2i(22, 10))
	for id in ["rice_paddy", "soybean_field", "clay_pit", "woodcutter", "salt_pans", "granary", "market",
			"seonangdang", "storehouse", "onggi_kiln", "jangdokdae"]:
		c.objectives.unlocked[id] = true
		_check_spot(c, id)
	check_eq(c.grid.get_terrain(c.objectives.guide.find_spot("rice_paddy")["origin"]), Terrain.FERTILE_PLAIN, "rice on the fertile plain")
	check_eq(c.grid.get_terrain(c.objectives.guide.find_spot("clay_pit")["origin"]), Terrain.ROCKY_HILL, "clay from the rocky hill")
	check_eq(c.grid.get_terrain(c.objectives.guide.find_spot("salt_pans")["origin"]), Terrain.SHORE, "salt on the shore")


func test_fermentation_yard_between_fields_and_salt() -> void:
	var c := _land()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	c.build_road(Vector2i(33, 10), Vector2i(33, 22))
	for id in ["soybean_field", "salt_pans", "jangdokdae"]:
		c.objectives.unlocked[id] = true
	c.place_building("soybean_field", Vector2i(20, 13))
	c.place_building("salt_pans", Vector2i(34, 19))
	var s: Dictionary = c.objectives.guide.find_spot("jangdokdae")
	var fields := Vector2i(20, 13)
	var salt := Vector2i(34, 19)
	var halfway := (fields + salt) / 2
	check(absi(s["origin"].x - halfway.x) + absi(s["origin"].y - halfway.y) <= 10, "near halfway (%s)" % s["origin"])


func test_guardian_post_spot_near_the_storage() -> void:
	var c := _valley()
	c.build_road(Vector2i(2, 10), Vector2i(38, 10))
	c.labor.extra_workers = 1000
	c.objectives.unlocked["granary"] = true
	c.place_building("granary", Vector2i(20, 11))
	c.economy.add(c.building_at(Vector2i(20, 11))["id"], "rice", 10)
	c.objectives.unlocked["jangseung"] = true # opened by the shrine goal, skipped here
	c.objectives._begin(_goal("dokkaebi"))
	c.objectives.guide.mark_dirty()
	var g = c.objectives.guide
	check_eq(g.todo(), ["jangseung"] as Array[String], "Guardian Posts glow")
	var s: Dictionary = g.spot()
	check(c.grid.is_road(s["origin"]), "on the road")
	check_eq(c.place_building("jangseung", s["origin"]), "", "it can stand there")
	check(c.dokkaebi.posts_near(c.building_at(Vector2i(20, 11))) >= 1, "close enough to guard the Granary")


func test_free_play_has_no_guide() -> void:
	var c := City.new()
	check(c.objectives == null, "no scenario, no glow, no arrow")


# --- The advisor's plan of the first town (phase 10c) ---

func _lay(c: City, path: Array[Vector2i]) -> void:
	for i in path.size() - 1:
		c.build_road(path[i], path[i + 1])


func test_the_first_street_is_planned() -> void:
	var c := _valley()
	var g = c.objectives.guide
	var s: Dictionary = g.step()
	check_eq(s["kind"], "road", "the first step is the street")
	var path: Array[Vector2i] = s["path"]
	check_eq(path[0], c.entrance, "it starts at the valley entrance")
	check_eq(g.roads().size(), 30, "thirty gold road tiles, deep into the valley")
	var straight := true
	for t in path:
		straight = straight and t.y == c.entrance.y
	check(straight, "straight into the valley: one drag")
	c.build_road(path[0], path[path.size() - 1])
	check(g.roads().is_empty(), "built: the gold path is gone")
	_days(c, 1)
	check_eq(c.objectives.index, _goal("homes"), "and the goal is done")


func test_the_homes_are_planned_all_at_once() -> void:
	var c := _valley()
	c.build_road(c.entrance, c.entrance + Vector2i(30, 0))
	_days(c, 1)
	var g = c.objectives.guide
	var houses := 0
	var wells := 0
	var tiles := {}
	var apart := true
	for m: Dictionary in g.ghosts():
		houses += 1 if m["type"] == "common_house" else 0
		wells += 1 if m["type"] == "well" else 0
		for dy in m["size"].y:
			for dx in m["size"].x:
				var t: Vector2i = m["origin"] + Vector2i(dx, dy)
				apart = apart and not tiles.has(t)
				tiles[t] = true
		if m["type"] == "common_house":
			check(g.touches_town(m["origin"], m["size"]), "a lot beside the street")
	check_eq(houses, 6, "six house lots")
	check_eq(wells, 1, "and a well")
	check(apart, "the marks do not overlap")
	check_eq(g.step()["kind"], "build", "next: build on a mark")
	for m: Dictionary in g.ghosts().duplicate():
		check_eq(c.place_building(m["type"], m["origin"]), "", "%s fits its mark" % m["type"])
	check(g.ghosts().is_empty(), "all built: no marks left")
	check_eq(g.step()["kind"], "wait", "then wait for settlers")


func test_a_cut_off_paddy_gets_a_road() -> void:
	var c := _land()
	c.build_road(c.entrance, Vector2i(38, 10))
	c.objectives._begin(_goal("rice"))
	c.objectives.guide.mark_dirty()
	var g = c.objectives.guide
	check_eq(c.place_building("rice_paddy", Vector2i(24, 16)), "", "a paddy far from the road")
	var s: Dictionary = g.step()
	check_eq(s["kind"], "connect", "the next step: connect it")
	check_eq(s["building"], "rice_paddy", "the paddy")
	check_eq(g.buttons()[0], "road", "the Road button glows first")
	var path: Array[Vector2i] = s["path"]
	check(g.town().has(path[0]), "the path starts on a town road")
	check(Coverage._edge_neighbors(Vector2i(24, 16), Vector2i(3, 3)).has(path[path.size() - 1]), "and ends beside the paddy")
	check_eq(g.spot()["origin"], path[0], "the arrow shows where to start dragging")
	_lay(c, path)
	check(g.touches_town(Vector2i(24, 16), Vector2i(3, 3)), "now the paddy touches the town's roads")
	check(g.step()["kind"] != "connect", "and the advisor moves on")


func test_planned_fields_come_with_their_road() -> void:
	var c := _land()
	c.build_road(c.entrance, Vector2i(38, 10))
	c.objectives._begin(_goal("rice"))
	c.objectives.guide.mark_dirty()
	var g = c.objectives.guide
	var paddies := 0
	for m: Dictionary in g.ghosts():
		if m["type"] != "rice_paddy":
			continue
		paddies += 1
		check_eq(c.grid.get_terrain(m["origin"]), Terrain.FERTILE_PLAIN, "on the fertile plain")
		var reached := g.touches_town(m["origin"], m["size"])
		for t in Coverage._edge_neighbors(m["origin"], m["size"]):
			reached = reached or g.roads().has(t)
		check(reached, "a town road or a planned one reaches it")
	check_eq(paddies, 2, "two paddies planned")


func test_the_next_step_follows_the_player() -> void:
	load("res://scripts/view/text_loader.gd").install() # the sentences need their %s
	var StepBar = load("res://scripts/view/step_bar.gd")
	var BuildTool = load("res://scripts/view/build_tool.gd")
	var bar = StepBar.new()
	var c := _valley()
	var o = c.objectives
	var keys := []
	keys.append(bar.text_for(o, BuildTool.Mode.NONE, ""))
	keys.append(bar.text_for(o, BuildTool.Mode.ROAD, ""))
	c.build_road(c.entrance, c.entrance + Vector2i(30, 0))
	_days(c, 1)
	keys.append(bar.text_for(o, BuildTool.Mode.NONE, ""))
	keys.append(bar.text_for(o, BuildTool.Mode.BUILD, "common_house"))
	for i in keys.size():
		check(keys[i] != "", "step %d has a sentence" % i)
		for j in i:
			check(keys[i] != keys[j], "steps %d and %d say different things" % [j, i])
	bar.free()


# --- The advisor looks at the town (phase 10d) ---

func _rice(c: City) -> void:
	c.build_road(c.entrance, Vector2i(38, 10))
	c.objectives._begin(_goal("rice"))
	c.objectives.guide.mark_dirty()


func _settle(c: City, origin: Vector2i) -> void:
	c.place_building("common_house", origin)
	c.building_at(origin)["tier"] = 1
	c.houses.clear_cache()
	c.objectives.guide.mark_dirty()


func test_food_lasts_longer() -> void:
	check_eq(Balance.FOOD_PORTIONS_PER_LOAD, 460, "a load feeds 40 people for 11-12 days (30 % less eating)")


func test_a_market_without_workers_asks_for_houses() -> void:
	var c := _valley()
	_rice(c)
	c.labor.extra_workers = 8
	c.place_building("granary", Vector2i(10, 11))
	c.place_building("market", Vector2i(14, 11))
	var g = c.objectives.guide
	var s: Dictionary = g.step()
	check_eq(s["kind"], "workers", "the advisor sees the Market idle")
	check_eq(s["building"], "market", "it names the Market")
	check_eq(s["have"], 8, "the town has 8 workers")
	check_eq(s["need"], 14, "the buildings need 14")
	check_eq(s["houses"], 3, "three more Choga Huts bring them (2.4 workers each)")
	check_eq(g.buttons()[0], "common_house", "the Common House button glows first")
	check_eq(g.spot()["type"], "common_house", "the arrow shows a house lot")
	c.labor.extra_workers = 100
	c._recompute_labor()
	g.mark_dirty()
	check(g.step()["kind"] != "workers", "enough workers: the advisor moves on")


func test_settlers_on_the_way_are_counted() -> void:
	var c := _valley()
	_rice(c)
	for x in [6, 9, 12, 15, 18, 21]:
		c.place_building("common_house", Vector2i(x, 11)) # vacant lots: settlers are coming
	c.place_building("granary", Vector2i(24, 11))
	var w: Dictionary = c.objectives.guide.workers_problem()
	check_eq(w["building"], "granary", "the Granary waits for workers")
	check_eq(w["houses"], 0, "but six lots bring 14 workers: no more houses needed, just wait")
	check_eq(c.objectives.guide.step()["kind"], "build", "meanwhile the advisor shows what else to build")


func test_the_goal_says_how_many_more_houses() -> void:
	var c := _land()
	_rice(c)
	c.labor.extra_workers = 1000
	for x in [6, 9, 12, 15, 18, 21]:
		_settle(c, Vector2i(x, 8))
	for x in [7, 13, 19]:
		c.place_building("well", Vector2i(x, 7))
	c.build_road(Vector2i(20, 10), Vector2i(20, 12))
	c.build_road(Vector2i(20, 12), Vector2i(26, 12))
	for spot in [["rice_paddy", Vector2i(20, 13)], ["rice_paddy", Vector2i(24, 13)], ["granary", Vector2i(26, 7)], ["market", Vector2i(14, 11)]]:
		check_eq(c.place_building(spot[0], spot[1]), "", "%s built" % spot[0])
	for id: int in c.houses.state:
		c.houses.state[id]["food"] = 100 # fed: the advisor looks only at the houses
	var g = c.objectives.guide
	g.mark_dirty()
	var s: Dictionary = g.step()
	check_eq(s["kind"], "build", "next: houses (%s)" % s)
	check_eq(s.get("type"), "common_house", "a house")
	check_eq(s.get("goal_houses"), 10, "the goal needs 10 houses")
	check_eq(s.get("have"), 6, "the town has 6")
	check_eq(s.get("more"), 4, "build 4 more")
	var lots := 0
	for m: Dictionary in g.ghosts():
		lots += 1 if m["type"] == "common_house" else 0
	check_eq(lots, 4, "four gold lots")


func test_houses_without_water_get_a_well() -> void:
	var c := _valley()
	c.build_road(c.entrance, Vector2i(38, 10))
	_days(c, 1)
	_settle(c, Vector2i(20, 11))
	_settle(c, Vector2i(22, 11))
	var s: Dictionary = c.objectives.guide.step()
	check_eq(s["kind"], "water", "the advisor sees houses without water")
	check_eq(s["houses"], 2, "two of them")
	check_eq(c.place_building("well", s["origin"]), "", "the Well fits its mark")
	c.houses.clear_cache()
	c.objectives.guide.mark_dirty()
	check(c.houses.is_met(c.building_at(Vector2i(20, 11)), "water"), "and it waters them")
	check(c.objectives.guide.step()["kind"] != "water", "the advisor moves on")


func test_houses_far_from_the_market_get_another() -> void:
	var c := _valley()
	_rice(c)
	c.labor.extra_workers = 1000
	c.place_building("market", Vector2i(4, 11))
	_settle(c, Vector2i(34, 11))
	c.place_building("well", Vector2i(34, 9))
	var s: Dictionary = c.objectives.guide.step()
	check_eq(s["kind"], "food", "a house no vendor reaches")
	check_eq(s["houses"], 1, "one house")
	check(absi(s["origin"].x - 34) <= 10, "another Market near it (%s)" % s["origin"])


func test_not_enough_silver_is_said() -> void:
	var c := _valley()
	c.build_road(c.entrance, Vector2i(38, 10))
	_days(c, 1)
	c.treasury = 0
	c.objectives.guide.mark_dirty()
	check(c.objectives.guide.step().get("silver", false), "the next house costs more than the treasury")


## Six houses the Market reaches, all hungry, two connected paddies and a Granary up the street.
func _hungry_town() -> City:
	var c := _land()
	_rice(c)
	c.labor.extra_workers = 1000
	for x in [6, 9, 12, 15, 18, 21]:
		_settle(c, Vector2i(x, 8))
	for x in [7, 13, 19]:
		c.place_building("well", Vector2i(x, 7))
	c.build_road(Vector2i(20, 10), Vector2i(20, 12))
	c.build_road(Vector2i(20, 12), Vector2i(26, 12))
	c.place_building("rice_paddy", Vector2i(20, 13))
	c.place_building("rice_paddy", Vector2i(24, 13))
	c.place_building("granary", Vector2i(34, 7))
	c.place_building("market", Vector2i(14, 11))
	c.objectives.guide.mark_dirty()
	return c


func test_hungry_houses_ask_for_more_fields() -> void:
	var c := _hungry_town()
	var g = c.objectives.guide
	check(g.rice_problem().is_empty(), "the fields have not grown anything yet: no word about more fields")
	c.economy.produced["rice"] = 10 # they have grown, the rice is eaten, houses still hungry
	g.mark_dirty()
	var s: Dictionary = c.objectives.guide.step()
	check_eq(s["kind"], "rice_more", "hungry, nothing waits at the fields: too few fields (%s)" % s)
	check_eq(s.get("hungry"), 6, "six hungry houses")
	check_eq(s.get("type"), "rice_paddy", "the Rice Paddy button and a gold mark")
	check(c.objectives.guide.buttons().has("rice_paddy"), "the Rice Paddy button glows")


func test_rice_waiting_far_from_the_granary_asks_for_a_closer_one() -> void:
	var c := _hungry_town()
	c.economy.add(c.building_at(Vector2i(20, 13))["id"], "rice", 1)
	c.objectives.guide.mark_dirty()
	var s: Dictionary = c.objectives.guide.step()
	check_eq(s["kind"], "rice_far", "rice waits at the field: the Granary is far (%s)" % s)
	check(s.get("trip_days", 0) > 12, "the round trip is longer than the rice takes to grow")
	check_eq(s.get("type"), "granary", "a Granary")
	check(absi(s["origin"].x - 22) + absi(s["origin"].y - 13) < absi(34 - 22) + absi(7 - 13), "closer to the fields than the old one (%s)" % s["origin"])


func test_a_wandering_vendor_gets_a_guardian_post() -> void:
	var c := _valley()
	_rice(c)
	c.labor.extra_workers = 1000
	c.objectives.unlocked["jangseung"] = true
	for x in [6, 9]:
		_settle(c, Vector2i(x, 11))
		c.houses.state[c.building_at(Vector2i(x, 11))["id"]]["food"] = 100
	c.place_building("well", Vector2i(8, 13))
	c.place_building("market", Vector2i(12, 11))
	var g = c.objectives.guide
	g.mark_dirty()
	var s: Dictionary = g.step()
	check_eq(s["kind"], "stray", "the vendor walks the empty road east (%s)" % s)
	check(s.get("tiles", 0) >= 6, "many tiles with nobody")
	check_eq(s.get("type"), "jangseung", "Guardian Posts")
	var before: Dictionary = Coverage.walker_roads(c.grid, Vector2i(12, 11), Vector2i(3, 3))
	check_eq(c.place_building("jangseung", s["origin"]), "", "the post fits its mark")
	var after: Dictionary = Coverage.walker_roads(c.grid, Vector2i(12, 11), Vector2i(3, 3))
	check(after.size() < before.size(), "the vendor's area is shorter")
	for t: Vector2i in before:
		if not c.services._houses_near(t).is_empty():
			check(after.has(t) or t == s["origin"], "every street with houses is still walked (%s)" % t)
	g.mark_dirty()
	check(g.step()["kind"] != "stray", "the advisor moves on")


func test_no_new_markets_while_workers_are_short() -> void:
	var c := _hungry_town()
	c.economy.produced["rice"] = 10
	c.labor.extra_workers = 0
	c._recompute_labor()
	var g = c.objectives.guide
	g.mark_dirty()
	var s: Dictionary = g.step()
	check(s["kind"] not in ["rice_more", "food"], "no more fields or Markets while workers are short (%s)" % s)
	for m: Dictionary in g.ghosts():
		check(m["type"] != "market" and m["type"] != "rice_paddy", "no gold mark for a building nobody could work in")
