extends RefCounted
## Goods held by buildings: the small store of a producing building, the Granary and
## the Storehouse. Also runs production (phase 3: fixed rate, no workers).
## Counts every load produced and every load destroyed with a demolished building,
## so tests can check that no goods appear or vanish.
##
## Production is scheduled: a building is looked at only on the tick its next load is
## ready, so a big city costs nothing while its fields grow. A full store pauses
## production; it starts again (a full period) when a carrier takes a load.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")

const PAUSED := -1

signal stock_changed(id: int)

## id -> {"type", "good" (what it makes, or ""), "stock": {good: loads},
##        "reserved": {good: loads on the way}, "ready_at": tick or PAUSED, "carrier": walker id}
var state := {}
var produced := {} # good -> loads produced since the start
var lost := {} # good -> loads destroyed with demolished buildings
## Producers with a load waiting and no carrier out: id -> true.
var waiting := {}

var _clock: SimClock
var _schedule := {} # tick -> [building ids whose load is ready then]


func _init(clock: SimClock) -> void:
	_clock = clock


func add_building(instance: Dictionary) -> void:
	var p := production(instance["type"])
	var s := {"type": instance["type"], "good": p.get("good", ""), "stock": {}, "reserved": {},
		"ready_at": PAUSED, "carrier": 0}
	state[instance["id"]] = s
	if not p.is_empty():
		_schedule_next(instance["id"])


func remove_building(instance: Dictionary) -> void:
	var s: Dictionary = state.get(instance["id"], {})
	for good: String in s.get("stock", {}):
		lost[good] = lost.get(good, 0) + s["stock"][good]
	state.erase(instance["id"])
	waiting.erase(instance["id"])


static func production(type: String) -> Dictionary:
	return Buildings.get_building(type).get("produces", {})


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
	if not accepts(instance["type"], good):
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
		add(id, s["good"], 1) # schedules the next load if there is room


## Production progress 0..1 for the building window (1 = store full, waiting).
func progress(instance: Dictionary) -> float:
	var s: Dictionary = state[instance["id"]]
	if s["good"] == "":
		return 0.0
	if s["ready_at"] == PAUSED:
		return 1.0
	var period := _period(s["type"])
	return 1.0 - float(s["ready_at"] - _clock.tick) / period


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
	if s["ready_at"] == PAUSED and loads < Balance.PRODUCER_STORE:
		_schedule_next(id)


func _schedule_next(id: int) -> void:
	var s: Dictionary = state[id]
	var at: int = _clock.tick + _period(s["type"])
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
