extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")


## A city on a flat 24x24 grass map, so tests control the terrain.
func _flat_city() -> City:
	var c := City.new()
	c.grid = Grid.new(24, 24)
	return c


func test_building_costs_silver() -> void:
	var c := _flat_city()
	check_eq(c.place_building("granary", Vector2i(2, 2)), "", "granary placed")
	check_eq(c.treasury, Balance.START_TREASURY - 60, "60 Silver paid")
	check_eq(c.buildings.count(), 1, "one building")
	check_eq(c.building_at(Vector2i(4, 4))["type"], "granary", "covers its 3x3 footprint")
	check(c.building_at(Vector2i(5, 5)).is_empty(), "nothing outside it")


func test_not_enough_silver_changes_nothing() -> void:
	var c := _flat_city()
	c.treasury = 59
	check_eq(c.place_building("granary", Vector2i(2, 2)), "REASON_NOT_ENOUGH_SILVER", "refused")
	check_eq(c.treasury, 59, "treasury unchanged")
	check_eq(c.buildings.count(), 0, "nothing built")
	check(not c.grid.is_occupied(Vector2i(2, 2)), "tiles still free")


func test_rules_give_reasons() -> void:
	var c := _flat_city()
	check_eq(c.check_building("rice_paddy", Vector2i(1, 1)), "REASON_NEEDS_FERTILE_PLAIN", "rice paddy on grass")
	check_eq(c.check_building("salt_pans", Vector2i(1, 1)), "REASON_NEEDS_SHORE", "salt pans away from shore")
	check_eq(c.check_building("clay_pit", Vector2i(1, 1)), "REASON_NEEDS_ROCKY_HILL", "clay pit on grass")
	check_eq(c.check_building("market", Vector2i(22, 22)), "REASON_OUT_OF_BOUNDS", "past the edge")
	c.place_building("market", Vector2i(5, 5))
	check_eq(c.check_building("well", Vector2i(6, 6)), "REASON_OCCUPIED", "on top of the market")
	c.grid.set_terrain(Vector2i(10, 10), Terrain.RIVER)
	check_eq(c.check_building("granary", Vector2i(9, 9)), "REASON_BAD_TERRAIN", "river under a granary")
	check_eq(c.check_building("road", Vector2i(0, 0)), "REASON_UNKNOWN_BUILDING", "roads use the road command")


func test_every_reason_has_text() -> void:
	var texts := preload("res://scripts/view/text_loader.gd").read_csv("res://data/text/en.csv")
	var keys := ["REASON_NOT_ENOUGH_SILVER", "REASON_OUT_OF_BOUNDS", "REASON_OCCUPIED", "REASON_BAD_TERRAIN", "REASON_UNKNOWN_BUILDING", "REASON_NEEDS_ROAD"]
	for b in Buildings.MVP_BUILDINGS:
		keys.append(Buildings.terrain_reason(b["id"]))
		if b.has("hint_key"):
			keys.append(b["hint_key"])
		if b.has("near_terrain"):
			keys.append(b["near_terrain"]["reason_key"])
	for key in keys:
		check(texts.get(key, "") != "", "%s has English text" % key)


func test_rotation_turns_the_footprint() -> void:
	var c := _flat_city()
	check_eq(c.place_building("onggi_kiln", Vector2i(2, 2), 1), "", "kiln turned east")
	var kiln := c.building_at(Vector2i(2, 2))
	check_eq(kiln["size"], Vector2i(2, 3), "3x2 becomes 2x3")
	check(c.grid.is_occupied(Vector2i(3, 4)), "south end occupied")
	check(not c.grid.is_occupied(Vector2i(4, 2)), "old east end free")
	check_eq(Grid.rotated_size(Vector2i(3, 2), 2), Vector2i(3, 2), "half turn keeps size")


func test_door_follows_rotation() -> void:
	var t := Balance.TILE_SIZE
	var origin := Vector2i(0, 0)
	var size := Vector2i(2, 2)
	check_eq(Grid.door_world(origin, size, 0), Vector3(t, 0, 2 * t), "south")
	check_eq(Grid.door_world(origin, size, 1), Vector3(2 * t, 0, t), "east")
	check_eq(Grid.door_world(origin, size, 2), Vector3(t, 0, 0), "north")
	check_eq(Grid.door_world(origin, size, 3), Vector3(0, 0, t), "west")


func test_new_house_is_a_vacant_lot() -> void:
	var c := _flat_city()
	c.place_building("common_house", Vector2i(3, 3))
	check_eq(c.building_at(Vector2i(3, 3))["tier"], 0, "tier 0 = vacant lot")
	c.place_building("well", Vector2i(8, 8))
	check_eq(c.building_at(Vector2i(8, 8))["tier"], 1, "other buildings are tier 1")


func test_demolish_frees_tiles_without_refund() -> void:
	var c := _flat_city()
	c.place_building("storehouse", Vector2i(4, 4))
	var removed := []
	c.building_removed.connect(func(i: Dictionary) -> void: removed.append(i["type"]))
	var silver := c.treasury
	check_eq(c.demolish(Vector2i(5, 5), Vector2i(5, 5)), 1, "one click removes the whole building")
	check_eq(removed, ["storehouse"], "removal signal")
	check(not c.grid.is_occupied(Vector2i(4, 4)) and not c.grid.is_occupied(Vector2i(6, 6)), "all tiles free")
	check_eq(c.treasury, silver, "no Silver returned")
	check_eq(c.demolish(Vector2i(5, 5), Vector2i(5, 5)), 0, "nothing left to remove")


func test_demolish_area() -> void:
	var c := _flat_city()
	c.place_building("well", Vector2i(2, 2))
	c.place_building("well", Vector2i(4, 2))
	c.build_road(Vector2i(2, 4), Vector2i(6, 4))
	check_eq(c.demolish(Vector2i(6, 4), Vector2i(2, 2)), 7, "two wells and five road tiles")
	check_eq(c.buildings.count(), 0, "no buildings left")
	check(not c.grid.is_road(Vector2i(4, 4)), "road removed")


func test_woodcutter_needs_forest_within_2_tiles() -> void:
	var c := _flat_city()
	c.grid.set_terrain(Vector2i(10, 5), Terrain.FOREST)
	# Footprint x 6..7: forest at x=10 is 3 tiles away.
	check_eq(c.check_building("woodcutter", Vector2i(6, 5)), "REASON_NEEDS_FOREST_NEARBY", "3 tiles is too far")
	# Footprint x 7..8: forest at x=10 is 2 tiles away.
	check_eq(c.check_building("woodcutter", Vector2i(7, 5)), "", "2 tiles is fine")


func test_road_access_warning() -> void:
	var c := _flat_city()
	c.place_building("market", Vector2i(5, 5))
	var market := c.building_at(Vector2i(5, 5))
	check(not c.has_road_access(market), "no road yet")
	c.build_road(Vector2i(4, 4), Vector2i(4, 9))
	check(c.has_road_access(market), "road along the west side")
	c.demolish(Vector2i(4, 4), Vector2i(4, 9))
	check(not c.has_road_access(market), "road gone again")


func test_same_commands_same_city() -> void:
	var a := City.new(Balance.DEFAULT_MAP_SEED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ids := Buildings.ids()
	for i in 300:
		var t := Vector2i(rng.randi_range(0, 63), rng.randi_range(0, 63))
		match rng.randi_range(0, 3):
			0:
				a.build_road(t, t + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8)))
			1:
				a.demolish(t, t + Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2)))
			_:
				a.place_building(ids[rng.randi_range(0, ids.size() - 1)], t, rng.randi_range(0, 3))
	check(a.buildings.count() > 10, "the random city has buildings (%d)" % a.buildings.count())
	var b := City.new(Balance.DEFAULT_MAP_SEED)
	b.replay(a.command_log, a.clock.tick)
	check(a.grid.occupant == b.grid.occupant, "same tiles")
	check_eq(b.treasury, a.treasury, "same treasury")
	check_eq(b.buildings.count(), a.buildings.count(), "same buildings")
