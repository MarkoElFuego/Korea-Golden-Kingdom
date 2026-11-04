extends RefCounted
## Walkers sent out by service buildings (docs/koncept.md, "Šetači i distribucija"):
##   vendor - roaming walker from a Market; houses it passes get rice in their pantry, and
##            houses from tier 2 also Jang (Ripe first) and a set of Onggi Jars;
##   keeper - roaming walker from a Seonangdang; houses it passes remember the visit;
##   buyer  - destination walker from a Market; fetches what its emptiest stall lacks: rice
##            from a Granary, Jang from a Jangdokdae (Ripe first), Onggi Jars from a Storehouse.
##            A workshop (Onggi Kiln) or Jangdokdae that has none of an input left sends
##            one too (the fetcher): it brings that input from the nearest Storehouse
##            that holds it (Onggi Jars for the Jangdokdae).
##
## Roaming walkers keep to their building's area (coverage.gd: the streets up to
## WALKER_AREA_ROAD_TILES road tiles away, ended by Guardian Posts). The area is split into
## rounds that together walk every street of it; each walker the building sends takes the
## next round, in turn, so every house in the area is visited regularly and nobody wanders
## off. A walker serves on its round and walks home without serving.
##
## A walker is a Dictionary: id, kind, home (building id), path, index, progress
## (see walker_motion.gd), serve_end (last path index it serves), served (last index served),
## round / rounds (roaming walker: which of its building's rounds it walks, 1-based),
## food (vendor: portions of rice), jang_ripe / jang_fresh (vendor: portions of Jang),
## jars (vendor: sets of Onggi Jars), cargo (buyer: loads of `good`), want (buyer: loads it
## goes for), reserved (fetcher: loads announced at its workshop), target (buyer: storage
## id), state (buyer: "fetch" or "return").

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const Goods = preload("res://scripts/data/goods.gd")
const WalkerMotion = preload("res://scripts/sim/walker_motion.gd")

const NO_TILE := Vector2i(-1, -1)
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var walkers := {} # id -> walker
var _next_id := 1
## Service building or workshop id -> {"kind": roaming walker it sends ("workshop": none),
## "next_at": tick of the next one, "out": roaming walkers out, "round": rounds sent so far,
## "buyer": buyer walker id or 0, "buyer_retry": tick to look again}
var _homes := {}
var _city: WeakRef
var _near := {} # road tile -> ids of houses within WALKER_SERVICE_RANGE (cleared when a house comes or goes)
var _rounds := {} # building id -> its rounds (cleared when roads or Guardian Posts change)


func _init(city) -> void:
	_city = weakref(city)


func count() -> int:
	return walkers.size()


func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(walkers.values())
	return result


## Roaming walker a building sends ("vendor", "keeper"), or "".
static func roamer(type: String) -> String:
	return Buildings.get_building(type).get("roamer", "")


static func market_data(type: String) -> Dictionary:
	return Buildings.get_building(type).get("market", {})


## Loads a Market holds in one stall (all goods of the stall together).
func stall_stock(id: int, stall: Dictionary) -> int:
	var n := 0
	for good: String in stall["goods"]:
		n += _city.get_ref().economy.stock(id, good)
	return n


func roamers_out(id: int) -> int:
	return _homes.get(id, {}).get("out", 0)


func buyer_out(id: int) -> bool:
	return _homes.get(id, {}).get("buyer", 0) != 0


func tick() -> void:
	_dispatch()
	var buyer_step := Balance.BUYER_SPEED / Balance.TICKS_PER_SECOND
	var roamer_step := Balance.ROAMER_SPEED / Balance.TICKS_PER_SECOND
	for w in all():
		if not walkers.has(w["id"]):
			continue
		var done := WalkerMotion.advance(w, buyer_step if w["kind"] == "buyer" else roamer_step)
		if w["served"] < w["index"] and w["served"] < w["serve_end"]:
			_serve_passed(w) # stepped onto a new road tile on the way out
		if done:
			_arrive(w)


# --- Events from the city ---

func on_building_added(instance: Dictionary) -> void:
	if instance["type"] == "common_house":
		_near.clear()
	if Buildings.get_building(instance["type"]).get("on_road", false):
		_rounds.clear() # a Guardian Post ends areas
		_turn_back_at(instance["origin"])
	var kind := roamer(instance["type"])
	var data := Buildings.get_building(instance["type"])
	if kind == "" and not data.has("workshop") and not data.has("fermentation"):
		return
	var city = _city.get_ref()
	_homes[instance["id"]] = {"kind": kind if kind != "" else "workshop", "next_at": city.clock.tick,
		"out": 0, "round": 0, "buyer": 0, "buyer_retry": 0}


func on_building_removed(instance: Dictionary) -> void:
	var id: int = instance["id"]
	if instance["type"] == "common_house":
		_near.clear()
	_homes.erase(id)
	_rounds.clear()
	for w in all():
		if w["home"] == id:
			_drop(w) # nobody to go back to
		elif w["kind"] == "buyer" and w["target"] == id:
			_fetch(w) # another Granary, or home empty-handed


func on_roads_changed() -> void:
	_rounds.clear()
	var city = _city.get_ref()
	for w in all():
		if not city.grid.is_road(WalkerMotion.here(w)):
			_drop(w) # the road under its feet is gone
		elif not WalkerMotion.path_still_open(w, city.grid):
			if w["kind"] == "buyer" and w["state"] == "fetch":
				_fetch(w)
			else:
				_go_home(w)


## What a Market or Seonangdang is doing, for the building window.
func status(instance: Dictionary) -> Dictionary:
	var city = _city.get_ref()
	var id: int = instance["id"]
	if not _homes.has(id) or city.economy.state[id]["eff"] <= 0.0:
		return {"key": "", "args": []}
	var out := roamers_out(id)
	if roamer(instance["type"]) == "vendor":
		if buyer_out(id):
			var w: Dictionary = walkers[_homes[id]["buyer"]]
			return {"key": "STATUS_BUYER_OUT", "args": [Goods.GOODS[w["good"]]["name_key"]]}
		for stall: Dictionary in market_data(instance["type"])["stalls"]:
			if stall_stock(id, stall) <= 0:
				var good_name: String = Goods.GOODS[stall["goods"][-1]]["name_key"]
				return {"key": "STATUS_MARKET_LACKS", "args": [good_name, good_name]}
		if out > 0:
			return {"key": "STATUS_VENDORS_OUT", "args": [out]}
		return {"key": "STATUS_MARKET_READY", "args": []}
	if out > 0:
		return {"key": "STATUS_KEEPER_OUT", "args": [out]}
	return {"key": "STATUS_KEEPER_RESTS", "args": []}


# --- Sending walkers out ---

func _dispatch() -> void:
	var city = _city.get_ref()
	var now: int = city.clock.tick
	for id: int in _homes:
		var h: Dictionary = _homes[id]
		var kind: String = h["kind"]
		var roam: bool = kind != "workshop" and now >= h["next_at"] and h["out"] < Balance.ROAMER_MAX_OUT
		var buy: bool = (kind == "vendor" or kind == "workshop") and h["buyer"] == 0 and now >= h["buyer_retry"]
		if not roam and not buy:
			continue # most buildings on most ticks
		var eff: float = city.economy.state[id]["eff"]
		if eff <= 0.0:
			h["next_at"] = now + Balance.BUYER_RETRY_TICKS # nobody works here: look again soon
			h["buyer_retry"] = h["next_at"]
			continue
		var instance: Dictionary = city.buildings.get_instance(id)
		if buy:
			_dispatch_buyer(instance, h)
		if not roam:
			continue
		var w := {"id": _next_id, "kind": kind, "home": id, "path": [], "index": 0,
			"progress": 0.0, "serve_end": -1, "served": -1, "food": 0, "jang_ripe": 0,
			"jang_fresh": 0, "jars": 0, "cargo": 0, "target": 0, "state": ""}
		if kind == "vendor" and not _load_vendor(w):
			h["next_at"] = now + Balance.BUYER_RETRY_TICKS # nothing to sell yet
			continue
		var round_trip := _round(instance, h)
		if round_trip.is_empty():
			_unload_vendor(w) # nowhere to go: the goods stay at the Market
			h["next_at"] = now + Balance.TICKS_PER_DAY # no street to walk: look again tomorrow
			continue
		w["path"] = round_trip["path"]
		w["serve_end"] = round_trip["serve_end"]
		w["round"] = round_trip["round"]
		w["rounds"] = round_trip["rounds"]
		h["next_at"] = now + ceili(Balance.ROAMER_INTERVAL_DAYS * Balance.TICKS_PER_DAY / eff)
		h["out"] += 1
		walkers[_next_id] = w
		_next_id += 1


## A vendor takes goods from every stall of its Market: rice for all houses, Jang (Ripe
## first) and Onggi Jars for houses from tier 2. False when there is nothing to sell.
func _load_vendor(w: Dictionary) -> bool:
	var city = _city.get_ref()
	var id: int = w["home"]
	var any := false
	for stall: Dictionary in market_data(city.buildings.get_instance(id)["type"])["stalls"]:
		var room: int = stall["vendor_loads"]
		for good: String in stall["goods"]:
			var loads := mini(room, city.economy.stock(id, good))
			if loads <= 0:
				continue
			_sell(id, good, loads)
			room -= loads
			any = true
			match good:
				"rice":
					w["food"] += loads * Balance.FOOD_PORTIONS_PER_LOAD
				"ripe_jang":
					w["jang_ripe"] += loads * Balance.JANG_PORTIONS_RIPE
				"jang":
					w["jang_fresh"] += loads * Balance.JANG_PORTIONS_FRESH
				"onggi_jars":
					w["jars"] += loads * Balance.JAR_SETS_PER_LOAD
	return any


## Unsold whole loads go back to the Market's stalls.
func _unload_vendor(w: Dictionary) -> void:
	var portions := {"rice": [w["food"], Balance.FOOD_PORTIONS_PER_LOAD],
		"ripe_jang": [w["jang_ripe"], Balance.JANG_PORTIONS_RIPE],
		"jang": [w["jang_fresh"], Balance.JANG_PORTIONS_FRESH],
		"onggi_jars": [w["jars"], Balance.JAR_SETS_PER_LOAD]}
	for good: String in portions:
		@warning_ignore("integer_division")
		var loads: int = portions[good][0] / portions[good][1]
		if loads > 0:
			_sell(w["home"], good, -loads)
	w["food"] = 0
	w["jang_ripe"] = 0
	w["jang_fresh"] = 0
	w["jars"] = 0


## A Market low on goods sends its Buyer to the nearest Granary that has them; a workshop
## out of an input sends its fetcher to the nearest Storehouse that has it.
func _dispatch_buyer(instance: Dictionary, h: Dictionary) -> void:
	var city = _city.get_ref()
	var id: int = instance["id"]
	if h["buyer"] != 0 or city.clock.tick < h["buyer_retry"]:
		return
	var start: Vector2i = city.carriers.access_road(instance)
	var wanted: Array = [] # [good, loads] in the order to try
	if h["kind"] == "workshop":
		for good: String in city.economy.inputs(instance["type"]):
			var room: int = city.economy.input_space(instance, good)
			if city.economy.incoming(id, good) == 0 and room > 0:
				wanted.append([good, mini(room, Balance.WORKSHOP_INPUT_STORE)])
	else:
		# The emptiest stall first (by share of its room), each good of it in turn.
		# Stalls with room for a Buyer's load, the emptiest first (by share of its room; on a
		# tie, the order of the stalls), each good of a stall in turn.
		var open: Array = [] # [fill share, stall, loads in it]
		for stall: Dictionary in market_data(instance["type"])["stalls"]:
			var has := stall_stock(id, stall)
			if has > stall["capacity"] - stall["buyer_loads"]:
				continue
			var share := has / float(stall["capacity"])
			var at := open.size()
			while at > 0 and open[at - 1][0] > share:
				at -= 1
			open.insert(at, [share, stall, has])
		for item: Array in open:
			var stall: Dictionary = item[1]
			for good: String in stall["goods"]:
				wanted.append([good, mini(stall["buyer_loads"], stall["capacity"] - item[2])])
	for order: Array in wanted:
		var source: Dictionary = {} if start == NO_TILE else city.carriers.find_source(start, order[0])
		if source.is_empty():
			continue
		var reserved: int = order[1] if h["kind"] == "workshop" else 0
		if reserved > 0:
			city.economy.reserve(id, order[0], reserved) # carriers do not bring it too
		var w := {"id": _next_id, "kind": "buyer", "home": id, "path": source["path"], "index": 0,
			"progress": 0.0, "serve_end": -1, "served": -1, "food": 0, "cargo": 0,
			"target": source["id"], "state": "fetch", "good": order[0], "want": order[1],
			"reserved": reserved}
		walkers[_next_id] = w
		h["buyer"] = _next_id
		_next_id += 1
		return
	h["buyer_retry"] = city.clock.tick + Balance.BUYER_RETRY_TICKS # enough for now, or nothing to fetch


## The next round of a roaming walker: {"path", "serve_end", "round", "rounds"}, or {} when
## no street leads out. Rounds are taken in turn (h["round"] counts the ones sent).
func _round(instance: Dictionary, h: Dictionary) -> Dictionary:
	var id: int = instance["id"]
	if not _rounds.has(id):
		var grid = _city.get_ref().grid
		_rounds[id] = Coverage.walker_rounds(Coverage.walker_area(grid, instance["origin"], instance["size"], instance["rotation"]))
	var rounds: Array[Dictionary] = _rounds[id]
	if rounds.is_empty():
		return {}
	var k: int = h["round"] % rounds.size()
	h["round"] += 1
	var result: Dictionary = rounds[k].duplicate()
	result["path"] = result["path"].duplicate()
	result["round"] = k + 1
	result["rounds"] = rounds.size()
	return result


# --- On the way ---

## Serves the houses around every road tile it stepped on since the last tick.
func _serve_passed(w: Dictionary) -> void:
	while w["served"] < w["index"] and w["served"] < w["serve_end"]:
		w["served"] += 1
		_serve(w, w["path"][w["served"]])


func _serve(w: Dictionary, tile: Vector2i) -> void:
	var city = _city.get_ref()
	var now: int = city.clock.tick
	var houses = city.houses
	for id: int in _houses_near(tile):
		if w["kind"] == "vendor":
			houses.visit(id, "market", now)
			w["food"] -= houses.give_food(id, w["food"])
			if w["jang_ripe"] + w["jang_fresh"] + w["jars"] == 0 or not houses.wants_jang(id):
				continue
			var took: int = houses.give_jang(id, w["jang_ripe"] + w["jang_fresh"])
			var ripe := mini(took, w["jang_ripe"])
			w["jang_ripe"] -= ripe
			w["jang_fresh"] -= took - ripe
			if w["jars"] > 0 and houses.give_jars(id, now):
				w["jars"] -= 1
		else:
			houses.visit(id, "seonangdang", now)


## Houses within WALKER_SERVICE_RANGE of a road tile (remembered until houses change).
func _houses_near(tile: Vector2i) -> Array[int]:
	if _near.has(tile):
		return _near[tile]
	var city = _city.get_ref()
	var grid = city.grid
	var result: Array[int] = []
	var r := Balance.WALKER_SERVICE_RANGE
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tile + Vector2i(dx, dy)
			if not grid.in_bounds(t):
				continue
			var id: int = grid.get_occupant(t)
			if id > 0 and city.houses.state.has(id) and not result.has(id):
				result.append(id)
	_near[tile] = result
	return result


func _arrive(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w["kind"] == "buyer" and w["state"] == "fetch":
		var good: String = w["good"]
		var source: Dictionary = city.buildings.get_instance(w["target"])
		var take := mini(w["want"], city.economy.can_give(source, good))
		if take > 0:
			city.economy.give(w["target"], good, take, city.clock.tick)
		w["cargo"] = take
		w["target"] = 0
		_go_home(w)
		return
	var home: Dictionary = city.buildings.get_instance(w["home"])
	if not home.is_empty():
		if w["kind"] == "buyer":
			_unreserve(w)
			if w["cargo"] > 0:
				city.economy.add(w["home"], w["good"], w["cargo"])
				w["cargo"] = 0
		elif w["kind"] == "vendor":
			_unload_vendor(w)
	_drop(w)


## A Jangseung went up on `tile`: roaming walkers whose round still leads over it turn
## around there and walk back the way they came (so they never pass the statue).
func _turn_back_at(tile: Vector2i) -> void:
	for w in all():
		if w["kind"] == "buyer" or w["serve_end"] <= w["index"]:
			continue # buyers pass, and walkers already heading home are not on their round
		var ahead: Array = w["path"].slice(w["index"] + 1, w["serve_end"] + 1)
		if not ahead.has(tile):
			continue
		var back: Array[Vector2i] = []
		back.assign(w["path"].slice(0, w["index"] + 1))
		back.reverse()
		WalkerMotion.follow(w, back)
		w["serve_end"] = -1
		w["served"] = -1


## Walks home the shortest way (no more serving); gone if it cannot.
func _go_home(w: Dictionary) -> void:
	var city = _city.get_ref()
	w["serve_end"] = -1
	if w["kind"] == "buyer":
		w["state"] = "return"
	var home: Dictionary = city.buildings.get_instance(w["home"])
	var end: Vector2i = NO_TILE if home.is_empty() else city.carriers.access_road(home)
	var path: Array[Vector2i] = []
	if end != NO_TILE:
		path = city.network.path(WalkerMotion.here(w), end)
	if path.is_empty():
		_drop(w)
		return
	WalkerMotion.follow(w, path)
	w["served"] = -1


## Loads leave a Market with a vendor (negative: unsold loads come back).
func _sell(market: int, good: String, loads: int) -> void:
	var city = _city.get_ref()
	city.economy.add(market, good, -loads)
	city.economy.sold[good] = city.economy.sold.get(good, 0) + loads


## Loads of `good` buyers are carrying.
func carried(good: String) -> int:
	var n := 0
	for w: Dictionary in walkers.values():
		if w["kind"] == "buyer" and w["good"] == good:
			n += w["cargo"]
	return n


## A buyer heads for the nearest Granary with rice from where it stands, or goes home.
func _fetch(w: Dictionary) -> void:
	var city = _city.get_ref()
	var home: Dictionary = city.buildings.get_instance(w["home"])
	var source := {}
	if not home.is_empty():
		source = city.carriers.find_source(WalkerMotion.here(w), w["good"])
	if source.is_empty():
		w["target"] = 0
		_go_home(w)
		return
	w["target"] = source["id"]
	w["state"] = "fetch"
	WalkerMotion.follow(w, source["path"])


## The walker leaves the streets. A buyer's load that never got home is counted as lost.
func _drop(w: Dictionary) -> void:
	var city = _city.get_ref()
	if not walkers.has(w["id"]):
		return
	_unreserve(w)
	if w["kind"] == "buyer" and w["cargo"] > 0:
		city.economy.lost[w["good"]] = city.economy.lost.get(w["good"], 0) + w["cargo"]
	if _homes.has(w["home"]):
		var h: Dictionary = _homes[w["home"]]
		if w["kind"] == "buyer":
			h["buyer"] = 0
		else:
			h["out"] -= 1
	walkers.erase(w["id"])


## A fetcher's loads are no longer announced at its workshop (it is back, or gone).
func _unreserve(w: Dictionary) -> void:
	var city = _city.get_ref()
	if w.get("reserved", 0) > 0 and city.economy.state.has(w["home"]):
		city.economy.reserve(w["home"], w["good"], -w["reserved"])
	w["reserved"] = 0


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"walkers": walkers, "next_id": _next_id, "homes": _homes}


func load_save(d: Dictionary) -> void:
	walkers = d["walkers"]
	_next_id = d["next_id"]
	_homes = d["homes"]
	_near.clear()
	_rounds.clear()
