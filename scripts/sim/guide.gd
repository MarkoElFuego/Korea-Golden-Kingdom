extends RefCounted
## The advisor's pointing finger (phase 10b): for the current goal's "build" list
## (scripts/data/scenario.gd), which buildings are still to be built (their menu buttons glow)
## and a good spot for the next one (an arrow on the map).
##
## The spot always follows the building rules (City.check_building, Silver aside), so the
## player can build right there. Where it looks:
##   road            - the valley entrance (start the road here);
##   on the land     - Rice Paddy, Soybean Field (fertile plain), Clay Pit (rocky hill),
##                     Salt Pans (shore), Woodcutter (forest edge): the nearest fitting land,
##                     beside a road when one is close;
##   Fermentation Yard - between the Soybean Fields and the Salt Pans, so loads walk little;
##   Guardian Posts  - on the road near the storage the dokkaebi will come for;
##   everything else - beside a road, near the middle of the town.
## Worked out again only after buildings, roads or the goal change; never saved.

const Buildings = preload("res://scripts/data/buildings.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const Economy = preload("res://scripts/sim/economy.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Scenario = preload("res://scripts/data/scenario.gd")

const NO_TILE := Vector2i(-1, -1)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SEARCH_TILES := 50 # how far from the anchor to look for a spot
const ROAD_NEAR := 25 # look this far for a spot beside a road before taking one without
const POST_REACH := 4 # Guardian Posts go this close to the storage

var _city: WeakRef
var _dirty := true
var _todo: Array[String] = []
var _spot := {}


func _init(city) -> void:
	_city = weakref(city)
	city.building_added.connect(_on_change)
	city.building_removed.connect(_on_change)
	city.roads_changed.connect(_on_change.bind({}))
	city.goal_changed.connect(_on_change.bind({}))


func mark_dirty() -> void:
	_dirty = true


func _on_change(_instance: Dictionary) -> void:
	_dirty = true


## Buildings of the current goal still to build, in order (their menu buttons glow).
func todo() -> Array[String]:
	_ensure()
	return _todo


## Where the next one could go: {"type", "origin", "size"}, or {} when there is nothing to
## show (or no place fits).
func spot() -> Dictionary:
	_ensure()
	return _spot


## How many of `type` the city has (roads: road tiles joined to the entrance, up to `limit`).
func built(type: String, limit: int) -> int:
	var city = _city.get_ref()
	if type == "road":
		return city.objectives._entrance_roads(limit) - 1 # the entrance tile itself is free
	var n := 0
	for instance: Dictionary in city.buildings.all():
		if instance["type"] == type:
			n += 1
	return n


func _ensure() -> void:
	if not _dirty:
		return
	_dirty = false
	_todo.clear()
	_spot = {}
	var city = _city.get_ref()
	if city.objectives == null or city.objectives.won():
		return
	for item: Dictionary in city.objectives.goal().get("build", []):
		if built(item["id"], item["count"]) < item["count"]:
			_todo.append(item["id"])
	if not _todo.is_empty():
		_spot = find_spot(_todo[0])


## A good place for `type` right now ({} when none is found).
func find_spot(type: String) -> Dictionary:
	var city = _city.get_ref()
	match type:
		"road":
			return {"type": "road", "origin": city.entrance, "size": Vector2i.ONE}
		"jangseung":
			return _post_spot()
	var size: Vector2i = Buildings.get_building(type)["footprint"]
	var anchor := _anchor(type)
	var beside_road := _search(type, anchor, size, true)
	if not beside_road.is_empty():
		return beside_road
	return _search(type, anchor, size, false)


## Where to start looking for `type`.
func _anchor(type: String) -> Vector2i:
	var city = _city.get_ref()
	if type == "jangdokdae":
		var fields := _centre_of("soybean_field")
		var pans := _centre_of("salt_pans")
		if fields != NO_TILE and pans != NO_TILE:
			return (fields + pans) / 2
	var houses := _centre_of("common_house")
	if houses != NO_TILE:
		return houses
	var all := _centre_of("")
	if all != NO_TILE:
		return all
	return _road_end()


## The middle of every building of `type` ("" for all buildings), or NO_TILE.
func _centre_of(type: String) -> Vector2i:
	var city = _city.get_ref()
	var sum := Vector2i.ZERO
	var n := 0
	for instance: Dictionary in city.buildings.all():
		if type == "" or instance["type"] == type:
			sum += instance["origin"]
			n += 1
	return NO_TILE if n == 0 else sum / n


## The road tile farthest along the roads from the entrance (the end of the first street).
func _road_end() -> Vector2i:
	var city = _city.get_ref()
	var seen := {city.entrance: true}
	var queue: Array[Vector2i] = [city.entrance]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for d in DIRS:
			var n := t + d
			if city.grid.in_bounds(n) and city.grid.is_road(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return queue[queue.size() - 1]


## The nearest place (ring by ring from `anchor`) where `type` may stand; with
## `beside_road`, only places touching a road and no farther than ROAD_NEAR.
func _search(type: String, anchor: Vector2i, size: Vector2i, beside_road: bool) -> Dictionary:
	var city = _city.get_ref()
	var reach := ROAD_NEAR if beside_road else SEARCH_TILES
	for r in reach + 1:
		for origin in _ring(anchor, r):
			if not city.grid.in_bounds(origin):
				continue
			var reason: String = city.check_building(type, origin, 0)
			if reason != "" and reason != "REASON_NOT_ENOUGH_SILVER":
				continue
			if beside_road and not Coverage.has_road_access(city.grid, origin, size):
				continue
			return {"type": type, "origin": origin, "size": size}
	return {}


## Tiles at distance `r` (square ring) around `c`, in a fixed order.
static func _ring(c: Vector2i, r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if r == 0:
		result.append(c)
		return result
	for x in range(-r, r + 1):
		result.append(c + Vector2i(x, -r))
		result.append(c + Vector2i(x, r))
	for y in range(-r + 1, r):
		result.append(c + Vector2i(-r, y))
		result.append(c + Vector2i(r, y))
	return result


## A road tile near the storage with goods and the lowest Gi (where dokkaebi would come),
## but not its own doorstep.
func _post_spot() -> Dictionary:
	var city = _city.get_ref()
	var target: Dictionary = city.objectives._lowest_gi_storage()
	if target.is_empty():
		return {}
	var door: Vector2i = city.carriers.access_road(target)
	var o: Vector2i = target["origin"]
	var s: Vector2i = target["size"]
	for r in range(1, POST_REACH + 1):
		for y in range(o.y - r, o.y + s.y + r):
			for x in range(o.x - r, o.x + s.x + r):
				var t := Vector2i(x, y)
				if t == door or not city.grid.in_bounds(t):
					continue
				var reason: String = city.check_building("jangseung", t, 0)
				if reason == "" or reason == "REASON_NOT_ENOUGH_SILVER":
					return {"type": "jangseung", "origin": t, "size": Vector2i.ONE}
	return {}
