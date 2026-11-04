extends RefCounted
## Dokkaebi, the first event (docs/koncept.md, "Dokkaebi", phase 9).
##
## At the start of every season (from the second year, once the city has
## DOKKAEBI_MIN_POPULATION people) each storage holding goods may draw them: the lower its
## Gi below DOKKAEBI_SAFE_GI, the likelier, and every Guardian Post near it halves the chance.
## At most one dokkaebi night at a time.
##
## A warning comes first: dokkaebi fires (dokkaebibul) flicker in the nearest hill or forest
## DOKKAEBI_WARNING_DAYS before they come. Then night falls and 2-3 dokkaebi walk the roads
## from there to the storage. A Guardian Post on their way turns them back. At the storage
## each carries away up to DOKKAEBI_LOADS loads (counted in economy.stolen), unless a
## Village Shrine with a buckwheat-jelly offering covers that storage: then they take
## nothing, and sometimes leave Silver.
##
## Every chance goes through the city's one rng, so the same game gives the same nights.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const Economy = preload("res://scripts/sim/economy.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const WalkerMotion = preload("res://scripts/sim/walker_motion.gd")

const NO_TILE := Vector2i(-1, -1)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SHRINE := "seonangdang"
const ADVICE_AFTER_DAYS := 5 # the top bar tells how the night went this long

## Dokkaebi nights: {"id", "target": storage id, "fire": hill tile, "start": road tile they
## set off from, "come_at": tick, "state": "warning" or "night", "taken": {good: loads},
## "turned": dokkaebi turned back, "appeased": bool, "gift": Silver left, "gift_rolled": bool}
var raids: Array = []
## id -> {"id", "raid", "path", "index", "progress", "state": "go" or "back", "wait": ticks
##        before it sets off, "cargo": good or "", "loads"}
var walkers := {}
var offerings := {} # Village Shrine id -> tick its offering lasts until
var notes := {} # storage id -> {"key", "args", "tick"}: how the last night went there
var last_note := {} # the same for the top bar: {"key", "args", "tick"}
var _next_id := 1
var _next_raid := 1
var _city: WeakRef


func _init(city) -> void:
	_city = weakref(city)


func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w: Dictionary in walkers.values():
		result.append(w)
	return result


## True while dokkaebi walk the city (the view darkens to night).
func is_night() -> bool:
	for raid: Dictionary in raids:
		if raid["state"] == "night":
			return true
	return false


## Hill tiles where dokkaebi fires flicker now (warning and night).
func fires() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raid: Dictionary in raids:
		result.append(raid["fire"])
	return result


## Chance per season that dokkaebi come for this storage (0..1).
func chance(instance: Dictionary) -> float:
	var city = _city.get_ref()
	var gi: int = city.gi.of_area(instance["origin"], instance["size"])
	var c := clampf((Balance.DOKKAEBI_SAFE_GI - gi) * Balance.DOKKAEBI_CHANCE_PER_GI, 0.0, Balance.DOKKAEBI_MAX_CHANCE)
	return c * pow(0.5, posts_near(instance))


## Guardian Posts within DOKKAEBI_POST_TILES of the building.
func posts_near(instance: Dictionary) -> int:
	var city = _city.get_ref()
	var r := Balance.DOKKAEBI_POST_TILES
	var o: Vector2i = instance["origin"]
	var s: Vector2i = instance["size"]
	var ids := {}
	for t: Vector2i in city.grid.blockers:
		if t.x >= o.x - r and t.x < o.x + s.x + r and t.y >= o.y - r and t.y < o.y + s.y + r:
			ids[city.grid.blockers[t]] = true
	return ids.size()


# --- Offerings ---

## Why an offering cannot be made at this building: a text key, or "".
func check_offering(id: int) -> String:
	var city = _city.get_ref()
	var instance: Dictionary = city.buildings.get_instance(id)
	if instance.get("type", "") != SHRINE:
		return "REASON_UNKNOWN_BUILDING"
	if offering_days(id) > 0:
		return "REASON_OFFERING_MADE"
	if city.treasury < Balance.OFFERING_COST:
		return "REASON_NOT_ENOUGH_SILVER"
	return ""


## The shrine's offering starts now (the city takes the Silver).
func start_offering(id: int) -> void:
	var city = _city.get_ref()
	offerings[id] = city.clock.tick + Balance.OFFERING_DAYS * Balance.TICKS_PER_DAY


## Whole days the shrine's offering still lasts (0: none).
func offering_days(id: int) -> int:
	var left: int = offerings.get(id, 0) - _city.get_ref().clock.tick
	return maxi(0, ceili(left / float(Balance.TICKS_PER_DAY)))


## True when a shrine with an offering covers this storage (its entrance road is in the
## shrine's walker area).
func appeased(instance: Dictionary) -> bool:
	var city = _city.get_ref()
	var road: Vector2i = city.carriers.access_road(instance)
	if road == NO_TILE:
		return false
	for id: int in offerings:
		if offering_days(id) <= 0:
			continue
		var shrine: Dictionary = city.buildings.get_instance(id)
		if shrine.is_empty():
			continue
		var area := Coverage.walker_area(city.grid, shrine["origin"], shrine["size"], shrine["rotation"])
		if not area.is_empty() and area["parent"].has(road):
			return true
	return false


# --- Events from the city ---

func on_building_removed(instance: Dictionary) -> void:
	offerings.erase(instance["id"])
	notes.erase(instance["id"])


## At the start of a season: do dokkaebi come this time, and for which storage?
func season_start() -> void:
	var city = _city.get_ref()
	if city.clock.get_year() < Balance.DOKKAEBI_FIRST_YEAR or city.population() < Balance.DOKKAEBI_MIN_POPULATION:
		return
	if not raids.is_empty():
		return # one night at a time
	var drawn: Array[Dictionary] = []
	for instance: Dictionary in city.buildings.all():
		if Economy.storage(instance["type"]).is_empty() or city.economy.total_stock(instance["id"]) == 0:
			continue
		var c := chance(instance)
		if c > 0.0 and city.rng.randf() < c:
			drawn.append(instance)
	if drawn.is_empty():
		return
	plan_raid(drawn[city.rng.randi() % drawn.size()])


## Dokkaebi will come for this storage in DOKKAEBI_WARNING_DAYS (tests call it directly).
## False when there is no hill and road to come by.
func plan_raid(target: Dictionary) -> bool:
	var city = _city.get_ref()
	var access: Vector2i = city.carriers.access_road(target)
	if access == NO_TILE:
		return false
	var fire := _hill_near(target)
	var start := _road_near(fire, access)
	if start == NO_TILE:
		return false
	raids.append({"id": _next_raid, "target": target["id"], "fire": fire, "start": start,
		"come_at": city.clock.tick + Balance.DOKKAEBI_WARNING_DAYS * Balance.TICKS_PER_DAY,
		"state": "warning", "taken": {}, "turned": 0, "appeased": false, "gift": 0, "gift_rolled": false})
	_next_raid += 1
	return true


func tick() -> void:
	if raids.is_empty():
		return
	var city = _city.get_ref()
	for raid: Dictionary in raids.duplicate():
		if raid["state"] == "warning" and city.clock.tick >= raid["come_at"]:
			_nightfall(raid)
	var step := Balance.DOKKAEBI_SPEED / Balance.TICKS_PER_SECOND
	for w in all():
		if w["wait"] > 0:
			w["wait"] -= 1
			continue
		if not WalkerMotion.path_still_open(w, city.grid):
			_vanish(w) # the road is gone: back into the dark
			continue
		var done := WalkerMotion.advance(w, step)
		if w["state"] == "go" and not done and city.grid.is_blocked(w["path"][w["index"] + 1]):
			_turn_back(w) # a Guardian Post stands ahead
			continue
		if done:
			if w["state"] == "go":
				_at_storage(w)
			else:
				_vanish(w)
	for raid: Dictionary in raids.duplicate():
		if raid["state"] == "night" and _walkers_of(raid["id"]) == 0:
			_dawn(raid)


func _nightfall(raid: Dictionary) -> void:
	var city = _city.get_ref()
	var target: Dictionary = city.buildings.get_instance(raid["target"])
	var path: Array[Vector2i] = []
	if not target.is_empty():
		var access: Vector2i = city.carriers.access_road(target)
		if access != NO_TILE:
			path = city.network.path(raid["start"], access)
	if path.is_empty():
		raids.erase(raid) # the storage or the way to it is gone
		return
	raid["state"] = "night"
	var count: int = city.rng.randi_range(Balance.DOKKAEBI_COUNT_MIN, Balance.DOKKAEBI_COUNT_MAX)
	for i in count:
		var w := {"id": _next_id, "raid": raid["id"], "state": "go", "wait": i * Balance.DOKKAEBI_SPACING_TICKS,
			"cargo": "", "loads": 0}
		WalkerMotion.follow(w, path.duplicate())
		walkers[_next_id] = w
		_next_id += 1


func _raid(id: int) -> Dictionary:
	for raid: Dictionary in raids:
		if raid["id"] == id:
			return raid
	return {}


func _walkers_of(raid_id: int) -> int:
	var n := 0
	for w: Dictionary in walkers.values():
		if w["raid"] == raid_id:
			n += 1
	return n


func _turn_back(w: Dictionary) -> void:
	_raid(w["raid"])["turned"] += 1
	_go_back(w)


func _go_back(w: Dictionary) -> void:
	var back: Array[Vector2i] = []
	for i in range(w["index"], -1, -1):
		back.append(w["path"][i])
	w["state"] = "back"
	WalkerMotion.follow(w, back)
	if back.size() <= 1:
		_vanish(w)


func _vanish(w: Dictionary) -> void:
	walkers.erase(w["id"])


## At the storage: take goods, or, where a shrine has an offering, play and maybe leave Silver.
func _at_storage(w: Dictionary) -> void:
	var city = _city.get_ref()
	var raid := _raid(w["raid"])
	var target: Dictionary = city.buildings.get_instance(raid["target"])
	if target.is_empty():
		_go_back(w)
		return
	if appeased(target):
		raid["appeased"] = true
		if not raid["gift_rolled"]:
			raid["gift_rolled"] = true
			if city.rng.randf() < Balance.OFFERING_GIFT_CHANCE:
				raid["gift"] = Balance.OFFERING_GIFT
				city.receive_gift(Balance.OFFERING_GIFT)
		_go_back(w)
		return
	var good := _most_stocked(raid["target"])
	if good != "":
		var loads := mini(Balance.DOKKAEBI_LOADS, city.economy.stock(raid["target"], good))
		city.economy.add(raid["target"], good, -loads)
		city.economy.stolen[good] = city.economy.stolen.get(good, 0) + loads
		raid["taken"][good] = raid["taken"].get(good, 0) + loads
		w["cargo"] = good
		w["loads"] = loads
	_go_back(w)


## The good this storage holds most of ("" when it is empty).
func _most_stocked(id: int) -> String:
	var stock: Dictionary = _city.get_ref().economy.state[id]["stock"]
	var best := ""
	var goods: Array = stock.keys()
	goods.sort()
	for good: String in goods:
		if stock[good] > 0 and (best == "" or stock[good] > stock[best]):
			best = good
	return best


## Every dokkaebi has gone: the storage window (and the top bar) tell how the night went.
func _dawn(raid: Dictionary) -> void:
	var city = _city.get_ref()
	raids.erase(raid)
	var target: Dictionary = city.buildings.get_instance(raid["target"])
	if target.is_empty():
		return
	var note := {}
	var total := 0
	var most := ""
	for good: String in raid["taken"]:
		total += raid["taken"][good]
		if most == "" or raid["taken"][good] > raid["taken"][most]:
			most = good
	if total > 0:
		note = {"key": "DOKKAEBI_NOTE_TOOK", "args": [total, Goods.GOODS[most]["name_key"]]}
	elif raid["appeased"]:
		note = {"key": "DOKKAEBI_NOTE_GIFT", "args": [raid["gift"]]} if raid["gift"] > 0 \
			else {"key": "DOKKAEBI_NOTE_APPEASED", "args": []}
	elif raid["turned"] > 0:
		note = {"key": "DOKKAEBI_NOTE_TURNED", "args": []}
	else:
		note = {"key": "DOKKAEBI_NOTE_NOTHING", "args": []}
	note["tick"] = city.clock.tick
	notes[raid["target"]] = note
	last_note = note.duplicate()
	last_note["args"] = note["args"].duplicate()


## How the last dokkaebi night went at this storage, while it is news: {"key", "args"} or {}.
func note(id: int) -> Dictionary:
	var n: Dictionary = notes.get(id, {})
	if n.is_empty() or _city.get_ref().clock.tick - n["tick"] > Balance.DOKKAEBI_NOTE_DAYS * Balance.TICKS_PER_DAY:
		return {}
	return n


## The advisor's line in the top bar: {"key", "args"} or {}.
func advice() -> Dictionary:
	var city = _city.get_ref()
	for raid: Dictionary in raids:
		var target: Dictionary = city.buildings.get_instance(raid["target"])
		var name_key: String = Buildings.get_building(target.get("type", "granary"))["name_key"]
		if raid["state"] == "night":
			return {"key": "ADVICE_DOKKAEBI_NIGHT", "args": [name_key]}
		var days := ceili((raid["come_at"] - city.clock.tick) / float(Balance.TICKS_PER_DAY))
		return {"key": "ADVICE_DOKKAEBI_COMING", "args": [name_key, maxi(1, days)]}
	if not last_note.is_empty() and city.clock.tick - last_note["tick"] <= ADVICE_AFTER_DAYS * Balance.TICKS_PER_DAY:
		return {"key": last_note["key"], "args": last_note["args"]}
	return {}


## The hill, mountain or forest tile nearest the storage (where the fires show); the city
## entrance when there is none near.
func _hill_near(target: Dictionary) -> Vector2i:
	var city = _city.get_ref()
	var grid = city.grid
	var dist := {}
	var queue: Array[Vector2i] = []
	for dy in target["size"].y:
		for dx in target["size"].x:
			var t: Vector2i = target["origin"] + Vector2i(dx, dy)
			dist[t] = 0
			queue.append(t)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var terrain: int = grid.get_terrain(t)
		if terrain == Terrain.FOREST or terrain == Terrain.MOUNTAIN or terrain == Terrain.ROCKY_HILL:
			return t
		if dist[t] >= Balance.DOKKAEBI_HILL_REACH:
			continue
		for d in DIRS:
			var n := t + d
			if grid.in_bounds(n) and not dist.has(n):
				dist[n] = dist[t] + 1
				queue.append(n)
	return city.entrance


## The road tile nearest the fire from which the roads lead to `access`; NO_TILE if none.
func _road_near(fire: Vector2i, access: Vector2i) -> Vector2i:
	var city = _city.get_ref()
	var grid = city.grid
	var seen := {fire: true}
	var queue: Array[Vector2i] = [fire]
	var head := 0
	var tries := 0
	while head < queue.size() and tries < 20:
		var t := queue[head]
		head += 1
		if grid.is_road(t) and not grid.is_blocked(t):
			tries += 1
			if not city.network.path(t, access).is_empty():
				return t
		for d in DIRS:
			var n := t + d
			if grid.in_bounds(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return NO_TILE


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"raids": raids, "walkers": walkers, "offerings": offerings, "notes": notes,
		"last_note": last_note, "next_id": _next_id, "next_raid": _next_raid}


func load_save(d: Dictionary) -> void:
	raids = d["raids"]
	walkers = d["walkers"]
	offerings = d["offerings"]
	notes = d["notes"]
	last_note = d["last_note"]
	_next_id = d["next_id"]
	_next_raid = d["next_raid"]
