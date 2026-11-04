extends RefCounted
## Gi, the life force of the land (docs/koncept.md, "Pungsu i Gi"): 0..100 on every tile.
##
## From the land (pungsu): GI_BASE everywhere, more right below the mountain (baesan), more
## by the water in front (imsu), and more where forest ridges guard both east (Blue Dragon)
## and west (White Tiger). Buildings then raise it (Village Shrine, Guardian Posts) or lower
## it (Clay Pit, Pottery Kiln, Woodcutter) around them. The best places (GI_MYEONGDANG and
## up) are the Myeongdang.
##
## Gi is worked out from the terrain and the buildings, so it is never saved. It is worked
## out again only when asked after a change (mark_dirty), never every tick.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Terrain = preload("res://scripts/data/terrain.gd")

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var version := 0 # grows every time the map is worked out again (the view redraws then)
var _city: WeakRef
var _dirty := true
var _values := PackedByteArray() # per tile, index y * width + x
var _base := PackedByteArray() # from the land only
var _base_terrain := PackedByteArray() # the terrain _base was worked out for


func _init(city) -> void:
	_city = weakref(city)


## Buildings came or went (or the terrain changed): work Gi out again when it is next asked.
func mark_dirty() -> void:
	_dirty = true


func at(tile: Vector2i) -> int:
	_ensure()
	var grid = _city.get_ref().grid
	if not grid.in_bounds(tile):
		return 0
	return _values[tile.y * grid.width + tile.x]


## Average Gi over a footprint (a house's Gi).
func of_area(origin: Vector2i, size: Vector2i) -> int:
	var total := 0
	for dy in size.y:
		for dx in size.x:
			total += at(origin + Vector2i(dx, dy))
	return roundi(total / float(size.x * size.y))


## Every tile's Gi (for the overlay), index y * width + x.
func values() -> PackedByteArray:
	_ensure()
	return _values


## What building `type` does to the Gi around it: {"change", "tiles"}, or {}.
static func effect(type: String) -> Dictionary:
	return Buildings.get_building(type).get("gi", {})


func _ensure() -> void:
	if not _dirty:
		return
	var grid = _city.get_ref().grid
	if grid.terrain != _base_terrain:
		_base = land_gi(grid)
		_base_terrain = grid.terrain.duplicate()
	var w: int = grid.width
	var change := PackedInt32Array()
	change.resize(_base.size())
	for instance: Dictionary in _city.get_ref().buildings.all():
		var e := effect(instance["type"])
		if e.is_empty():
			continue
		var o: Vector2i = instance["origin"]
		var r: int = e["tiles"]
		for y in range(maxi(0, o.y - r), mini(grid.height, o.y + instance["size"].y + r)):
			for x in range(maxi(0, o.x - r), mini(w, o.x + instance["size"].x + r)):
				change[y * w + x] += e["change"]
	_values.resize(_base.size())
	for i in _base.size():
		_values[i] = clampi(_base[i] + change[i], 0, 100)
	_dirty = false
	version += 1


## Gi from the land alone (pungsu), per tile.
static func land_gi(grid) -> PackedByteArray:
	var w: int = grid.width
	var h: int = grid.height
	var mountain := _distance_to(grid, func(t: int) -> bool: return t == Terrain.MOUNTAIN)
	var water := _distance_to(grid, func(t: int) -> bool: return Terrain.is_water(t))
	var result := PackedByteArray()
	result.resize(w * h)
	# Forest per row, to look for ridges to the west and east (rows close by count too:
	# a ridge that ends a little short of the mountain still guards the land below it).
	var forest_rows: Array = []
	for y in h:
		var xs: Array[int] = []
		for x in w:
			if grid.get_terrain(Vector2i(x, y)) == Terrain.FOREST:
				xs.append(x)
		forest_rows.append(xs)
	for y in h:
		var forest_x: Array[int] = []
		for ry in range(maxi(0, y - Balance.GI_RIDGE_ROWS), mini(h, y + Balance.GI_RIDGE_ROWS + 1)):
			forest_x.append_array(forest_rows[ry])
		for x in w:
			var i := y * w + x
			var gi := float(Balance.GI_BASE)
			if mountain[i] >= 0:
				gi += Balance.GI_MOUNTAIN_BONUS * maxf(0.0, 1.0 - mountain[i] / float(Balance.GI_MOUNTAIN_REACH))
			if water[i] >= 0:
				gi += Balance.GI_WATER_BONUS * maxf(0.0, 1.0 - maxi(0, water[i] - 1) / float(Balance.GI_WATER_REACH))
			var west := false
			var east := false
			for fx in forest_x:
				if fx < x and x - fx <= Balance.GI_RIDGE_REACH:
					west = true
				elif fx > x and fx - x <= Balance.GI_RIDGE_REACH:
					east = true
			if west and east:
				gi += Balance.GI_ENCLOSED_BONUS
			result[i] = clampi(roundi(gi), 0, 100)
	return result


## Steps (4 directions) from every tile to the nearest tile whose terrain `is_source` accepts;
## -1 when there is none on the map.
static func _distance_to(grid, is_source: Callable) -> PackedInt32Array:
	var w: int = grid.width
	var dist := PackedInt32Array()
	dist.resize(w * grid.height)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for i in dist.size():
		if is_source.call(grid.terrain[i]):
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		@warning_ignore("integer_division")
		var t := Vector2i(i % w, i / w)
		for d in DIRS:
			var n := t + d
			if not grid.in_bounds(n):
				continue
			var ni := n.y * w + n.x
			if dist[ni] == -1:
				dist[ni] = dist[i] + 1
				queue.append(ni)
	return dist
