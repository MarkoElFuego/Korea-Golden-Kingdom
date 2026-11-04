extends RefCounted
## The Jangdokdae (docs/koncept.md, "Fermentacija"): a yard of onggi jars where Jang ripens.
##
## Every load of Onggi Jars brought to it becomes one jar (up to max_jars). Once a day, with
## workers, each empty jar takes one load of each input (Soybeans, Salt) and starts brewing;
## nature does the rest, workers or not: Fresh after fresh_days, Ripe ripe_days later.
## A Market buyer takes Jang out of the jars (economy.give), and the jar is filled again.
## Ripening turns a load of Jang into a load of Ripe Jang (counted as used and produced).
## The jars live in the Jangdokdae's economy state ("jars": [{"state", "at"}]), so they are
## saved with it. A jar's state is "empty", "brewing", "fresh" or "ripe"; "at" is the tick it
## was filled. "ripe_only" (the player's choice) keeps Fresh Jang in its jar until it is Ripe.

const Balance = preload("res://scripts/data/balance.gd")
const Economy = preload("res://scripts/sim/economy.gd")

const STATES: Array[String] = ["empty", "brewing", "fresh", "ripe"]

var _city: WeakRef


func _init(city) -> void:
	_city = weakref(city)


## Once a day: jars ripen, new jars are set out, empty jars are filled.
func daily() -> void:
	var city = _city.get_ref()
	var economy = city.economy
	var now: int = city.clock.tick
	for id: int in economy.state:
		var s: Dictionary = economy.state[id]
		if not s.has("jars"):
			continue
		var f := Economy.fermentation(s["type"])
		var fresh_at: int = f["fresh_days"] * Balance.TICKS_PER_DAY
		var ripe_at: int = fresh_at + f["ripe_days"] * Balance.TICKS_PER_DAY
		var changed := false
		for jar: Dictionary in s["jars"]:
			var age: int = now - jar["at"]
			if jar["state"] == "brewing" and age >= fresh_at:
				jar["state"] = "fresh"
				_made(economy, f["good"])
				changed = true
			elif jar["state"] == "fresh" and age >= ripe_at:
				jar["state"] = "ripe"
				economy.used[f["good"]] = economy.used.get(f["good"], 0) + 1
				_made(economy, f["ripe_good"])
				changed = true
		if s["eff"] > 0.0:
			while economy.stock(id, "onggi_jars") > 0 and s["jars"].size() < f["max_jars"]:
				economy.use(id, "onggi_jars")
				s["jars"].append({"state": "empty", "at": now})
				changed = true
			for jar: Dictionary in s["jars"]:
				if jar["state"] != "empty" or not _has_all(economy, id, f["inputs"]):
					continue
				for good: String in f["inputs"]:
					economy.use(id, good)
				jar["state"] = "brewing"
				jar["at"] = now
				changed = true
		if changed:
			economy.stock_changed.emit(id)


## Jars by state: {"jars": all, "empty", "brewing", "fresh", "ripe"}.
func counts(id: int) -> Dictionary:
	var result := {"jars": 0}
	for st in STATES:
		result[st] = 0
	for jar: Dictionary in _city.get_ref().economy.state[id]["jars"]:
		result["jars"] += 1
		result[jar["state"]] += 1
	return result


## Loads of Jang that may leave now: Ripe ones, and Fresh ones unless the player keeps
## them to ripen.
func ready(id: int) -> int:
	var c := counts(id)
	return c["ripe"] + (0 if ripe_only(id) else c["fresh"])


func ripe_only(id: int) -> bool:
	return _city.get_ref().economy.state[id]["ripe_only"]


static func _made(economy, good: String) -> void:
	economy.produced[good] = economy.produced.get(good, 0) + 1
	economy.produced_year[good] = economy.produced_year.get(good, 0) + 1
	economy.note_source(good) # a Market buyer may find it now


static func _has_all(economy, id: int, goods: Array) -> bool:
	for good: String in goods:
		if economy.stock(id, good) <= 0:
			return false
	return true
