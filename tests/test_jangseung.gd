extends "res://tests/test_base.gd"
## Jangseung is a roadblock (docs/koncept.md, "Šetači"): it stands on a road,
## turns back roaming walkers and lets destination walkers pass.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")


func _city_with_street() -> City:
	var c := City.new()
	c.grid = Grid.new(40, 24)
	c.build_road(Vector2i(0, 10), Vector2i(30, 10))
	return c


func test_needs_a_road() -> void:
	var c := _city_with_street()
	check_eq(c.check_building("jangseung", Vector2i(5, 5)), "REASON_NEEDS_ROAD", "not on grass")
	check_eq(c.place_building("jangseung", Vector2i(5, 10)), "", "on the road")
	check_eq(c.treasury, Balance.START_TREASURY - 31 * 2 - 10, "road and 10 Silver paid")


func test_tile_stays_a_road() -> void:
	var c := _city_with_street()
	c.place_building("jangseung", Vector2i(5, 10))
	check(c.grid.is_road(Vector2i(5, 10)), "still a road for destination walkers")
	check(c.grid.is_blocked(Vector2i(5, 10)), "but blocked for roaming walkers")
	check_eq(c.building_at(Vector2i(5, 10))["type"], "jangseung", "found on its tile")
	check(c.has_road_access(c.building_at(Vector2i(5, 10))), "never warns about road access")
	check_eq(c.check_building("jangseung", Vector2i(5, 10)), "REASON_OCCUPIED", "one per tile")


func test_turns_back_roaming_walkers() -> void:
	var c := _city_with_street()
	var before := Coverage.walker_roads(c.grid, Vector2i(0, 11), Vector2i.ONE)
	check(before.has(Vector2i(20, 10)), "without a Jangseung the walker goes far")
	c.place_building("jangseung", Vector2i(8, 10))
	var after := Coverage.walker_roads(c.grid, Vector2i(0, 11), Vector2i.ONE)
	check(after.has(Vector2i(7, 10)), "reaches the Jangseung")
	check(not after.has(Vector2i(8, 10)) and not after.has(Vector2i(9, 10)), "does not pass it")
	check_eq(after.size(), 8, "only tiles 0..7")


func test_walker_starting_on_the_far_side_is_not_affected() -> void:
	var c := _city_with_street()
	c.place_building("jangseung", Vector2i(8, 10))
	var roads := Coverage.walker_roads(c.grid, Vector2i(12, 11), Vector2i.ONE)
	check(roads.has(Vector2i(9, 10)) and roads.has(Vector2i(20, 10)), "serves its own side")
	check(not roads.has(Vector2i(7, 10)), "cannot cross to the other side")


func test_demolish_removes_statue_first_then_road() -> void:
	var c := _city_with_street()
	c.place_building("jangseung", Vector2i(5, 10))
	check_eq(c.demolish(Vector2i(5, 10), Vector2i(5, 10)), 1, "first click removes the Jangseung")
	check(c.grid.is_road(Vector2i(5, 10)) and not c.grid.is_blocked(Vector2i(5, 10)), "road stays")
	check_eq(c.buildings.count(), 0, "statue gone")
	check_eq(c.demolish(Vector2i(5, 10), Vector2i(5, 10)), 1, "second click removes the road")
	check(not c.grid.is_road(Vector2i(5, 10)), "road gone")


func test_demolish_area_with_jangseung_inside() -> void:
	var c := _city_with_street()
	c.place_building("jangseung", Vector2i(5, 10))
	check_eq(c.demolish(Vector2i(4, 10), Vector2i(6, 10)), 3, "two road tiles and the statue")
	check(c.grid.is_road(Vector2i(5, 10)), "the statue's road tile stays")
