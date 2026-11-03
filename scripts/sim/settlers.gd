extends RefCounted
## Settlers: destination walkers who come in through the valley entrance and walk to a
## house with room (oldest first), carrying their bundles. On arrival a vacant lot becomes
## a Choga Hut. If their house is demolished they look for another one, or go back out.
##
## A settler is a Dictionary: id, people, target (house id), state ("in" or "out"),
## path, index, progress (see walker_motion.gd).

const Balance = preload("res://scripts/data/balance.gd")
const WalkerMotion = preload("res://scripts/sim/walker_motion.gd")

const NO_TILE := Vector2i(-1, -1)

signal arrived(house: Dictionary)

var walkers := {} # id -> settler
## False when houses wait for settlers but no road joins them to the entrance.
var entrance_connected := true
var _next_id := 1
var _next_spawn := 0 # tick
var _city: WeakRef


func _init(city) -> void:
	_city = weakref(city)


func count() -> int:
	return walkers.size()


func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(walkers.values())
	return result


func tick() -> void:
	var city = _city.get_ref()
	if city.clock.tick >= _next_spawn:
		_next_spawn = city.clock.tick + Balance.SETTLER_INTERVAL_TICKS
		_spawn()
	var step := Balance.SETTLER_SPEED / Balance.TICKS_PER_SECOND
	for w in all():
		if WalkerMotion.advance(w, step):
			_arrive(w)


func on_building_removed(instance: Dictionary) -> void:
	for w in all():
		if w["target"] == instance["id"]:
			_find_house(w)


func on_roads_changed() -> void:
	var city = _city.get_ref()
	for w in all():
		if not city.grid.is_road(WalkerMotion.here(w)):
			_vanish(w) # the road under their feet is gone: they leave the valley
		elif not WalkerMotion.path_still_open(w, city.grid):
			if w["state"] == "in":
				_find_house(w)
			else:
				_leave(w)


# --- Inside ---

## One group leaves the entrance for the oldest house with room.
func _spawn() -> void:
	var city = _city.get_ref()
	var start: Vector2i = city.entrance
	var waiting_houses := false
	for instance: Dictionary in city.buildings.all():
		if instance["type"] != city.houses.HOUSE:
			continue
		var room: int = city.houses.room(instance)
		if room <= 0:
			continue
		var end: Vector2i = city.carriers.access_road(instance)
		if end == NO_TILE:
			continue
		waiting_houses = true
		var path: Array[Vector2i] = city.network.path(start, end)
		if path.is_empty():
			continue
		var people := mini(room, Balance.SETTLER_GROUP)
		city.houses.state[instance["id"]]["incoming"] += people
		var w := {"id": _next_id, "people": people, "target": instance["id"], "state": "in",
			"path": path, "index": 0, "progress": 0.0}
		walkers[_next_id] = w
		_next_id += 1
		entrance_connected = true
		return
	entrance_connected = not waiting_houses


func _arrive(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w["state"] == "out":
		walkers.erase(w["id"])
		return
	var house: Dictionary = city.buildings.get_instance(w["target"])
	var s: Dictionary = city.houses.state[w["target"]]
	s["incoming"] -= w["people"]
	s["residents"] += w["people"]
	if house["tier"] == 0:
		house["tier"] = 1
	walkers.erase(w["id"])
	arrived.emit(house)


## Their house is gone or cut off: try another house with room, or walk back out.
func _find_house(w: Dictionary) -> void:
	var city = _city.get_ref()
	var old: Dictionary = city.houses.state.get(w["target"], {})
	if not old.is_empty():
		old["incoming"] -= w["people"]
	var here := WalkerMotion.here(w)
	for instance: Dictionary in city.buildings.all():
		if instance["type"] != city.houses.HOUSE or city.houses.room(instance) < w["people"]:
			continue
		var end: Vector2i = city.carriers.access_road(instance)
		if end == NO_TILE:
			continue
		var path: Array[Vector2i] = city.network.path(here, end)
		if path.is_empty():
			continue
		city.houses.state[instance["id"]]["incoming"] += w["people"]
		w["target"] = instance["id"]
		WalkerMotion.follow(w, path)
		return
	_leave(w)


## Gone from the map. The house they were walking to stops waiting for them, so the next
## group can fill it.
func _vanish(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w["state"] == "in":
		var s: Dictionary = city.houses.state.get(w["target"], {})
		if not s.is_empty():
			s["incoming"] -= w["people"]
	walkers.erase(w["id"])


func _leave(w: Dictionary) -> void:
	var city = _city.get_ref()
	w["state"] = "out"
	w["target"] = 0
	var path: Array[Vector2i] = city.network.path(WalkerMotion.here(w), city.entrance)
	if path.is_empty():
		walkers.erase(w["id"])
		return
	WalkerMotion.follow(w, path)


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"walkers": walkers, "entrance_connected": entrance_connected, "next_id": _next_id,
		"next_spawn": _next_spawn}


func load_save(d: Dictionary) -> void:
	walkers = d["walkers"]
	entrance_connected = d["entrance_connected"]
	_next_id = d["next_id"]
	_next_spawn = d["next_spawn"]
