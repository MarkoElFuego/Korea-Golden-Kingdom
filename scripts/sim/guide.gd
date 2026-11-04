extends RefCounted
## The advisor's hand on the player's (phase 10b, 10c): for the current goal's "build" list
## (scripts/data/scenario.gd) it plans the town on the map and says the one next step.
##
##   todo()    - buildings of the goal still to build (their menu buttons glow);
##   ghosts()  - the plan: a gold mark for every one still to build, where it fits best;
##   roads()   - planned road tiles: the first street from the valley entrance, a road to
##               every planned building that would not touch the town's roads, and a road
##               to a building already built but cut off from the town;
##   step()    - the one next thing to do (the bar above the menu, the arrow). The advisor
##               looks at the town every day and picks the most urgent:
##                 "connect"  a building is cut off from the town: a road to it ("path");
##                 "workers"  a building lacks workers: "have"/"need" workers, "houses" to
##                            build (0: settlers already on their way bring them; then it
##                            waits until nothing else is left to do);
##                 "water"    "houses" without water: a Well on the gold mark;
##                 "food"     "houses" no Market vendor reaches: a Market on the gold mark;
##                 "road"     lay the first street ("path");
##                 "build"    the goal's next building on its gold mark ("goal_houses",
##                            "have", "more" when the goal wants more houses than the town has);
##                 "rice_far" hungry houses: rice waits at fields far from the Granary
##                            ("trip_days"): a Granary near the fields;
##                 "rice_more" hungry houses: too few fields, build "paddies" more;
##                 "goods"    the goal's goods are stuck: the Goods report's "note";
##                 "stray"    a Market vendor or shrine keeper walks "tiles" of road with no
##                            houses: a Guardian Post where the houses end turns it back;
##                 "wait"     nothing to build now.
##               "silver": true when the next building costs more than the treasury holds.
##   spot()    - where the arrow stands: the start of the road to drag, or the next gold mark.
##
## Every mark follows the building rules (City.check_building, Silver aside), so the player can
## build right there. A road path is draggable: as straight as it can be, from a town road.
## Where marks go:
##   on the land     - Rice Paddy, Soybean Field (fertile plain), Clay Pit (rocky hill),
##                     Salt Pans (shore), Woodcutter (forest edge): the nearest fitting land,
##                     beside a town road when one is close (otherwise with a planned road);
##   Fermentation Yard - between the Soybean Fields and the Salt Pans, so loads walk little;
##   Guardian Posts  - on the road near the storage the dokkaebi will come for;
##   everything else - beside a town road, near the middle of the town.
## A mark keeps its place while it still fits, so the plan does not jump around.
## Worked out again only after buildings, roads or the goal change; never saved.

const Buildings = preload("res://scripts/data/buildings.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Balance = preload("res://scripts/data/balance.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const Scenario = preload("res://scripts/data/scenario.gd")

const NO_TILE := Vector2i(-1, -1)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SEARCH_TILES := 50 # how far from the anchor to look for a spot
const ROAD_NEAR := 25 # look this far for a spot beside a road before taking one without
const POST_REACH := 4 # Guardian Posts go this close to the storage
const PATH_SEARCH := 9000 # tiles a road path search may look at
const HOUSE := "common_house"
const END_KEEP := 2 # tiles kept free around the far end of the street
const HUNGRY_HOUSES := 3 # the advisor speaks up when this many reachable houses have no food
const STRAY_TILES := 6 # road tiles without houses a walker may wander before the advisor says so
const FAR_TRIP := 1.5 # a carrier's round trip this many times the growing time: the Granary is too far

var _city: WeakRef
var _dirty := true
var _todo: Array[String] = []
var _ghosts: Array[Dictionary] = []
var _roads: Array[Vector2i] = []
var _step := {}
var _spot := {}
var _town := {} # road tiles joined to the valley entrance (worked out when needed)


func _init(city) -> void:
	_city = weakref(city)
	city.building_added.connect(_on_change)
	city.building_removed.connect(_on_change)
	city.roads_changed.connect(_on_change.bind({}))
	city.goal_changed.connect(_on_change.bind({}))
	city.population_changed.connect(_on_change.bind({}))
	city.clock.day_changed.connect(func(_day: int) -> void: mark_dirty()) # water, food, workers move daily


func mark_dirty() -> void:
	_dirty = true
	_town = {}


func _on_change(_instance: Dictionary) -> void:
	mark_dirty()


## Buildings of the current goal still to build, in order.
func todo() -> Array[String]:
	_ensure()
	return _todo


## Menu buttons to glow: the goal's buildings, and Road first when a road is the next step.
func buttons() -> Array[String]:
	_ensure()
	if _step.get("kind", "") != "connect" or _todo.has("road"):
		return _todo
	var result: Array[String] = ["road"]
	result.append_array(_todo)
	return result


## The planned buildings: [{"type", "origin", "size"}].
func ghosts() -> Array[Dictionary]:
	_ensure()
	return _ghosts


## Planned road tiles not built yet.
func roads() -> Array[Vector2i]:
	_ensure()
	return _roads


## The one next thing to do (see the top of this file); {} with no scenario.
func step() -> Dictionary:
	_ensure()
	return _step


## Where the arrow stands: {"type", "origin", "size"} ("road": where to start dragging), or {}.
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
	var old := _ghosts.duplicate()
	_todo.clear()
	_ghosts.clear()
	_roads.clear()
	_step = {}
	_spot = {}
	var city = _city.get_ref()
	if city.objectives == null or city.objectives.won():
		return
	var left := {}
	for item: Dictionary in city.objectives.goal().get("build", []):
		var n: int = item["count"] - built(item["id"], item["count"])
		if n > 0:
			_todo.append(item["id"])
			left[item["id"]] = n
	var taken := {}

	# 1. A building cut off from the town: a road to it first.
	var cut := _first_cut_off()
	if not cut.is_empty():
		var path := road_to(cut["origin"], cut["size"], taken)
		if not path.is_empty():
			_add_road(path, taken)
			_step = {"kind": "connect", "type": "road", "building": cut["type"], "path": path,
				"building_origin": cut["origin"], "building_size": cut["size"]}

	# 2. A building without workers: more houses (or wait for the settlers on their way).
	var houses := built(HOUSE, 0)
	var workers := workers_problem()
	if not workers.is_empty() and workers["houses"] > 0 and _step.is_empty():
		_step = workers.duplicate()
		_step["type"] = HOUSE
		_add_todo(HOUSE, workers["houses"], left, true)

	# 3. The goal wants more houses than the town has (or plans already).
	var goal_houses := houses_for_goal()
	var more: int = goal_houses - houses - left.get(HOUSE, 0)
	if more > 0:
		_add_todo(HOUSE, more, left, false)

	# 4-5. Houses without water, or out of every Market's reach: a Well or a Market near them.
	var dry := _houses_where(func(h: Dictionary) -> bool: return not city.houses.is_met(h, "water"))
	if not dry.is_empty():
		_problem_ghost("water", "well", dry, taken)
	# A Market or more fields need workers: never while the town lacks them (they would stand
	# idle and take workers from the rest).
	var far := _houses_out_of_market_reach() if workers.is_empty() else ([] as Array[Dictionary])
	if not far.is_empty():
		_problem_ghost("food", "market", far, taken)

	# 6. Hungry houses the Market does reach: rice waits at faraway fields, or too few fields.
	var rice := rice_problem() if workers.is_empty() else {}
	if not rice.is_empty():
		if rice["kind"] == "rice_far":
			_problem_ghost("rice_far", "granary", [], taken, rice["fields"])
		else:
			_add_todo("rice_paddy", rice["paddies"], left, _step.is_empty())
		if _step.get("kind", "") == "rice_far":
			_step.merge(rice) # the Granary's mark is set: add how far and how hungry
		elif _step.is_empty():
			_step = rice.duplicate()
			if rice["kind"] == "rice_more":
				_step["type"] = "rice_paddy"

	# 7. A Market vendor or shrine keeper wandering roads where nobody lives: a Guardian Post.
	if _step.is_empty():
		var stray := stray_problem()
		if not stray.is_empty():
			_step = stray
			var post := {"type": "jangseung", "origin": stray["origin"], "size": Vector2i.ONE}
			_ghosts.append(post) # on a road: planned roads may still pass it, like carriers do

	# The goal's buildings (and the houses above): gold marks, with a road where none reaches.
	for id: String in _todo:
		if id == "road":
			var street := street_plan(_goal_count("road"))
			_add_road(street, taken)
			if _step.is_empty() and not street.is_empty():
				_step = {"kind": "road", "type": "road", "path": street}
			continue
		if id == "jangseung":
			var post := _post_spot()
			if not post.is_empty():
				_ghosts.append(post)
			continue
		var mine: Array[Dictionary] = []
		for g: Dictionary in old:
			if mine.size() < left[id] and g["type"] == id and _still_fits(g, taken):
				mine.append(g)
				_take(g, taken)
		while mine.size() < left[id]:
			var s := find_spot(id, taken)
			if s.is_empty():
				break
			mine.append(s)
			_take(s, taken)
		for g: Dictionary in mine:
			_ghosts.append(g)
			if Buildings.needs_road(id) and not touches_town(g["origin"], g["size"]):
				_add_road(road_to(g["origin"], g["size"], taken), taken)

	if _step.is_empty():
		for id: String in _todo:
			var g := _first_ghost(id)
			if not g.is_empty():
				_step = {"kind": "build", "type": id, "origin": g["origin"], "size": g["size"]}
				break
		if not _step.is_empty() and _step["type"] == HOUSE and more > 0:
			_step["goal_houses"] = goal_houses # "this goal needs 10 houses, you have 6"
			_step["have"] = houses
			_step["more"] = left[HOUSE]
	if _step.is_empty():
		var note := goods_problem()
		if not note.is_empty():
			_step = {"kind": "goods", "note": note}
	if _step.is_empty() and not workers.is_empty():
		_step = workers.duplicate() # settlers are on their way: nothing to build, just wait
	if _step.is_empty():
		_step = {"kind": "wait"} if _todo.is_empty() else {"kind": "build", "type": _todo[0]}

	# Where the arrow stands, and whether the Silver is there.
	if _step.get("type", "") not in ["", "road"] and not _step.has("origin"):
		var g := _first_ghost(_step["type"])
		if not g.is_empty():
			_step["origin"] = g["origin"]
			_step["size"] = g["size"]
	if _step.has("path"):
		_spot = {"type": "road", "origin": _step["path"][0], "size": Vector2i.ONE}
	elif _step.has("origin"):
		_spot = {"type": _step["type"], "origin": _step["origin"], "size": _step["size"]}
	if _step.has("type") and _step["type"] != "road" and Buildings.get_building(_step["type"])["cost"] > city.treasury:
		_step["silver"] = true # not enough Silver now: taxes come at the end of the season


## Adds `n` more of `id` to build (first in line with `first`).
func _add_todo(id: String, n: int, left: Dictionary, first: bool) -> void:
	if n <= 0:
		return
	left[id] = left.get(id, 0) + n
	if _todo.has(id):
		if first:
			_todo.erase(id)
			_todo.insert(0, id)
		return
	if first:
		_todo.insert(0, id)
	else:
		_todo.append(id)


func _first_ghost(id: String) -> Dictionary:
	for g: Dictionary in _ghosts:
		if g["type"] == id:
			return g
	return {}


## A Well (water) or a Market (food) for `houses` that lack it: a gold mark near them, and
## the step when nothing more urgent is waiting.
func _problem_ghost(kind: String, type: String, houses: Array[Dictionary], taken: Dictionary, near := NO_TILE) -> void:
	var city = _city.get_ref()
	if not city.is_unlocked(type):
		return
	var sum := Vector2i.ZERO
	for h in houses:
		sum += h["origin"]
	var s := find_spot(type, taken, near if houses.is_empty() else sum / houses.size())
	if s.is_empty():
		return
	_ghosts.append(s)
	_take(s, taken)
	if Buildings.needs_road(type) and not touches_town(s["origin"], s["size"]):
		_add_road(road_to(s["origin"], s["size"], taken), taken)
	if _step.is_empty():
		_step = {"kind": kind, "type": type, "origin": s["origin"], "size": s["size"], "houses": houses.size()}


# --- What the advisor checks every day ---

## The newest building short of workers, while the town lacks them:
## {"kind": "workers", "building", "have": workforce, "need": workers wanted,
##  "houses": houses to build so that the settlers bring enough (0: they are on their way)}, or {}.
func workers_problem() -> Dictionary:
	var city = _city.get_ref()
	var labor = city.labor
	if labor.needed <= labor.workforce:
		return {}
	var short := {}
	var short_has := 0
	for instance: Dictionary in city.buildings.all():
		var want: int = Buildings.get_building(instance["type"])["workers"]
		var has: int = labor.assigned.get(instance["id"], 0)
		if want == 0 or has >= want:
			continue
		if short.is_empty() or has < short_has or (has == short_has and instance["id"] > short["id"]):
			short = instance
			short_has = has
	if short.is_empty():
		return {}
	var coming: int = floori(_room() * Balance.WORKER_SHARE) + labor.extra_workers
	var per_house := Houses.capacity(1) * Balance.WORKER_SHARE
	var houses := maxi(0, ceili((labor.needed - coming) / per_house))
	return {"kind": "workers", "building": short["type"], "have": labor.workforce, "need": labor.needed,
		"houses": houses}


## People the houses will hold once the settlers on their way move in.
func _room() -> int:
	var city = _city.get_ref()
	var room := 0
	for id: int in city.houses.state:
		room += Houses.capacity(city.buildings.get_instance(id)["tier"])
	return room


## Houses the current goal needs at least (its house and population conditions).
func houses_for_goal() -> int:
	var city = _city.get_ref()
	var n := 0
	for c: Dictionary in city.objectives.goal()["conditions"]:
		match c["type"]:
			"houses_tier", "houses_with":
				n = maxi(n, c["count"])
			"buildings":
				if c["building"] == HOUSE:
					n = maxi(n, c["count"])
			"population":
				var room := _room()
				if room < c["count"]:
					n = maxi(n, built(HOUSE, 0) + ceili(float(c["count"] - room) / Houses.capacity(1)))
	return n


## Settled houses for which `test` holds.
func _houses_where(test: Callable) -> Array[Dictionary]:
	var city = _city.get_ref()
	var result: Array[Dictionary] = []
	for id: int in city.houses.state:
		var h: Dictionary = city.buildings.get_instance(id)
		if h["tier"] > 0 and test.call(h):
			result.append(h)
	return result


## Settled houses no Market vendor ever passes (only when the town has a Market).
func _houses_out_of_market_reach() -> Array[Dictionary]:
	var city = _city.get_ref()
	var streets := {}
	var markets := 0
	for m: Dictionary in city.buildings.all():
		if m["type"] != "market":
			continue
		markets += 1
		var area: Dictionary = Coverage.walker_area(city.grid, m["origin"], m["size"], m["rotation"])
		for t: Vector2i in area.get("parent", {}):
			streets[t] = true
	var result: Array[Dictionary] = []
	if markets == 0:
		return result
	var r := Balance.WALKER_SERVICE_RANGE
	return _houses_where(func(h: Dictionary) -> bool:
		for dy in range(-r, h["size"].y + r):
			for dx in range(-r, h["size"].x + r):
				if streets.has(h["origin"] + Vector2i(dx, dy)):
					return false
		return true)


## Settled houses with an empty pantry although a Market vendor reaches them, when there are
## at least HUNGRY_HOUSES of them. Why:
##   {"kind": "rice_far", "hungry", "trip_days", "fields"}: rice waits at the Rice Paddies, the
##       carrier's round trip to the nearest Granary (trip_days) is longer than the fields
##       take to grow a load: a Granary near the fields ("fields": their middle);
##   {"kind": "rice_more", "hungry", "paddies"}: the fields are too few for the people.
## {} when nobody is hungry, or the town has no Market yet.
func rice_problem() -> Dictionary:
	var city = _city.get_ref()
	if not city.is_unlocked("rice_paddy") or _centre_of("market") == NO_TILE:
		return {}
	var far := {}
	for h: Dictionary in _houses_out_of_market_reach():
		far[h["id"]] = true
	var hungry := _houses_where(func(h: Dictionary) -> bool:
		return not far.has(h["id"]) and not city.houses.is_met(h, "food")).size()
	if hungry < HUNGRY_HOUSES:
		return {}
	var grow: float = Buildings.get_building("rice_paddy")["produces"]["days"]
	var worst := 0.0
	var paddies := 0
	for b: Dictionary in city.buildings.all():
		if b["type"] != "rice_paddy":
			continue
		paddies += 1
		if city.economy.stock(b["id"], "rice") == 0:
			continue # nothing waits here: not this field's fault
		var start: Vector2i = city.carriers.access_road(b)
		if start == NO_TILE:
			continue
		var target: Dictionary = city.carriers.find_storage(start, "rice")
		var trip := 0.0
		if target.is_empty():
			trip = INF
		else:
			trip = 2.0 * target["path"].size() / Balance.CARRIER_SPEED # days: 1 day = 1 second at 1x
		worst = maxf(worst, trip)
	if paddies > 0 and worst > grow * FAR_TRIP and worst < INF:
		return {"kind": "rice_far", "hungry": hungry, "trip_days": ceili(worst), "fields": _centre_of("rice_paddy")}
	# Too few fields only once the fields have had time to grow and the stores are empty.
	if city.economy.produced.get("rice", 0) < paddies * 2:
		return {}
	for b: Dictionary in city.buildings.all():
		if b["type"] in ["granary", "market"] and city.economy.stock(b["id"], "rice") > 0:
			return {} # rice is there: the vendors bring it
	var eaters: int = city.population()
	var feeds: float = Balance.FOOD_PORTIONS_PER_LOAD / grow # people one paddy feeds
	var more := maxi(1, ceili(eaters / feeds) - paddies)
	return {"kind": "rice_more", "hungry": hungry, "paddies": more}


## A Market vendor or shrine keeper whose area runs STRAY_TILES or more road tiles past the
## last houses (toward the fields, the clay pit...): every round there feeds nobody. A Guardian
## Post where the houses end turns the walker back to them.
## {"kind": "stray", "type": "jangseung", "building", "tiles", "origin", "size"} or {}.
func stray_problem() -> Dictionary:
	var city = _city.get_ref()
	if not city.is_unlocked("jangseung"):
		return {}
	for b: Dictionary in city.buildings.all():
		if b["type"] != "market" and b["type"] != "seonangdang":
			continue
		var area: Dictionary = Coverage.walker_area(city.grid, b["origin"], b["size"], b["rotation"])
		if area.is_empty():
			continue
		var parent: Dictionary = area["parent"]
		var serving := {} # area tiles with a house in reach, and every tile on the way to them
		for t: Vector2i in parent:
			if not city.services._houses_near(t).is_empty():
				var u := t
				while not serving.has(u):
					serving[u] = true
					if u == area["start"]:
						break
					u = parent[u]
		var cut := {} # tile -> area tiles behind it (the tile itself included)
		for t: Vector2i in parent:
			var u := t
			while true:
				cut[u] = cut.get(u, 0) + 1
				if u == area["start"]:
					break
				u = parent[u]
		var best := NO_TILE
		for t: Vector2i in parent:
			if serving.has(t) or not serving.has(parent[t]) or cut[t] < STRAY_TILES:
				continue
			if not _buildable("jangseung", t):
				continue
			if best == NO_TILE or cut[t] > cut[best] or (cut[t] == cut[best] and (t.y < best.y or (t.y == best.y and t.x < best.x))):
				best = t
		if best != NO_TILE:
			return {"kind": "stray", "type": "jangseung", "building": b["type"], "tiles": cut[best],
				"origin": best, "size": Vector2i.ONE}
	return {}


## What the Goods report says stops the goal's goods ({"key", "args", "good", "stopped"} or {}).
func goods_problem() -> Dictionary:
	var city = _city.get_ref()
	var goods: Array = city.objectives.goal()["goods"]
	for row: Dictionary in city.supply.report():
		if goods.has(row["good"]) and not row["note"].is_empty() and row["note"].get("stopped", false):
			return row["note"]
	return {}


func _goal_count(id: String) -> int:
	for item: Dictionary in _city.get_ref().objectives.goal().get("build", []):
		if item["id"] == id:
			return item["count"]
	return 0


func _add_road(path: Array[Vector2i], taken: Dictionary) -> void:
	var grid = _city.get_ref().grid
	for t in path:
		taken[t] = true
		if not grid.is_road(t) and not _roads.has(t):
			_roads.append(t)


func _take(g: Dictionary, taken: Dictionary) -> void:
	for dy in g["size"].y:
		for dx in g["size"].x:
			taken[g["origin"] + Vector2i(dx, dy)] = true


func _overlaps(origin: Vector2i, size: Vector2i, taken: Dictionary) -> bool:
	for dy in size.y:
		for dx in size.x:
			if taken.has(origin + Vector2i(dx, dy)):
				return true
	return false


func _buildable(type: String, origin: Vector2i) -> bool:
	var reason: String = _city.get_ref().check_building(type, origin, 0)
	return reason == "" or reason == "REASON_NOT_ENOUGH_SILVER"


func _still_fits(g: Dictionary, taken: Dictionary) -> bool:
	return _buildable(g["type"], g["origin"]) and not _overlaps(g["origin"], g["size"], taken)


# --- The town's roads ---

## Road tiles joined to the valley entrance.
func town() -> Dictionary:
	if _town.is_empty():
		var city = _city.get_ref()
		_town = {city.entrance: true}
		var queue: Array[Vector2i] = [city.entrance]
		var head := 0
		while head < queue.size():
			var t := queue[head]
			head += 1
			for d in DIRS:
				var n := t + d
				if city.grid.is_road(n) and not _town.has(n):
					_town[n] = true
					queue.append(n)
	return _town


## True when the footprint touches a road joined to the entrance.
func touches_town(origin: Vector2i, size: Vector2i) -> bool:
	var roads := town()
	for t in Coverage.adjacent_roads(_city.get_ref().grid, origin, size):
		if roads.has(t):
			return true
	return false


## The oldest building that needs a road but does not touch the town's roads, or {}.
func _first_cut_off() -> Dictionary:
	var best := {}
	for instance: Dictionary in _city.get_ref().buildings.all():
		var data := Buildings.get_building(instance["type"])
		if not Buildings.needs_road(instance["type"]) or data.get("on_road", false):
			continue
		if touches_town(instance["origin"], instance["size"]):
			continue
		if best.is_empty() or instance["id"] < best["id"]:
			best = instance
	return best


## Can a planned road go over `t`? (A road already, or free land a road may use.)
func _road_ok(t: Vector2i, taken: Dictionary) -> bool:
	var grid = _city.get_ref().grid
	if not grid.in_bounds(t) or taken.has(t) or grid.is_blocked(t):
		return false
	return grid.is_road(t) or grid.can_place(t, Vector2i.ONE, Buildings.allowed_terrain("road"))


## The shortest road from the town's roads (or a road already planned) to the footprint, as
## straight as it can be: from a road tile (first) to a tile touching the footprint (last).
## [] when none.
func road_to(origin: Vector2i, size: Vector2i, taken: Dictionary) -> Array[Vector2i]:
	var goal := {}
	for t in Coverage._edge_neighbors(origin, size):
		goal[t] = true
	var dist := {}
	var queue: Array[Vector2i] = []
	for t: Vector2i in town():
		dist[t] = 0
		queue.append(t)
	for t in _roads: # join a road already planned rather than lay one beside it
		if not dist.has(t):
			dist[t] = 0
			queue.append(t)
	var head := 0
	var end := NO_TILE
	while head < queue.size() and head < PATH_SEARCH:
		var t := queue[head]
		head += 1
		if goal.has(t):
			end = t
			break
		for d in DIRS:
			var n := t + d
			if not dist.has(n) and _road_ok(n, taken):
				dist[n] = dist[t] + 1
				queue.append(n)
	if end == NO_TILE:
		return []
	return _walk_back(end, dist)


## From `end` back to a tile at distance 0, keeping the same direction while it can
## (fewer bends: easier to drag). Returned from the start to `end`.
static func _walk_back(end: Vector2i, dist: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = [end]
	var t := end
	var last := Vector2i.ZERO
	while dist[t] > 0:
		var order: Array[Vector2i] = []
		if last != Vector2i.ZERO:
			order.append(last)
		order.append_array(DIRS)
		for d in order:
			var n := t + d
			if dist.get(n, -1) == dist[t] - 1:
				last = d
				t = n
				break
		path.append(t)
	path.reverse()
	return path


## The first street: `length` road tiles from the valley entrance straight into the valley
## (around anything in the way). From the entrance (first) to its end.
func street_plan(length: int) -> Array[Vector2i]:
	var city = _city.get_ref()
	var start: Vector2i = city.entrance
	var inward := _inward(start)
	var order: Array[Vector2i] = [inward]
	for d in DIRS:
		if d != inward and d != -inward:
			order.append(d)
	order.append(-inward)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var best := start
	while head < queue.size() and head < PATH_SEARCH:
		var t := queue[head]
		head += 1
		if dist[t] >= length:
			continue
		for d in order:
			var n := t + d
			if not dist.has(n) and _road_ok(n, {}):
				dist[n] = dist[t] + 1
				queue.append(n)
				if _further(n, best, start, inward, dist):
					best = n
	return _walk_back(best, dist)


## Farther along the roads, then deeper into the valley, then closer to the straight line.
static func _further(a: Vector2i, b: Vector2i, start: Vector2i, inward: Vector2i, dist: Dictionary) -> bool:
	if dist[a] != dist[b]:
		return dist[a] > dist[b]
	var da := (a - start).x * inward.x + (a - start).y * inward.y
	var db := (b - start).x * inward.x + (b - start).y * inward.y
	if da != db:
		return da > db
	var sa := absi((a - start).x * inward.y) + absi((a - start).y * inward.x)
	var sb := absi((b - start).x * inward.y) + absi((b - start).y * inward.x)
	return sa < sb


## From an entrance on the map's edge, the way into the valley.
func _inward(t: Vector2i) -> Vector2i:
	var grid = _city.get_ref().grid
	var w: int = grid.width
	var h: int = grid.height
	var gaps := {Vector2i.RIGHT: t.x, Vector2i.LEFT: w - 1 - t.x, Vector2i.DOWN: t.y, Vector2i.UP: h - 1 - t.y}
	var best := Vector2i.RIGHT
	for d: Vector2i in gaps:
		if gaps[d] < gaps[best]:
			best = d
	return best


# --- Spots for buildings ---

## A good place for `type` right now ({} when none is found), away from `taken` tiles.
func find_spot(type: String, taken := {}, near := NO_TILE) -> Dictionary:
	if type == "road":
		return {"type": "road", "origin": _city.get_ref().entrance, "size": Vector2i.ONE}
	if type == "jangseung":
		return _post_spot()
	var size: Vector2i = Buildings.get_building(type)["footprint"]
	var anchor := near if near != NO_TILE else _anchor(type)
	var beside_road := _search(type, anchor, size, true, taken)
	if not beside_road.is_empty():
		return beside_road
	return _search(type, anchor, size, false, taken)


## Where to start looking for `type`.
func _anchor(type: String) -> Vector2i:
	if type == "jangdokdae":
		var fields := _centre_of("soybean_field")
		var pans := _centre_of("salt_pans")
		if fields != NO_TILE and pans != NO_TILE:
			return (fields + pans) / 2
	var houses := _centre_of("common_house")
	if type == "granary":
		var paddies := _centre_of("rice_paddy", true)
		if paddies != NO_TILE and houses != NO_TILE:
			return (paddies + houses) / 2 # carriers and buyers both walk little
	if type == "onggi_kiln":
		var clay := _centre_of("clay_pit", true)
		var wood := _centre_of("woodcutter", true)
		if clay != NO_TILE and wood != NO_TILE:
			return (clay + wood) / 2 # clay and wood come straight to the kiln
	if type == "storehouse":
		var kiln := _centre_of("onggi_kiln", true)
		if kiln != NO_TILE and houses != NO_TILE:
			return (kiln + houses) / 2 # between the kiln and the Market's buyers
	if houses != NO_TILE:
		return houses
	var all := _centre_of("")
	if all != NO_TILE:
		return all
	return _road_far()


## The middle of every building of `type` ("" for all buildings), or NO_TILE.
## With `planned`, the gold marks of this plan count too.
func _centre_of(type: String, planned := false) -> Vector2i:
	var sum := Vector2i.ZERO
	var n := 0
	var all: Array[Dictionary] = _city.get_ref().buildings.all()
	if planned:
		all.append_array(_ghosts)
	for instance: Dictionary in all:
		if type == "" or instance["type"] == type:
			sum += instance["origin"]
			n += 1
	return NO_TILE if n == 0 else sum / n


## The town road tile farthest from the valley entrance (the town starts deep in the valley,
## not at the edge of the map).
func _road_far() -> Vector2i:
	var entrance: Vector2i = _city.get_ref().entrance
	var best := entrance
	for t: Vector2i in town():
		var d := absi(t.x - entrance.x) + absi(t.y - entrance.y)
		var bd := absi(best.x - entrance.x) + absi(best.y - entrance.y)
		if d > bd or (d == bd and (t.y < best.y or (t.y == best.y and t.x < best.x))):
			best = t
	return best


## The nearest place (ring by ring from `anchor`) where `type` may stand; with
## `beside_road`, only places touching a town road and no farther than ROAD_NEAR.
func _search(type: String, anchor: Vector2i, size: Vector2i, beside_road: bool, taken: Dictionary) -> Dictionary:
	var grid = _city.get_ref().grid
	var reach := ROAD_NEAR if beside_road else SEARCH_TILES
	var end := _road_far()
	for r in reach + 1:
		for origin in _ring(anchor, r):
			if not grid.in_bounds(origin) or _overlaps(origin, size, taken):
				continue
			if _near_end(origin, size, end):
				continue # the street must be able to go on
			if not _buildable(type, origin):
				continue
			if beside_road and not touches_town(origin, size):
				continue
			return {"type": type, "origin": origin, "size": size}
	return {}


## True when the footprint comes within END_KEEP tiles of the street's far end, which stays
## free so the street (and roads to the fields) can go on from there.
static func _near_end(origin: Vector2i, size: Vector2i, end: Vector2i) -> bool:
	return end.x >= origin.x - END_KEEP and end.x < origin.x + size.x + END_KEEP 		and end.y >= origin.y - END_KEEP and end.y < origin.y + size.y + END_KEEP


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
				if _buildable("jangseung", t):
					return {"type": "jangseung", "origin": t, "size": Vector2i.ONE}
	return {}
