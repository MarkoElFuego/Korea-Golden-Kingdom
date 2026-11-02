extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")

const ROAD_COST := 2


func _flat_city() -> City:
	var c := City.new()
	c.grid = Grid.new(24, 24)
	return c


func test_l_path_goes_along_the_longer_side_first() -> void:
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)]
	check_eq(Grid.l_path(Vector2i(0, 0), Vector2i(3, 2)), expected, "east, then south")
	var path := Grid.l_path(Vector2i(5, 5), Vector2i(4, 1))
	check_eq(path[1], Vector2i(5, 4), "longer side is north, so north first")
	check_eq(path[-1], Vector2i(4, 1), "ends at the target")
	check_eq(path.size(), 1 + 4 + 1, "one tile per step")


func test_l_path_single_tile_and_straight_line() -> void:
	check_eq(Grid.l_path(Vector2i(2, 2), Vector2i(2, 2)), [Vector2i(2, 2)] as Array[Vector2i], "one tile")
	check_eq(Grid.l_path(Vector2i(2, 2), Vector2i(2, 6)).size(), 5, "straight line")


func test_road_cost_per_tile() -> void:
	var c := _flat_city()
	check_eq(c.plan_road(Vector2i(1, 1), Vector2i(10, 1))["cost"], 10 * ROAD_COST, "preview cost")
	check_eq(c.build_road(Vector2i(1, 1), Vector2i(10, 1)), 10, "ten tiles")
	check_eq(c.treasury, Balance.START_TREASURY - 10 * ROAD_COST, "paid per tile")
	check(c.grid.is_road(Vector2i(5, 1)), "road is on the grid")


func test_existing_road_is_free() -> void:
	var c := _flat_city()
	c.build_road(Vector2i(1, 1), Vector2i(5, 1))
	var silver := c.treasury
	check_eq(c.build_road(Vector2i(1, 1), Vector2i(8, 1)), 3, "only the three new tiles")
	check_eq(c.treasury, silver - 3 * ROAD_COST, "old tiles not paid again")


func test_blocked_tiles_are_skipped() -> void:
	var c := _flat_city()
	c.grid.set_terrain(Vector2i(4, 2), Terrain.RIVER)
	c.place_building("well", Vector2i(6, 2))
	var plan := c.plan_road(Vector2i(1, 2), Vector2i(8, 2))
	check_eq(plan["blocked"], [Vector2i(4, 2), Vector2i(6, 2)] as Array[Vector2i], "river and well block")
	check_eq(c.build_road(Vector2i(1, 2), Vector2i(8, 2)), 6, "the other six are built")
	check(not c.grid.is_road(Vector2i(4, 2)), "no road on the river")
	check_eq(c.building_at(Vector2i(6, 2))["type"], "well", "well still stands")


func test_road_stops_when_silver_runs_out() -> void:
	var c := _flat_city()
	c.treasury = 7
	check_eq(c.build_road(Vector2i(0, 0), Vector2i(9, 0)), 3, "three tiles for 6 Silver")
	check_eq(c.treasury, 1, "1 Silver left")
	check(c.grid.is_road(Vector2i(2, 0)) and not c.grid.is_road(Vector2i(3, 0)), "built from the start of the drag")


func test_roads_changed_signal() -> void:
	var c := _flat_city()
	var calls := [0]
	c.roads_changed.connect(func() -> void: calls[0] += 1)
	c.build_road(Vector2i(0, 0), Vector2i(3, 0))
	c.build_road(Vector2i(0, 0), Vector2i(3, 0)) # nothing new
	c.demolish(Vector2i(0, 0), Vector2i(1, 0))
	check_eq(calls[0], 2, "signal only when roads really change")
