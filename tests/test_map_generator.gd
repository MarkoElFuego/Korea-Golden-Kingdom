extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")

const W := Balance.MAP_WIDTH
const H := Balance.MAP_HEIGHT
const SEEDS: Array[int] = [Balance.DEFAULT_MAP_SEED, 1, 42, 777, 123456]


func _grid(map_seed: int) -> Grid:
	return Grid.new(W, H, MapGenerator.generate(map_seed, W, H))


func test_same_seed_same_map() -> void:
	for s in SEEDS:
		check(MapGenerator.generate(s, W, H) == MapGenerator.generate(s, W, H), "seed %d gives the same map" % s)


func test_different_seed_different_map() -> void:
	check(MapGenerator.generate(1, W, H) != MapGenerator.generate(2, W, H), "seeds 1 and 2 differ")


func test_map_size() -> void:
	check_eq(MapGenerator.generate(1, W, H).size(), W * H, "one terrain value per tile")


func test_river_flows_from_west_edge_to_sea() -> void:
	for s in SEEDS:
		var g := _grid(s)
		var start: Array[Vector2i] = []
		for y in H:
			if g.get_terrain(Vector2i(0, y)) == Terrain.RIVER:
				start.append(Vector2i(0, y))
		check(not start.is_empty(), "seed %d: river touches the west edge" % s)
		check(_river_reaches_sea(g, start), "seed %d: river connects to the sea" % s)
		var river_rows := 0
		var south_rows := 0
		for y in H:
			for x in W:
				if g.get_terrain(Vector2i(x, y)) == Terrain.RIVER:
					river_rows += 1
					if y >= H / 2:
						south_rows += 1
		check_eq(south_rows, river_rows, "seed %d: the whole river is in the south half" % s)


func _river_reaches_sea(g: Grid, start: Array[Vector2i]) -> bool:
	var seen := {}
	var queue: Array[Vector2i] = start.duplicate()
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		if seen.has(t):
			continue
		seen[t] = true
		for d in dirs:
			var n := t + d
			if not g.in_bounds(n):
				continue
			var terrain := g.get_terrain(n)
			if terrain == Terrain.SEA:
				return true
			if terrain == Terrain.RIVER and not seen.has(n):
				queue.append(n)
	return false


func test_sea_is_in_south_east_corner() -> void:
	for s in SEEDS:
		var g := _grid(s)
		check_eq(g.get_terrain(Vector2i(W - 1, H - 1)), Terrain.SEA, "seed %d: south-east corner is sea" % s)
		for y in H:
			for x in W:
				if g.get_terrain(Vector2i(x, y)) == Terrain.SEA and (x < W / 2 or y < H / 2):
					check(false, "seed %d: sea outside the south-east quarter at %d,%d" % [s, x, y])
					return


func test_shore_exists_along_sea() -> void:
	for s in SEEDS:
		var g := _grid(s)
		check(g.count_terrain(Terrain.SHORE) > 0, "seed %d: there is Shore" % s)
		check(_has_spot(g, "salt_pans"), "seed %d: Salt Pans (3x3 on Shore) fit somewhere" % s)


func test_mountains_are_in_the_north() -> void:
	for s in SEEDS:
		var g := _grid(s)
		var total := g.count_terrain(Terrain.MOUNTAIN)
		check(total > W * 3, "seed %d: enough mountains (%d tiles)" % [s, total])
		for x in W:
			check_eq(g.get_terrain(Vector2i(x, 0)), Terrain.MOUNTAIN, "seed %d: north edge is mountain at x=%d" % [s, x])
		for y in range(H / 3, H):
			for x in W:
				if g.get_terrain(Vector2i(x, y)) == Terrain.MOUNTAIN:
					check(false, "seed %d: mountain outside the north third at %d,%d" % [s, x, y])
					return


func test_ridges_east_and_west() -> void:
	for s in SEEDS:
		var g := _grid(s)
		var west := 0
		var east := 0
		for y in range(H / 4, H / 2):
			for x in 4:
				if g.get_terrain(Vector2i(x, y)) == Terrain.FOREST:
					west += 1
				if g.get_terrain(Vector2i(W - 1 - x, y)) == Terrain.FOREST:
					east += 1
		check(west > 20, "seed %d: forest ridge in the west (%d)" % [s, west])
		check(east > 20, "seed %d: forest ridge in the east (%d)" % [s, east])


func test_fertile_plain_in_the_middle() -> void:
	for s in SEEDS:
		var g := _grid(s)
		check_eq(g.get_terrain(Vector2i(W / 2, int(H * 0.45))), Terrain.FERTILE_PLAIN, "seed %d: center of the valley" % s)
		check(_has_spot(g, "rice_paddy"), "seed %d: a Rice Paddy fits" % s)


func test_some_rocky_hill() -> void:
	for s in SEEDS:
		var g := _grid(s)
		var n := g.count_terrain(Terrain.ROCKY_HILL)
		check(n > 0 and n < W * H / 10, "seed %d: a little Rocky Hill (%d tiles)" % [s, n])
		check(_has_spot(g, "clay_pit"), "seed %d: a Clay Pit fits" % s)


func _has_spot(g: Grid, building_id: String) -> bool:
	var size: Vector2i = Buildings.get_building(building_id)["footprint"]
	var allowed := Buildings.allowed_terrain(building_id)
	for y in H:
		for x in W:
			if g.can_place(Vector2i(x, y), size, allowed):
				return true
	return false
