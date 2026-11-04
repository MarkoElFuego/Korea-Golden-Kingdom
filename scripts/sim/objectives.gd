extends RefCounted
## The scenario's goals (scripts/data/scenario.gd), one after another: what is unlocked in the
## build menu, how far the current goal is, the scheduled first dokkaebi night, and victory.
## Checked once a day, without graphics; the view only reads it.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Economy = preload("res://scripts/sim/economy.gd")
const Scenario = preload("res://scripts/data/scenario.gd")

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var index := 0 # the current goal; GOALS.size() once everything is done
var unlocked := {} # building id -> true
var started_at := 0 # tick the current goal began
var done_at: Array = [] # tick each finished goal was done
var event_at := -1 # tick the scheduled dokkaebi night is planned (-1: not yet)
var event_raid := false # the scheduled night has been planned
## The view's memory, saved with the game so a loaded game does not repeat itself:
var advice_seen := -1 # last goal whose advisor words the player closed
var victory_seen := false
var _city: WeakRef


func _init(city) -> void:
	_city = weakref(city)
	for id in Scenario.START_UNLOCKED:
		unlocked[id] = true
	_begin(0)


func is_unlocked(type: String) -> bool:
	return unlocked.has(type)


func won() -> bool:
	return index >= Scenario.GOALS.size()


func goal() -> Dictionary:
	return {} if won() else Scenario.GOALS[index]


## Which goal unlocks this building (index), or -1.
static func unlocked_by(type: String) -> int:
	for i in Scenario.GOALS.size():
		if Scenario.GOALS[i]["unlocks"].has(type):
			return i
	return -1


## Random dokkaebi stay away until the scenario has taught them.
func dokkaebi_allowed() -> bool:
	var i := _goal_index("dokkaebi")
	return i < 0 or index > i


## Whole days on the current goal.
func days_on_goal() -> int:
	return floori((_city.get_ref().clock.tick - started_at) / float(Balance.TICKS_PER_DAY))


## The current goal's conditions with how far each is: [{"condition", "have", "need", "done"}].
func progress() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if won():
		return result
	for c: Dictionary in goal()["conditions"]:
		var have := _have(c)
		var need: int = c.get("count", 1)
		result.append({"condition": c, "have": have, "need": need, "done": have >= need})
	return result


## Once a day: the scheduled dokkaebi, then is the current goal done?
func daily() -> bool:
	if won():
		return false
	var city = _city.get_ref()
	if event_at >= 0 and not event_raid and city.clock.tick >= event_at and city.dokkaebi.raids.is_empty():
		var target := _lowest_gi_storage()
		if not target.is_empty() and city.dokkaebi.plan_raid(target):
			event_raid = true
	for p in progress():
		if not p["done"]:
			return false
	done_at.append(city.clock.tick)
	_begin(index + 1)
	return true


func _begin(i: int) -> void:
	index = i
	started_at = _city.get_ref().clock.tick
	if won():
		return
	for id: String in Scenario.GOALS[i]["unlocks"]:
		unlocked[id] = true
	if Scenario.GOALS[i].get("event", "") == "dokkaebi":
		event_at = started_at + Scenario.EVENT_DELAY_DAYS * Balance.TICKS_PER_DAY
		event_raid = false


func _have(c: Dictionary) -> int:
	var city = _city.get_ref()
	match c["type"]:
		"road_tiles":
			return mini(_entrance_roads(c["count"]), c["count"])
		"population":
			return city.population()
		"buildings":
			var n := 0
			for instance: Dictionary in city.buildings.all():
				if instance["type"] == c["building"] and instance["tier"] > 0:
					n += 1
			return n
		"houses_tier":
			var n := 0
			for id: int in city.houses.state:
				if city.buildings.get_instance(id)["tier"] >= c["tier"]:
					n += 1
			return n
		"houses_with":
			var n := 0
			for id: int in city.houses.state:
				var house: Dictionary = city.buildings.get_instance(id)
				if house["tier"] > 0 and city.houses.is_met(house, c["need"]):
					n += 1
			return n
		"produced":
			return city.economy.produced.get(c["good"], 0)
		"dokkaebi_night":
			return 1 if event_raid and city.dokkaebi.raids.is_empty() else 0
	return 0


## Road tiles joined to the entrance (counts up to `limit`, then stops looking).
func _entrance_roads(limit: int) -> int:
	var grid = _city.get_ref().grid
	var start: Vector2i = _city.get_ref().entrance
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size() and seen.size() <= limit:
		var t := queue[head]
		head += 1
		for d in DIRS:
			var n := t + d
			if grid.in_bounds(n) and grid.is_road(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size()


## The storage with goods and the lowest Gi (the scheduled dokkaebi go there).
func _lowest_gi_storage() -> Dictionary:
	var city = _city.get_ref()
	var best := {}
	var best_gi := 1000
	for instance: Dictionary in city.buildings.all():
		if Economy.storage(instance["type"]).is_empty() or city.economy.total_stock(instance["id"]) == 0:
			continue
		var gi: int = city.gi.of_area(instance["origin"], instance["size"])
		if gi < best_gi:
			best = instance
			best_gi = gi
	return best


func _goal_index(id: String) -> int:
	for i in Scenario.GOALS.size():
		if Scenario.GOALS[i]["id"] == id:
			return i
	return -1


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"index": index, "unlocked": unlocked, "started_at": started_at, "done_at": done_at,
		"event_at": event_at, "event_raid": event_raid, "advice_seen": advice_seen, "victory_seen": victory_seen}


func load_save(d: Dictionary) -> void:
	index = d["index"]
	unlocked = d["unlocked"]
	started_at = d["started_at"]
	done_at = d["done_at"]
	event_at = d["event_at"]
	event_raid = d["event_raid"]
	advice_seen = d["advice_seen"]
	victory_seen = d["victory_seen"]
