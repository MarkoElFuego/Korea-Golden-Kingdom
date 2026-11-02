extends RefCounted
## Which tiles a building reaches: a fixed radius (Well) or the streets its roaming
## walker can walk (Market, Seonangdang). Also road access and "terrain nearby" rules.
## Results are Dictionaries used as sets: {Vector2i: true}.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## Tiles within `tiles` of the footprint (square ring around it, footprint included).
static func radius_tiles(grid: Grid, origin: Vector2i, size: Vector2i, tiles: int) -> Dictionary:
	var result := {}
	for y in range(origin.y - tiles, origin.y + size.y + tiles):
		for x in range(origin.x - tiles, origin.x + size.x + tiles):
			var t := Vector2i(x, y)
			if grid.in_bounds(t):
				result[t] = true
	return result


## Road tiles touching the footprint's sides (not corners).
static func adjacent_roads(grid: Grid, origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t in _edge_neighbors(origin, size):
		if grid.is_road(t):
			result.append(t)
	return result


static func has_road_access(grid: Grid, origin: Vector2i, size: Vector2i) -> bool:
	return not adjacent_roads(grid, origin, size).is_empty()


## Road tiles a roaming walker can reach: up to WALKER_MAX_ROAD_TILES steps along roads,
## starting from the roads next to the building (those count as the first step).
## A Jangseung turns roaming walkers back, so they never step onto its tile.
static func walker_roads(grid: Grid, origin: Vector2i, size: Vector2i) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for t in adjacent_roads(grid, origin, size):
		if grid.is_blocked(t):
			continue
		dist[t] = 1
		queue.append(t)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		if dist[t] >= Balance.WALKER_MAX_ROAD_TILES:
			continue
		for d in DIRS:
			var n := t + d
			if grid.is_road(n) and not grid.is_blocked(n) and not dist.has(n):
				dist[n] = dist[t] + 1
				queue.append(n)
	var result := {}
	for t in dist:
		result[t] = true
	return result


## Tiles served by a roaming walker: every tile within WALKER_SERVICE_RANGE of a reachable road.
static func walker_tiles(grid: Grid, origin: Vector2i, size: Vector2i) -> Dictionary:
	var result := {}
	var r := Balance.WALKER_SERVICE_RANGE
	for road: Vector2i in walker_roads(grid, origin, size):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := road + Vector2i(dx, dy)
				if grid.in_bounds(t):
					result[t] = true
	return result


## Tiles a building of this data would cover. `data` is a buildings.gd entry.
static func for_building(grid: Grid, data: Dictionary, origin: Vector2i, size: Vector2i) -> Dictionary:
	var coverage: Dictionary = data.get("coverage", {})
	match coverage.get("type", ""):
		"radius":
			return radius_tiles(grid, origin, size, coverage["tiles"])
		"walker":
			return walker_tiles(grid, origin, size)
	return {}


## True when `terrain` lies within `tiles` of the footprint (outside it).
static func terrain_near(grid: Grid, origin: Vector2i, size: Vector2i, terrain: int, tiles: int) -> bool:
	for t: Vector2i in radius_tiles(grid, origin, size, tiles):
		if grid.get_terrain(t) == terrain:
			return true
	return false


static func _edge_neighbors(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(origin.x, origin.x + size.x):
		result.append(Vector2i(x, origin.y - 1))
		result.append(Vector2i(x, origin.y + size.y))
	for y in range(origin.y, origin.y + size.y):
		result.append(Vector2i(origin.x - 1, y))
		result.append(Vector2i(origin.x + size.x, y))
	return result
