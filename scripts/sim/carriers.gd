extends RefCounted
## Carriers with a jige: destination walkers that take one load from a producing building
## to a workshop that needs it (Onggi Kiln: Clay, Wood) or, when none does, to the nearest
## storage (by road) that accepts it and has room, then walk home.
## A producing building sends one carrier at a time.
##
## A carrier is a Dictionary:
##   id, home (building id, 0 when demolished), cargo (good or ""), target (workshop or
##   storage id, or 0),
##   state ("deliver" or "return"), path (road tiles), index (tile it is on), progress (0..1
##   toward path[index + 1]).
## Goods are never lost on the way: if the target disappears the carrier finds another
## storage or brings the load home.

const Balance = preload("res://scripts/data/balance.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const Goods = preload("res://scripts/data/goods.gd")
const WalkerMotion = preload("res://scripts/sim/walker_motion.gd")

const NO_TILE := Vector2i(-1, -1)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var walkers := {} # id -> carrier
var _next_id := 1
var _city: WeakRef # scripts/sim/city.gd (weak: the city owns this object)

# Caches, rebuilt when roads or buildings change.
var _dirty := true
var _access := {} # building id -> entrance road tile
var _storage_at := {} # road tile -> storage and workshop ids entered from it, oldest first
var _takers := {} # good -> number of buildings that could ever take it (storages, workshops)
var _stores := {} # good -> number of storages that could hold it (sources for fetchers)
## Searches for a source that found nothing: good -> {start tile -> economy.source_version}.
## Nothing can be found from there until a load of that good is added somewhere, workers
## move, or roads or buildings change, so the search is skipped until then. (It only skips
## searches that would fail, so the city plays exactly the same.)
var _no_source := {}
var _nearest := {} # good -> {start tile -> last storage found: {"id", "path"}}
var _seen := PackedInt32Array() # search marks, per tile (compared with _stamp)
var _parent := PackedInt32Array() # search back links, per tile
var _stamp := 0


func _init(city) -> void:
	_city = weakref(city)


func count() -> int:
	return walkers.size()


## All carriers in the order they set out.
## (Ids only grow and a Dictionary keeps insertion order, so no sorting is needed.)
func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(walkers.values())
	return result


## Buildings in the city that could ever take `good` (storages and workshops).
func takers(good: String) -> int:
	_ensure_index()
	return _takers.get(good, 0)


## Loads currently on someone's back.
func carried(good: String) -> int:
	var n := 0
	for w: Dictionary in walkers.values():
		if w["cargo"] == good:
			n += 1
	return n


func tick() -> void:
	_dispatch()
	var step := Balance.CARRIER_SPEED / Balance.TICKS_PER_SECOND
	for w in all():
		if not walkers.has(w["id"]):
			continue
		if WalkerMotion.advance(w, step):
			_arrive(w)


## Where a load of `good` from `start` goes: {"id", "path"}, or {} when nothing takes it.
## First the nearest workshop (by road) that needs it as an input, as in Zeus; otherwise
## the nearest storage with room: one breadth-first walk along the streets that stops at
## the first one (several on one entrance tile: the older one first).
## The storage answer is remembered until roads or buildings change; if that storage
## fills up, the search runs again.
func find_storage(start: Vector2i, good: String) -> Dictionary:
	var city = _city.get_ref()
	var grid = city.grid
	if not grid.is_road(start):
		return {}
	_ensure_index()
	if _takers.get(good, 0) == 0:
		return {} # nothing in the city takes it (Soybeans and Salt before the Jangdokdae)
	var economy = city.economy
	if economy.consumers(good) > 0:
		var workshop := _search(start, func(instance: Dictionary) -> bool:
			return economy.input_space(instance, good) > 0)
		if not workshop.is_empty():
			return workshop
	# Same start and good as last time, and that storage still has room: reuse the answer.
	var cached: Dictionary = _nearest.get(good, {}).get(start, {})
	if not cached.is_empty():
		var known: Dictionary = city.buildings.get_instance(cached["id"])
		if not known.is_empty() and city.economy.free_space(known, good) > 0:
			return {"id": cached["id"], "path": cached["path"].duplicate()}
	var found := _search(start, func(instance: Dictionary) -> bool:
		return economy.accepts(instance["type"], good) and economy.free_space(instance, good) > 0)
	if not found.is_empty():
		if not _nearest.has(good):
			_nearest[good] = {}
		_nearest[good][start] = {"id": found["id"], "path": found["path"].duplicate()}
	return found


## Nearest staffed storage (by road) that holds `good`, or Jangdokdae with that Jang ready:
## {"id", "path"}, or {} (Market buyers, workshop fetchers). Workshops are never a source.
func find_source(start: Vector2i, good: String) -> Dictionary:
	var city = _city.get_ref()
	if not city.grid.is_road(start):
		return {}
	_ensure_index()
	if _stores.get(good, 0) == 0:
		return {} # no storage could hold it (Soybeans, Salt): no need to walk the streets
	var economy = city.economy
	var version: Array = economy.source_version(good)
	if _no_source.get(good, {}).get(start, []) == version:
		return {}
	var found := _search(start, func(instance: Dictionary) -> bool:
		return economy.can_give(instance, good) > 0)
	if found.is_empty():
		if not _no_source.has(good):
			_no_source[good] = {}
		_no_source[good][start] = version
	return found


## Breadth-first walk along the streets from `start` to the first storage `wanted` accepts.
func _search(start: Vector2i, wanted: Callable) -> Dictionary:
	var city = _city.get_ref()
	var grid = city.grid
	var w: int = grid.width
	_stamp += 1
	var first: int = start.y * w + start.x
	_seen[first] = _stamp
	_parent[first] = -1
	var queue := PackedInt32Array([first])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		@warning_ignore("integer_division")
		var t := Vector2i(i % w, i / w)
		for id: int in _storage_at.get(t, []):
			if wanted.call(city.buildings.get_instance(id)):
				return {"id": id, "path": _path_to(i, w)}
		for d in DIRS:
			var n := t + d
			if grid.is_road(n):
				var ni := n.y * w + n.x
				if _seen[ni] != _stamp:
					_seen[ni] = _stamp
					_parent[ni] = i
					queue.append(ni)
	return {}


## Entrance tile of a building (cached until roads or buildings change).
func access_road(instance: Dictionary) -> Vector2i:
	_ensure_index()
	return _access.get(instance["id"], NO_TILE)


func _path_to(i: int, w: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	while i != -1:
		@warning_ignore("integer_division")
		path.append(Vector2i(i % w, i / w))
		i = _parent[i]
	path.reverse()
	return path


## Rebuilds the entrance cache and the "which storages are entered from this tile" index.
func _ensure_index() -> void:
	if not _dirty:
		return
	var city = _city.get_ref()
	var grid = city.grid
	_access.clear()
	_storage_at.clear()
	_nearest.clear()
	_takers.clear()
	_stores.clear()
	_no_source.clear()
	var economy = city.economy
	for instance: Dictionary in city.buildings.all():
		var tile := Coverage.access_road(grid, instance)
		_access[instance["id"]] = tile
		var takes: Array = economy.inputs(instance["type"]).duplicate()
		for good: String in Goods.ids():
			if economy.accepts(instance["type"], good):
				takes.append(good)
				_stores[good] = _stores.get(good, 0) + 1
		var f: Dictionary = economy.fermentation(instance["type"])
		for good: String in [f.get("good", ""), f.get("ripe_good", "")]:
			if good != "":
				_stores[good] = _stores.get(good, 0) + 1
		for good: String in takes:
			_takers[good] = _takers.get(good, 0) + 1
		if tile != NO_TILE and not takes.is_empty():
			if not _storage_at.has(tile):
				_storage_at[tile] = []
			_storage_at[tile].append(instance["id"])
	var size: int = grid.width * grid.height
	if _seen.size() != size:
		_seen.resize(size)
		_seen.fill(0)
		_parent.resize(size)
	_dirty = false


# --- Events from the city ---

func on_building_added(_instance: Dictionary) -> void:
	_dirty = true


func on_building_removed(instance: Dictionary) -> void:
	var city = _city.get_ref()
	_dirty = true
	for w in all():
		if w["home"] == instance["id"]:
			w["home"] = 0
		if w["target"] == instance["id"]:
			w["target"] = 0
			_retarget(w)
		elif w["state"] == "return" and w["home"] == 0:
			_give_up(w)
	city.economy.remove_building(instance)


func on_roads_changed() -> void:
	var city = _city.get_ref()
	_dirty = true
	for w in all():
		var here: Vector2i = w["path"][w["index"]]
		if not city.grid.is_road(here):
			_give_up(w) # the road under its feet is gone
			continue
		if WalkerMotion.path_still_open(w, city.grid):
			continue
		if w["state"] == "deliver":
			city.economy.reserve(w["target"], w["cargo"], -1)
			_retarget(w)
		else:
			_go_home(w)


# --- Inside ---

## Sends a carrier from every producer that has a load waiting and its carrier at home.
func _dispatch() -> void:
	var city = _city.get_ref()
	if city.economy.waiting.is_empty():
		return
	var ids: Array = city.economy.waiting.keys()
	ids.sort()
	for id: int in ids:
		var s: Dictionary = city.economy.state[id]
		if city.clock.tick < s.get("retry_at", 0):
			continue
		var good: String = s["good"]
		var start := access_road(city.buildings.get_instance(id))
		var target := {} if start == NO_TILE else find_storage(start, good)
		if target.is_empty():
			s["retry_at"] = city.clock.tick + Balance.CARRIER_RETRY_TICKS # nobody takes it: ask again later
			continue
		city.economy.add(id, good, -1)
		city.economy.reserve(target["id"], good, 1)
		var w := {
			"id": _next_id, "home": id, "cargo": good, "target": target["id"],
			"state": "deliver", "path": target["path"], "index": 0, "progress": 0.0,
		}
		walkers[_next_id] = w
		city.economy.set_carrier(id, _next_id)
		_next_id += 1


func _arrive(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w["state"] == "deliver":
		city.economy.reserve(w["target"], w["cargo"], -1)
		city.economy.add(w["target"], w["cargo"], 1)
		w["cargo"] = ""
		w["target"] = 0
		_go_home(w)
		return
	# Back home.
	if w["home"] != 0:
		if w["cargo"] != "":
			city.economy.add(w["home"], w["cargo"], 1)
		city.economy.set_carrier(w["home"], 0)
	elif w["cargo"] != "":
		city.economy.lost[w["cargo"]] = city.economy.lost.get(w["cargo"], 0) + 1
	walkers.erase(w["id"])


## Looks for another storage from where the carrier stands; otherwise walks the load home.
func _retarget(w: Dictionary) -> void:
	var city = _city.get_ref()
	var here: Vector2i = w["path"][w["index"]]
	var target := find_storage(here, w["cargo"])
	if target.is_empty():
		w["target"] = 0
		_go_home(w)
		return
	city.economy.reserve(target["id"], w["cargo"], 1)
	w["target"] = target["id"]
	w["state"] = "deliver"
	WalkerMotion.follow(w, target["path"])


func _go_home(w: Dictionary) -> void:
	var city = _city.get_ref()
	w["state"] = "return"
	if w["home"] == 0:
		_give_up(w)
		return
	var home: Dictionary = city.buildings.get_instance(w["home"])
	var end := access_road(home)
	var path: Array[Vector2i] = []
	if end != NO_TILE:
		path = city.network.path(w["path"][w["index"]], end)
	if path.is_empty():
		_give_up(w)
		return
	WalkerMotion.follow(w, path)


## The carrier cannot walk on: it leaves the map and its load goes back to its building
## (or is lost if that building is gone too).
func _give_up(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w["state"] == "deliver" and w["target"] != 0:
		city.economy.reserve(w["target"], w["cargo"], -1)
	if w["home"] != 0:
		if w["cargo"] != "":
			city.economy.add(w["home"], w["cargo"], 1)
		city.economy.set_carrier(w["home"], 0)
	elif w["cargo"] != "":
		city.economy.lost[w["cargo"]] = city.economy.lost.get(w["cargo"], 0) + 1
	walkers.erase(w["id"])


# --- Saving (save_game.gd) ---

## The remembered storage answers are saved too: a carrier keeps going to the storage it
## found before, so a loaded game must remember the same answers to play on the same way.
func to_save() -> Dictionary:
	return {"walkers": walkers, "next_id": _next_id, "nearest": {} if _dirty else _nearest}


func load_save(d: Dictionary) -> void:
	walkers = d["walkers"]
	_next_id = d["next_id"]
	_dirty = true
	_ensure_index()
	_nearest = d["nearest"]
