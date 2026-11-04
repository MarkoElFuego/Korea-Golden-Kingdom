extends "res://tests/test_base.gd"
## Simulation speed with hundreds of carriers (CLAUDE.md: 400 walkers at 60 FPS).
## At 3x the game runs 30 ticks per second, so a tick must stay well under 33 ms;
## the budget here leaves most of the frame to drawing.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const BigCity = preload("res://scripts/sim/big_city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const TICK_BUDGET_MS := 3.0


func test_400_carriers_tick_fast() -> void:
	var c := City.new()
	c.grid = Grid.new(128, 96)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 10000000
	c.labor.extra_workers = 100000
	# Streets every 4 rows, one north-south avenue every 32 columns.
	for y in range(0, 96, 4):
		c.build_road(Vector2i(0, y), Vector2i(127, y))
	for x in range(0, 128, 32):
		c.build_road(Vector2i(x, 0), Vector2i(x, 95))
	# Rice paddies between the streets, a Granary on every block.
	for y in range(1, 96, 4):
		for x in range(1, 125, 3):
			if x % 32 >= 29 or x % 32 == 0:
				continue
			if (x / 3) % 9 == 4:
				c.place_building("granary", Vector2i(x, y))
			else:
				c.place_building("rice_paddy", Vector2i(x, y))
	check(c.buildings.count() > 800, "big city (%d buildings)" % c.buildings.count())

	# Let carriers set out.
	for i in 8 * Balance.TICKS_PER_DAY + 20:
		c.clock.step()
	check(c.carriers.count() >= 400, "at least 400 carriers walking (%d)" % c.carriers.count())

	var ticks := 300
	var start := Time.get_ticks_usec()
	for i in ticks:
		c.clock.step()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	print("        %d buildings, %d carriers: %.2f ms per tick" % [c.buildings.count(), c.carriers.count(), ms])
	check(ms < TICK_BUDGET_MS, "tick takes %.2f ms (budget %.1f ms)" % [ms, TICK_BUDGET_MS])


## A town of houses with Markets and Seonangdangs: hundreds of roaming walkers serving
## the houses they pass, settlers moving in, buyers fetching rice.
func test_400_service_walkers_tick_fast() -> void:
	var c := City.new()
	c.grid = Grid.new(128, 96)
	c.treasury = 10000000
	c.labor.extra_workers = 100000
	for y in range(0, 96, 4):
		c.build_road(Vector2i(0, y), Vector2i(127, y))
	for x in range(0, 128, 16):
		c.build_road(Vector2i(x, 0), Vector2i(x, 95))
	c.set_entrance(Vector2i(0, 0))
	var slot := 0
	for y in range(1, 96, 4):
		for x in range(1, 125, 3):
			slot += 1
			match slot % 10:
				0:
					c.place_building("market", Vector2i(x, y))
					var id: int = c.building_at(Vector2i(x, y)).get("id", 0)
					if id != 0:
						c.economy.add(id, "rice", 8)
				5:
					c.place_building("seonangdang", Vector2i(x, y))
				7:
					c.place_building("granary", Vector2i(x, y))
					var id: int = c.building_at(Vector2i(x, y)).get("id", 0)
					if id != 0:
						c.economy.add(id, "rice", 32)
				_:
					c.place_building("common_house", Vector2i(x, y))
	for i in 30 * Balance.TICKS_PER_DAY:
		c.clock.step()
	check(c.services.count() >= 400, "at least 400 service walkers (%d)" % c.services.count())
	var ticks := 300
	var start := Time.get_ticks_usec()
	for i in ticks:
		c.clock.step()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	print("        %d buildings, %d service walkers, %d settlers: %.2f ms per tick" % [
		c.buildings.count(), c.services.count(), c.settlers.count(), ms])
	check(ms < TICK_BUDGET_MS, "tick takes %.2f ms (budget %.1f ms)" % [ms, TICK_BUDGET_MS])


## The big city scene (scripts/sim/big_city.gd): 3,000+ people, every walker kind, and
## saving and loading it stays quick.
func test_big_city_ticks_and_saves_fast() -> void:
	var c := BigCity.build()
	check(c.population() >= 3000, "at least 3,000 residents (%d)" % c.population())
	for i in 30 * Balance.TICKS_PER_DAY:
		c.clock.step()
	var walkers := c.carriers.count() + c.settlers.count() + c.services.count()
	check(walkers >= 400, "at least 400 walkers (%d)" % walkers)
	var ticks := 300
	var start := Time.get_ticks_usec()
	for i in ticks:
		c.clock.step()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	start = Time.get_ticks_usec()
	var bytes := SaveGame.pack(c)
	var save_ms := (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	var loaded := SaveGame.city_from_bytes(bytes)
	var load_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("        big city: %d people, %d walkers: %.2f ms per tick; save %.0f ms (%d KB), load %.0f ms" % [
		c.population(), walkers, ms, save_ms, bytes.size() / 1024, load_ms])
	check(ms < TICK_BUDGET_MS, "tick takes %.2f ms (budget %.1f ms)" % [ms, TICK_BUDGET_MS])
	check_eq(loaded["error"], "", "the big city loads")
	check(save_ms + load_ms < 1000.0, "save and load take under a second (%.0f ms)" % (save_ms + load_ms))


## A dokkaebi night in the big city (phase 9): choosing the storage and the night itself
## stay cheap.
func test_big_city_dokkaebi_night_is_fast() -> void:
	var c := BigCity.build()
	for i in 10 * Balance.TICKS_PER_DAY:
		c.clock.step()
	var start := Time.get_ticks_usec()
	c.clock.tick = Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR * Balance.TICKS_PER_DAY
	c.dokkaebi.season_start()
	var season_ms := (Time.get_ticks_usec() - start) / 1000.0
	if c.dokkaebi.raids.is_empty():
		for instance: Dictionary in c.buildings.all():
			if instance["type"] == "granary" and c.economy.total_stock(instance["id"]) > 0 and c.dokkaebi.plan_raid(instance):
				break
	check_eq(c.dokkaebi.raids.size(), 1, "dokkaebi come for a storage")
	for i in Balance.DOKKAEBI_WARNING_DAYS * Balance.TICKS_PER_DAY:
		c.clock.step()
	check(c.dokkaebi.is_night(), "night falls on the big city")
	var ticks := 100
	start = Time.get_ticks_usec()
	for i in ticks:
		c.clock.step()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	print("        big city dokkaebi: season check %.1f ms, %.2f ms per night tick" % [season_ms, ms])
	check(season_ms < 50.0, "the season check is quick (%.1f ms)" % season_ms)
	check(ms < TICK_BUDGET_MS, "night tick takes %.2f ms (budget %.1f ms)" % [ms, TICK_BUDGET_MS])
