extends RefCounted
## Goods held by buildings: the small store of a producing building, the inputs of a
## workshop, the Granary and the Storehouse. Also runs production.
## Counts every load produced and every load destroyed with a demolished building,
## so tests can check that no goods appear or vanish.
##
## Production is scheduled: a building is looked at only on the tick its next load is
## ready, so a big city costs nothing while its fields grow. A full store pauses
## production; it starts again (a full period) when a carrier takes a load. Workers set the
## speed: half the workers, half the speed; none, no production (and a storage takes nothing).
## A workshop (Onggi Kiln) starts a load only with one load of each input, and uses them
## up at the start; without them it waits (WAITING_INPUT).
const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")

const PAUSED := -1 # store full
const NO_WORKERS := -2 # nobody works here
const WAITING_INPUT := -3 # a workshop without its inputs (or its workers) between loads

signal stock_changed(id: int)

## id -> {"type", "good" (what it makes, or ""), "stock": {good: loads},
##        "reserved": {good: loads on the way}, "ready_at": tick, PAUSED or NO_WORKERS,
##        "remaining": full-speed ticks left while NO_WORKERS, "eff": share of workers 0..1,
##        "carrier": walker id}
var state := {}
var produced := {} # good -> loads produced since the start
var lost := {} # good -> loads destroyed with demolished buildings
var sold := {} # good -> loads Market vendors took out to the houses
var used := {} # good -> loads workshops used up as inputs
var produced_year := {} # good -> loads produced since the year began (Goods window)
## Producers with a load waiting and no carrier out: id -> true.
var waiting := {}

var _clock: SimClock
var _schedule := {} # tick -> [building ids whose load is ready then]
var _consumers := {} # good -> workshops in the city that use it
## Change counters for carriers.gd's "no source" memory: a good's counter grows whenever a
## load of it comes into a storage, the staffing counter whenever a storage gets its first
## workers (only staffed storages are sources).
var _added := {} # good -> count
var _staffing := 0


func _init(clock: SimClock) -> void:
	_clock = clock


func add_building(instance: Dictionary) -> void:
	var p := production(instance["type"])
	var s := {"type": instance["type"], "good": p.get("good", ""), "stock": {}, "reserved": {},
		"ready_at": NO_WORKERS, "remaining": 0.0, "eff": 0.0, "carrier": 0}
	state[instance["id"]] = s
	for good: String in inputs(instance["type"]):
		_consumers[good] = _consumers.get(good, 0) + 1
	if Buildings.get_building(instance["type"])["workers"] == 0:
		s["eff"] = 1.0 # needs nobody (Well, Jangseung, houses)
	if not fermentation(instance["type"]).is_empty():
		s["jars"] = [] # fermentation.gd: one entry per jar
		s["ripe_only"] = false # the player's choice: release Jang only when Ripe
	elif not inputs(instance["type"]).is_empty():
		s["ready_at"] = WAITING_INPUT # starts when workers and inputs arrive
	elif not p.is_empty():
		s["remaining"] = float(_period(instance["type"])) # starts when workers arrive


func remove_building(instance: Dictionary) -> void:
	var s: Dictionary = state.get(instance["id"], {})
	for good: String in inputs(instance["type"]) if not s.is_empty() else []:
		_consumers[good] -= 1
	for good: String in s.get("stock", {}):
		lost[good] = lost.get(good, 0) + s["stock"][good]
	for jar: Dictionary in s.get("jars", []):
		if jar["state"] == "fresh" or jar["state"] == "ripe":
			var made: String = fermentation(instance["type"])["good"]
			lost[made] = lost.get(made, 0) + 1
	state.erase(instance["id"])
	waiting.erase(instance["id"])


static func production(type: String) -> Dictionary:
	return Buildings.get_building(type).get("produces", {})


## Workshops in the city that use `good` as an input.
func consumers(good: String) -> int:
	return _consumers.get(good, 0)


## Goods a workshop uses for every load it makes, or a Jangdokdae takes in (its inputs and
## Onggi Jars, which become its jars). [] for other buildings.
static func inputs(type: String) -> Array:
	var f := fermentation(type)
	if not f.is_empty():
		return f["inputs"] + ["onggi_jars"]
	return Buildings.get_building(type).get("workshop", {}).get("inputs", [])


static func fermentation(type: String) -> Dictionary:
	return Buildings.get_building(type).get("fermentation", {})


static func storage(type: String) -> Dictionary:
	return Buildings.get_building(type).get("storage", {})


func stock(id: int, good: String) -> int:
	return state[id]["stock"].get(good, 0)


func total_stock(id: int) -> int:
	var n := 0
	for good: String in state[id]["stock"]:
		n += state[id]["stock"][good]
	return n


func add(id: int, good: String, loads: int) -> void:
	var s: Dictionary = state[id]
	var st: Dictionary = s["stock"]
	st[good] = st.get(good, 0) + loads
	if st[good] == 0:
		st.erase(good)
	if loads > 0 and not storage(s["type"]).is_empty():
		_added[good] = _added.get(good, 0) + 1
	if s["good"] != "":
		_update_producer(id)
	stock_changed.emit(id)


func reserve(id: int, good: String, loads: int) -> void:
	var r: Dictionary = state[id]["reserved"]
	r[good] = r.get(good, 0) + loads
	if r[good] <= 0:
		r.erase(good)


## A producer sent out (walker id) or got back (0) its carrier.
func set_carrier(id: int, walker_id: int) -> void:
	state[id]["carrier"] = walker_id
	_update_producer(id)


func accepts(type: String, good: String) -> bool:
	var st := storage(type)
	return not st.is_empty() and st["accepts"] == Goods.kind(good)


## Loads of `good` this storage can still take, counting loads already on the way.
func free_space(instance: Dictionary, good: String) -> int:
	if not accepts(instance["type"], good) or state[instance["id"]]["eff"] <= 0.0:
		return 0
	var st := storage(instance["type"])
	var s: Dictionary = state[instance["id"]]
	if st.has("slots"):
		var slot: int = st["slot_size"]
		var used := 0
		var mine := 0
		for g: String in _goods_in(s):
			var n := _incoming(s, g)
			used += ceili(n / float(slot))
			if g == good:
				mine = n
		return (ceili(mine / float(slot)) * slot - mine) + (st["slots"] - used) * slot
	var total := 0
	for g: String in _goods_in(s):
		total += _incoming(s, g)
	return st["capacity"] - total


## Loads of input `good` a staffed workshop can still take, counting loads on the way.
func input_space(instance: Dictionary, good: String) -> int:
	if not inputs(instance["type"]).has(good) or state[instance["id"]]["eff"] <= 0.0:
		return 0
	var s: Dictionary = state[instance["id"]]
	var room := Balance.WORKSHOP_INPUT_STORE
	if s.has("jars") and good == "onggi_jars":
		room = fermentation(instance["type"])["max_jars"] - s["jars"].size() # one jar per load
	return maxi(0, room - _incoming(s, good))


## Changes since which a storage could newly hold `good` for a fetcher: [loads added, staffing].
func source_version(good: String) -> Array:
	return [_added.get(good, 0), _staffing]


## One load of an input is used up (a workshop starts a load, a jar is filled or set out).
## The caller emits stock_changed once it is done.
func use(id: int, good: String) -> void:
	var st: Dictionary = state[id]["stock"]
	st[good] -= 1
	if st[good] == 0:
		st.erase(good)
	used[good] = used.get(good, 0) + 1


## Loads of `good` in the building plus loads on the way to it.
func incoming(id: int, good: String) -> int:
	return _incoming(state[id], good)


## A new year: the yearly production count starts again.
func new_year() -> void:
	produced_year.clear()


## Capacity of a storage in loads (all slots together).
static func capacity(type: String) -> int:
	var st := storage(type)
	if st.has("slots"):
		return st["slots"] * st["slot_size"]
	return st.get("capacity", 0)


## Production for the current tick: only buildings whose load is ready now.
func produce_tick() -> void:
	var now := _clock.tick
	if not _schedule.has(now):
		return
	var ids: Array = _schedule[now]
	_schedule.erase(now)
	ids.sort()
	for id: int in ids:
		var s: Dictionary = state.get(id, {})
		if s.is_empty() or s["ready_at"] != now:
			continue # demolished or rescheduled
		s["ready_at"] = PAUSED
		produced[s["good"]] = produced.get(s["good"], 0) + 1
		produced_year[s["good"]] = produced_year.get(s["good"], 0) + 1
		add(id, s["good"], 1) # schedules the next load if there is room


## Production progress 0..1 for the building window (1 = store full, waiting).
func progress(instance: Dictionary) -> float:
	var s: Dictionary = state[instance["id"]]
	if s["good"] == "":
		return 0.0
	if s["ready_at"] == PAUSED:
		return 1.0
	if s["ready_at"] == WAITING_INPUT:
		return 0.0
	var period := _period(s["type"])
	if s["ready_at"] == NO_WORKERS:
		return 1.0 - s["remaining"] / period
	return 1.0 - float(s["ready_at"] - _clock.tick) * s["eff"] / period


## New share of workers (0..1). A producer keeps the work already done and finishes
## the rest at the new speed.
func set_efficiency(id: int, eff: float) -> void:
	var s: Dictionary = state[id]
	var old: float = s["eff"]
	if is_equal_approx(old, eff):
		return
	s["eff"] = eff
	if old <= 0.0 and not storage(s["type"]).is_empty():
		_staffing += 1
	if s["ready_at"] == WAITING_INPUT:
		if eff > 0.0:
			_update_producer(id) # workers came: start if the inputs are here
		return
	if s["good"] == "" or s["ready_at"] == PAUSED:
		return # storage, or a full store that resumes later at the new speed
	var remaining: float = s["remaining"] if s["ready_at"] == NO_WORKERS else (s["ready_at"] - _clock.tick) * old
	_continue(id, remaining)


static func _period(type: String) -> int:
	return production(type)["days"] * Balance.TICKS_PER_DAY


## Keeps a producer's schedule and its place in `waiting` in step with its store.
func _update_producer(id: int) -> void:
	var s: Dictionary = state[id]
	var loads: int = s["stock"].get(s["good"], 0)
	if loads > 0 and s["carrier"] == 0:
		waiting[id] = true
	else:
		waiting.erase(id)
	if (s["ready_at"] == PAUSED or s["ready_at"] == WAITING_INPUT) and loads < Balance.PRODUCER_STORE:
		_schedule_next(id)


## Starts the next load. A workshop first takes one load of each input; without them
## (or without workers) it waits.
func _schedule_next(id: int) -> void:
	var s: Dictionary = state[id]
	var needed := inputs(s["type"])
	if not needed.is_empty():
		if s["eff"] <= 0.0:
			s["ready_at"] = WAITING_INPUT
			return
		for good: String in needed:
			if s["stock"].get(good, 0) <= 0:
				s["ready_at"] = WAITING_INPUT
				return
		for good: String in needed:
			use(id, good)
		stock_changed.emit(id)
	_continue(id, float(_period(s["type"])))


## Schedules the next load after `remaining` ticks of full-speed work, at the current speed.
func _continue(id: int, remaining: float) -> void:
	var s: Dictionary = state[id]
	if s["eff"] <= 0.0:
		s["ready_at"] = NO_WORKERS
		s["remaining"] = remaining
		return
	var at: int = _clock.tick + maxi(1, ceili(remaining / s["eff"] - 0.0001))
	s["ready_at"] = at
	if not _schedule.has(at):
		_schedule[at] = []
	_schedule[at].append(id)


static func _goods_in(s: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for g: String in s["stock"]:
		result.append(g)
	for g: String in s["reserved"]:
		if not result.has(g):
			result.append(g)
	result.sort()
	return result


static func _incoming(s: Dictionary, good: String) -> int:
	return s["stock"].get(good, 0) + s["reserved"].get(good, 0)


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"state": state, "produced": produced, "lost": lost, "sold": sold, "waiting": waiting,
		"schedule": _schedule, "used": used, "produced_year": produced_year}


func load_save(d: Dictionary) -> void:
	state = d["state"]
	produced = d["produced"]
	lost = d["lost"]
	sold = d["sold"]
	waiting = d["waiting"]
	_schedule = d["schedule"]
	used = d["used"]
	produced_year = d["produced_year"]
	_consumers.clear()
	for s: Dictionary in state.values():
		for good: String in inputs(s["type"]):
			_consumers[good] = _consumers.get(good, 0) + 1
