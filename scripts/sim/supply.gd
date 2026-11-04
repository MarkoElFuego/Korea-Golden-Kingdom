extends RefCounted
## Where goods are missing and why (CLAUDE.md, lesson 8: the game always says where the
## bottleneck is). Reads the city; changes nothing.
##
## status(instance) is one sentence for a producing building, workshop or Jangdokdae:
##   {"key": text key, "args": [...] (String args are text keys too), "good": the good it is
##    about or "", "stopped": true when the building stands still because of it}.
## report() is the Goods window: one row per good.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")

const NO_TILE := Vector2i(-1, -1)

var _city: WeakRef


func _init(city) -> void:
	_city = weakref(city)


## What a producing building or workshop is doing, or why it is not.
func status(instance: Dictionary) -> Dictionary:
	var city = _city.get_ref()
	var economy = city.economy
	var id: int = instance["id"]
	var s: Dictionary = economy.state[id]
	var good: String = s["good"]
	var start: Vector2i = city.carriers.access_road(instance)
	if start == NO_TILE:
		return _say("STATUS_NO_ROAD_CARRIERS", [], "", false) # the red "!" already shows it
	if s["eff"] <= 0.0:
		return _say("STATUS_NO_WORKERS", [], "", true)
	if s.has("jars"):
		return _jangdokdae(instance, start)
	if s["ready_at"] == economy.WAITING_INPUT:
		var missing := _missing_input(instance)
		if missing != "":
			if economy.incoming(id, missing) > 0:
				var fetcher: bool = city.services.buyer_out(id)
				return _say("STATUS_FETCHER_OUT" if fetcher else "STATUS_INPUT_ON_WAY", [_name(missing)], missing, false)
			if not city.carriers.find_source(start, missing).is_empty():
				return _say("STATUS_FETCHER_SOON", [_name(missing)], missing, false)
			return _say("STATUS_NO_INPUT", [_name(missing)], missing, true)
	var loads: int = economy.stock(id, good)
	var full := loads >= Balance.PRODUCER_STORE
	if loads > 0 and city.carriers.find_storage(start, good).is_empty():
		if Goods.kind(good) == "ingredient":
			var key := "STATUS_NO_JANGDOKDAE" if city.carriers.takers(good) == 0 else "STATUS_JANGDOKDAE_NO_ROOM"
			return _say(key, [_name(good)], good, full)
		var key := "STATUS_NO_GRANARY" if Goods.kind(good) == "food" else "STATUS_NO_STOREHOUSE"
		return _say(key, [], good, full)
	var progress := roundi(economy.progress(instance) * 100)
	if s["carrier"] != 0 and not full:
		return _say("STATUS_CARRIER_OUT", [progress], "", false)
	if s["eff"] < 1.0:
		return _say("STATUS_PRODUCING_SLOW", [roundi(s["eff"] * 100), progress], "", false)
	return _say("STATUS_PRODUCING", [progress], "", false)


## A Jangdokdae: no jars yet, empty jars waiting for an input, or how its jars stand.
func _jangdokdae(instance: Dictionary, start: Vector2i) -> Dictionary:
	var city = _city.get_ref()
	var economy = city.economy
	var id: int = instance["id"]
	var c: Dictionary = city.fermentation.counts(id)
	var f: Dictionary = economy.fermentation(instance["type"])
	if c["jars"] == 0:
		if economy.incoming(id, "onggi_jars") > 0:
			return _say("STATUS_INPUT_ON_WAY", [_name("onggi_jars")], "onggi_jars", false)
		if not city.carriers.find_source(start, "onggi_jars").is_empty():
			return _say("STATUS_FETCHER_SOON", [_name("onggi_jars")], "onggi_jars", false)
		return _say("STATUS_NO_JARS", [], "onggi_jars", true)
	if c["empty"] > 0:
		for good: String in f["inputs"]:
			if economy.stock(id, good) > 0:
				continue
			if economy.incoming(id, good) > 0:
				return _say("STATUS_INPUT_ON_WAY", [_name(good)], good, false)
			return _say("STATUS_JARS_WAIT_FOR", [c["empty"], _name(good)], good, c["brewing"] == 0)
	if c["empty"] == 0 and c["brewing"] == 0:
		return _say("STATUS_JARS_ALL_FULL", [c["fresh"], c["ripe"]], "", false)
	return _say("STATUS_JANGDOKDAE", [c["jars"], f["max_jars"], c["brewing"], c["fresh"], c["ripe"]], "", false)


## The good a building makes (a producer's, or the Jangdokdae's Jang), or "".
static func _made(s: Dictionary) -> String:
	if s["good"] != "":
		return s["good"]
	return Buildings.get_building(s["type"]).get("fermentation", {}).get("good", "")


## The first input a waiting workshop has none of, or "".
func _missing_input(instance: Dictionary) -> String:
	var economy = _city.get_ref().economy
	for good: String in economy.inputs(instance["type"]):
		if economy.stock(instance["id"], good) <= 0:
			return good
	return ""


## Producing buildings and workshops that stand still: [{"id", "status"}], oldest first.
func stopped() -> Array[Dictionary]:
	var city = _city.get_ref()
	var result: Array[Dictionary] = []
	for id: int in city.economy.state:
		if _made(city.economy.state[id]) == "":
			continue
		var st := status(city.buildings.get_instance(id))
		if st["stopped"]:
			result.append({"id": id, "status": st})
	return result


## One row per good for the Goods window:
## {"good", "stored" (in Granaries and Storehouses; Jang and Ripe Jang: in the jars),
##  "moving" (on walkers' backs),
##  "year" (made this year), "makers" (buildings that make it), "idle" (of them stopped),
##  "note" (status of the first stopped maker, or a line when nothing makes it, or {})}.
func report() -> Array[Dictionary]:
	var city = _city.get_ref()
	var economy = city.economy
	var rows := {}
	for good: String in Goods.ids():
		rows[good] = {"good": good, "stored": 0, "moving": city.carriers.carried(good) + city.services.carried(good),
			"year": economy.produced_year.get(good, 0), "stolen": economy.stolen.get(good, 0), "makers": 0, "idle": 0, "note": {}}
	for id: int in economy.state:
		var s: Dictionary = economy.state[id]
		if not economy.storage(s["type"]).is_empty():
			for good: String in s["stock"]:
				rows[good]["stored"] += s["stock"][good]
		if s.has("jars"):
			var c: Dictionary = city.fermentation.counts(id)
			var f: Dictionary = economy.fermentation(s["type"])
			rows[f["good"]]["stored"] += c["fresh"]
			rows[f["ripe_good"]]["stored"] += c["ripe"]
			rows[f["ripe_good"]]["makers"] += 1 # the same yard makes both
		if _made(s) == "":
			continue
		var row: Dictionary = rows[_made(s)]
		row["makers"] += 1
		var st := status(city.buildings.get_instance(id))
		if st["stopped"]:
			row["idle"] += 1
			if row["note"].is_empty():
				row["note"] = st
	for good: String in rows:
		var row: Dictionary = rows[good]
		if row["makers"] == 0:
			row["note"] = _say("NOTE_NO_MAKER", [_maker_name(good)], good, false)
	var result: Array[Dictionary] = []
	result.assign(rows.values())
	return result


## Name key of the building that makes `good`.
static func _maker_name(good: String) -> String:
	for b in Buildings.MVP_BUILDINGS:
		var f: Dictionary = b.get("fermentation", {})
		if b.get("produces", {}).get("good", "") == good or f.get("good", "") == good or f.get("ripe_good", "") == good:
			return b["name_key"]
	return ""


static func _name(good: String) -> String:
	return Goods.GOODS[good]["name_key"]


static func _say(key: String, args: Array, good: String, is_stopped: bool) -> Dictionary:
	return {"key": key, "args": args, "good": good, "stopped": is_stopped}
