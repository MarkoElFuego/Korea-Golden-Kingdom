extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")

var land: Array[int] = [Terrain.GRASS, Terrain.FERTILE_PLAIN, Terrain.SHORE]


func test_tile_to_world_is_tile_center() -> void:
	var t := Balance.TILE_SIZE
	check_eq(Grid.tile_to_world(Vector2i(0, 0)), Vector3(t * 0.5, 0, t * 0.5), "tile 0,0 center")
	check_eq(Grid.tile_to_world(Vector2i(3, 5)), Vector3(3.5 * t, 0, 5.5 * t), "tile 3,5 center")


func test_world_to_tile_round_trip() -> void:
	for y in 10:
		for x in 10:
			var tile := Vector2i(x, y)
			check_eq(Grid.world_to_tile(Grid.tile_to_world(tile)), tile, "round trip %s" % tile)


func test_world_to_tile_edges() -> void:
	var t := Balance.TILE_SIZE
	check_eq(Grid.world_to_tile(Vector3(0.0, 0, 0.0)), Vector2i(0, 0), "origin is tile 0,0")
	check_eq(Grid.world_to_tile(Vector3(t - 0.001, 0, t - 0.001)), Vector2i(0, 0), "just inside tile 0,0")
	check_eq(Grid.world_to_tile(Vector3(t, 0, t)), Vector2i(1, 1), "edge belongs to next tile")
	check_eq(Grid.world_to_tile(Vector3(-0.1, 0, 2.0)), Vector2i(-1, 0), "west of the map is negative")


func test_footprint_center() -> void:
	var t := Balance.TILE_SIZE
	check_eq(Grid.footprint_center(Vector2i(0, 0), Vector2i(2, 2)), Vector3(t, 0, t), "2x2 center")
	check_eq(Grid.footprint_center(Vector2i(4, 2), Vector2i(3, 2)), Vector3(5.5 * t, 0, 3 * t), "3x2 center")


func test_footprint_fits_on_empty_grass() -> void:
	var g := Grid.new(10, 10)
	check(g.can_place(Vector2i(0, 0), Vector2i(3, 3), land), "3x3 at corner")
	check(g.can_place(Vector2i(7, 7), Vector2i(3, 3), land), "3x3 touching south-east edge")


func test_footprint_out_of_bounds() -> void:
	var g := Grid.new(10, 10)
	check_eq(g.check_footprint(Vector2i(8, 8), Vector2i(3, 3), land), "out_of_bounds", "past the south-east edge")
	check_eq(g.check_footprint(Vector2i(-1, 0), Vector2i(2, 2), land), "out_of_bounds", "past the west edge")
	check_eq(g.check_footprint(Vector2i(0, -1), Vector2i(1, 1), land), "out_of_bounds", "past the north edge")


func test_footprint_overlap() -> void:
	var g := Grid.new(10, 10)
	check(g.occupy(Vector2i(2, 2), Vector2i(2, 2), 1, land), "first building placed")
	check_eq(g.check_footprint(Vector2i(3, 3), Vector2i(2, 2), land), "occupied", "overlap by one tile")
	check(g.can_place(Vector2i(4, 2), Vector2i(2, 2), land), "right next to it is free")
	check(not g.occupy(Vector2i(1, 1), Vector2i(3, 3), 2, land), "occupy refuses overlap")
	check(not g.is_occupied(Vector2i(1, 1)), "failed occupy changes nothing")
	g.vacate(Vector2i(2, 2), Vector2i(2, 2))
	check(g.can_place(Vector2i(3, 3), Vector2i(2, 2), land), "free again after vacate")


func test_footprint_forbidden_terrain() -> void:
	var g := Grid.new(10, 10)
	g.set_terrain(Vector2i(5, 5), Terrain.RIVER)
	check_eq(g.check_footprint(Vector2i(4, 4), Vector2i(2, 2), land), "terrain", "river under the footprint")
	g.set_terrain(Vector2i(1, 1), Terrain.MOUNTAIN)
	check_eq(g.check_footprint(Vector2i(1, 1), Vector2i(1, 1), land), "terrain", "mountain")
	var only_plain: Array[int] = [Terrain.FERTILE_PLAIN]
	check_eq(g.check_footprint(Vector2i(7, 7), Vector2i(2, 2), only_plain), "terrain", "rice paddy needs fertile plain")


func test_default_buildable_terrain() -> void:
	check(Terrain.is_buildable(Terrain.GRASS), "grass")
	check(Terrain.is_buildable(Terrain.FERTILE_PLAIN), "fertile plain")
	check(Terrain.is_buildable(Terrain.SHORE), "shore")
	for t in [Terrain.RIVER, Terrain.SEA, Terrain.FOREST, Terrain.MOUNTAIN, Terrain.ROCKY_HILL]:
		check(not Terrain.is_buildable(t), "%s is not buildable for ordinary buildings" % Terrain.INFO[t]["id"])
		check(not Terrain.DEFAULT_BUILDABLE.has(t), "%s not in the default list" % Terrain.INFO[t]["id"])
