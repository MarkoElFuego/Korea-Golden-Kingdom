extends RefCounted
## Which tiles a building reaches: a fixed radius (Well) or the area its roaming walkers
## keep to (Market, Village Shrine), with the rounds that walk all of that area. Also road
## access and "terrain nearby" rules. Results are Dictionaries used as sets: {Vector2i: true}.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NO_TILE := Vector2i(-1, -1)


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


## The road tile walkers use to enter and leave: the touching road closest to the door.
## Returns Vector2i(-1, -1) when no road touches the building.
static func access_road(grid: Grid, instance: Dictionary) -> Vector2i:
	var door := Grid.door_world(instance["origin"], instance["size"], instance["rotation"])
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t in adjacent_roads(grid, instance["origin"], instance["size"]):
		var d := Grid.tile_to_world(t).distance_squared_to(door)
		if d < best_d - 0.001:
			best_d = d
			best = t
	return best


static func has_road_access(grid: Grid, origin: Vector2i, size: Vector2i) -> bool:
	return not adjacent_roads(grid, origin, size).is_empty()


## The area a building's roaming walkers keep to: road tiles up to WALKER_AREA_ROAD_TILES
## steps along roads from its entrance road (which counts as the first step). Guardian Posts
## (Jangseung) end the area: walkers never step onto their tile.
## {"start": entrance road tile, "parent": {tile: next tile toward start}}, or {} with no road.
static func walker_area(grid: Grid, origin: Vector2i, size: Vector2i, rotation := 0) -> Dictionary:
	var start := access_road(grid, {"origin": origin, "size": size, "rotation": rotation})
	if start == NO_TILE or grid.is_blocked(start):
		start = NO_TILE
		for t in adjacent_roads(grid, origin, size):
			if not grid.is_blocked(t):
				start = t
				break
	if start == NO_TILE:
		return {}
	var dist := {start: 1}
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		if dist[t] >= Balance.WALKER_AREA_ROAD_TILES:
			continue
		for d in DIRS:
			var n := t + d
			if grid.is_road(n) and not grid.is_blocked(n) and not dist.has(n):
				dist[n] = dist[t] + 1
				parent[n] = t
				queue.append(n)
	return {"start": start, "parent": parent}


## Road tiles of the walker area, as a set.
static func walker_roads(grid: Grid, origin: Vector2i, size: Vector2i, rotation := 0) -> Dictionary:
	var result := {}
	for t in walker_area(grid, origin, size, rotation).get("parent", {}):
		result[t] = true
	return result


## Rounds that together walk every street of the area, each about WALKER_ROUND_TILES long:
## [{"path": road tiles from the entrance and back, "serve_end": last index it serves}].
## A walk through the whole area (depth first, in a fixed order) is cut into pieces; a
## round goes to its piece the shortest way inside the area, walks it, and goes home.
static func walker_rounds(area: Dictionary) -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	if area.is_empty():
		return rounds
	var parent: Dictionary = area["parent"]
	var start: Vector2i = area["start"]
	var tour: Array[Vector2i] = [start]
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var t: Vector2i = stack.back()
		var next := NO_TILE
		for d in DIRS:
			var n := t + d
			if parent.has(n) and not seen.has(n):
				next = n
				break
		if next != NO_TILE:
			seen[next] = true
			stack.append(next)
			tour.append(next)
		else:
			stack.pop_back()
			if not stack.is_empty():
				tour.append(stack.back())
	if tour.size() == 1:
		rounds.append({"path": tour, "serve_end": 0})
		return rounds
	var piece := Balance.WALKER_ROUND_TILES
	for first in range(1, tour.size(), piece):
		var part := tour.slice(first, mini(first + piece, tour.size()))
		var path := _from_start(parent, part[0])
		path.append_array(part.slice(1))
		var serve_end := path.size() - 1
		var back := _from_start(parent, part[-1])
		back.reverse()
		path.append_array(back.slice(1))
		rounds.append({"path": path, "serve_end": serve_end})
	return rounds


## Road tiles from the area's entrance to `tile`, inside the area.
static func _from_start(parent: Dictionary, tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [tile]
	while parent[path[-1]] != path[-1]:
		path.append(parent[path[-1]])
	path.reverse()
	return path


## Tiles served by roaming walkers: every tile within WALKER_SERVICE_RANGE of the area's roads.
static func walker_tiles(grid: Grid, origin: Vector2i, size: Vector2i, rotation := 0) -> Dictionary:
	var result := {}
	var r := Balance.WALKER_SERVICE_RANGE
	for road: Vector2i in walker_roads(grid, origin, size, rotation):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := road + Vector2i(dx, dy)
				if grid.in_bounds(t):
					result[t] = true
	return result


## Tiles a building of this data would cover. `data` is a buildings.gd entry.
static func for_building(grid: Grid, data: Dictionary, origin: Vector2i, size: Vector2i, rotation := 0) -> Dictionary:
	var coverage: Dictionary = data.get("coverage", {})
	match coverage.get("type", ""):
		"radius":
			return radius_tiles(grid, origin, size, coverage["tiles"])
		"walker":
			return walker_tiles(grid, origin, size, rotation)
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
