extends "res://tests/test_base.gd"
## Simulation speed with hundreds of carriers (CLAUDE.md: 400 walkers at 60 FPS).
## At 3x the game runs 30 ticks per second, so a tick must stay well under 33 ms;
## the budget here leaves most of the frame to drawing.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")

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
