extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")


func _flat_city(size := 24) -> City:
	var c := City.new()
	c.grid = Grid.new(size, size)
	return c


func test_well_covers_3_tiles_around() -> void:
	var c := _flat_city()
	var tiles := c.coverage_preview("well", Vector2i(10, 10))
	check_eq(tiles.size(), 7 * 7, "7x7 square")
	check(tiles.has(Vector2i(7, 7)) and tiles.has(Vector2i(13, 13)), "corners 3 tiles away")
	check(not tiles.has(Vector2i(6, 10)), "4 tiles away is not covered")


func test_well_coverage_stops_at_map_edge() -> void:
	var c := _flat_city()
	check_eq(c.coverage_preview("well", Vector2i(0, 0)).size(), 4 * 4, "corner well")


func test_walker_needs_a_road() -> void:
	var c := _flat_city()
	check(c.coverage_preview("market", Vector2i(5, 5)).is_empty(), "no road, no walker coverage")


func test_walker_walks_at_most_30_road_tiles() -> void:
	var c := _flat_city(64)
	c.build_road(Vector2i(0, 4), Vector2i(60, 4))
	# Seonangdang at (0, 5), touching the road tile (0, 4).
	var roads := Coverage.walker_roads(c.grid, Vector2i(0, 5), Vector2i.ONE)
	check_eq(roads.size(), Balance.WALKER_MAX_ROAD_TILES, "30 road tiles")
	check(roads.has(Vector2i(29, 4)) and not roads.has(Vector2i(30, 4)), "turns back after 30")


func test_walker_serves_2_tiles_from_road() -> void:
	var c := _flat_city()
	c.build_road(Vector2i(0, 10), Vector2i(10, 10))
	var tiles := c.coverage_preview("seonangdang", Vector2i(0, 11))
	check(tiles.has(Vector2i(5, 8)) and tiles.has(Vector2i(5, 12)), "2 tiles north and south of the road")
	check(not tiles.has(Vector2i(5, 7)) and not tiles.has(Vector2i(5, 13)), "not 3 tiles")


func test_walker_cannot_cross_a_gap() -> void:
	var c := _flat_city()
	c.build_road(Vector2i(0, 10), Vector2i(5, 10))
	c.build_road(Vector2i(7, 10), Vector2i(15, 10))
	var roads := Coverage.walker_roads(c.grid, Vector2i(0, 11), Vector2i.ONE)
	check(roads.has(Vector2i(5, 10)), "own street reached")
	check(not roads.has(Vector2i(7, 10)), "the other street is cut off")


func test_road_access_counts_sides_not_corners() -> void:
	var c := _flat_city()
	c.build_road(Vector2i(4, 4), Vector2i(4, 4))
	check(not Coverage.has_road_access(c.grid, Vector2i(5, 5), Vector2i(2, 2)), "diagonal road does not count")
	c.build_road(Vector2i(5, 4), Vector2i(5, 4))
	check(Coverage.has_road_access(c.grid, Vector2i(5, 5), Vector2i(2, 2)), "road on the north side")
