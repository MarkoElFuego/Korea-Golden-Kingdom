extends RefCounted
## Common houses: residents, needs, rising and falling tiers, and the seasonal tax
## (docs/koncept.md, "Stanovanje", MVP simplification with 3 tiers).
##
## Tier 0 is a vacant lot; settlers make it a Choga Hut (tier 1). Once a day a house rises
## a tier if it has every need of the next tier (needs add up tier by tier), and drops a
## tier after missing a need of its own tier for HOUSE_DOWN_DAYS days. Tier 1 is the floor
## for a settled house.
##
## Water comes from a Well within its radius. Food and services come with walkers
## (services.gd): a Market vendor fills the pantry, which the residents eat from every day;
## a shrine keeper's visit counts for SERVICE_DAYS days. From tier 2 the vendor also fills a
## Jang pantry (eaten like rice; Ripe Jang lasts twice as long) and leaves a set of Onggi
## Jars that lasts JARS_LAST_DAYS: with both, a Choga House becomes a Giwa House.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")

const HOUSE := "common_house"

## id -> {"residents": people, "incoming": people walking here, "missing_days": days,
##        "food": portions in the pantry, "jang": portions of Jang, "jars_until": tick its
##        Onggi Jars last until, "visits": {service: tick of the last walker}}
var state := {}
var _city: WeakRef
static var _needs := {} # tier -> needs_for(tier), built once
var _cache := {} # derived from the buildings; cleared when buildings change (clear_cache)


func _init(city) -> void:
	_city = weakref(city)


func add_building(instance: Dictionary) -> void:
	if instance["type"] == HOUSE:
		state[instance["id"]] = {"residents": 0, "incoming": 0, "missing_days": 0, "food": 0, "jang": 0,
			"jars_until": 0, "visits": {}}


func remove_building(instance: Dictionary) -> void:
	state.erase(instance["id"])


func population() -> int:
	var n := 0
	for s: Dictionary in state.values():
		n += s["residents"]
	return n


static func tier_data(tier: int) -> Dictionary:
	var tiers: Array = Buildings.get_building(HOUSE)["tiers"]
	return tiers[clampi(tier, 1, tiers.size()) - 1]


static func max_tier() -> int:
	return Buildings.get_building(HOUSE)["tiers"].size()


## People the house holds at its tier (a vacant lot waits for a Choga Hut's worth).
static func capacity(tier: int) -> int:
	return tier_data(maxi(tier, 1))["residents"]


## Every need of `tier`, including the needs of the tiers below.
static func needs_for(tier: int) -> Array[String]:
	if _needs.has(tier):
		return _needs[tier]
	var result: Array[String] = []
	for t in range(1, tier + 1):
		for need: String in tier_data(t)["needs"]:
			result.append(need)
	_needs[tier] = result
	return result


## People this house can still take, counting settlers already on the way.
func room(instance: Dictionary) -> int:
	var s: Dictionary = state[instance["id"]]
	return capacity(instance["tier"]) - s["residents"] - s["incoming"]


func is_met(instance: Dictionary, need: String) -> bool:
	match need:
		"road":
			return _city.get_ref().carriers.access_road(instance) != Vector2i(-1, -1) # cached
		"water":
			return _watered().has(instance["id"])
		"food":
			return state[instance["id"]]["food"] > 0
		"seonangdang":
			var since := days_since(instance["id"], "seonangdang")
			return since >= 0 and since < Balance.SERVICE_DAYS
		"jang":
			return state[instance["id"]]["jang"] > 0
		"onggi_jars":
			return state[instance["id"]]["jars_until"] > _city.get_ref().clock.tick
	return false


## Portions the pantry holds when full (PANTRY_DAYS for the house's people at its tier).
static func pantry_size(tier: int) -> int:
	return 0 if tier == 0 else capacity(tier) * Balance.PANTRY_DAYS


## A vendor offers `portions`; returns how many the pantry took.
func give_food(id: int, portions: int) -> int:
	var tier: int = _city.get_ref().buildings.get_instance(id)["tier"]
	var s: Dictionary = state[id]
	var n := clampi(pantry_size(tier) - s["food"], 0, portions)
	s["food"] += n
	return n


## Houses from tier 2 want Jang and Onggi Jars (the needs of the next tier).
func wants_jang(id: int) -> bool:
	return _city.get_ref().buildings.get_instance(id)["tier"] >= 2


## A vendor offers `portions` of Jang; returns how many the Jang pantry took.
func give_jang(id: int, portions: int) -> int:
	var tier: int = _city.get_ref().buildings.get_instance(id)["tier"]
	var s: Dictionary = state[id]
	var n := clampi(pantry_size(tier) - s["jang"], 0, portions)
	s["jang"] += n
	return n


## A vendor offers a set of Onggi Jars; true when the house took it (its old set is gone
## or has less than JARS_RENEW_DAYS left).
func give_jars(id: int, tick: int) -> bool:
	var s: Dictionary = state[id]
	if s["jars_until"] - tick > Balance.JARS_RENEW_DAYS * Balance.TICKS_PER_DAY:
		return false
	s["jars_until"] = tick + Balance.JARS_LAST_DAYS * Balance.TICKS_PER_DAY
	return true


## Days the Jang pantry lasts at the current number of residents.
func jang_days(id: int) -> int:
	var s: Dictionary = state[id]
	return 0 if s["residents"] == 0 else floori(s["jang"] / float(s["residents"]))


## Whole days the house's Onggi Jars still last (0 when it has none).
func jars_days(id: int) -> int:
	var left: int = state[id]["jars_until"] - _city.get_ref().clock.tick
	return maxi(0, floori(left / float(Balance.TICKS_PER_DAY)))


## Days the pantry lasts at the current number of residents.
func pantry_days(id: int) -> int:
	var s: Dictionary = state[id]
	return 0 if s["residents"] == 0 else floori(s["food"] / float(s["residents"]))


func visit(id: int, service: String, tick: int) -> void:
	state[id]["visits"][service] = tick


## Whole days since a walker of `service` last passed, or -1 when none ever has.
func days_since(id: int, service: String) -> int:
	var visits: Dictionary = state[id]["visits"]
	if not visits.has(service):
		return -1
	return floori((_city.get_ref().clock.tick - visits[service]) / float(Balance.TICKS_PER_DAY))


## Once a day: everyone eats from the pantry, then each house rises, falls, or stays.
func daily() -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	var city = _city.get_ref()
	for s: Dictionary in state.values():
		s["food"] = maxi(0, s["food"] - s["residents"])
		s["jang"] = maxi(0, s["jang"] - s["residents"])
	for id: int in state:
		var instance: Dictionary = city.buildings.get_instance(id)
		var tier: int = instance["tier"]
		if tier == 0:
			continue
		var s: Dictionary = state[id]
		if tier < max_tier() and _all_met(instance, needs_for(tier + 1)):
			instance["tier"] = tier + 1
			s["missing_days"] = 0
			changed.append(instance)
		elif tier > 1 and not _all_met(instance, needs_for(tier)):
			s["missing_days"] += 1
			if s["missing_days"] >= Balance.HOUSE_DOWN_DAYS:
				instance["tier"] = tier - 1
				s["missing_days"] = 0
				s["residents"] = mini(s["residents"], capacity(tier - 1)) # the rest move away
				changed.append(instance)
		else:
			s["missing_days"] = 0
	return changed


## Silver all houses pay at the end of a season.
func tax() -> int:
	return population() * Balance.TAX_PER_RESIDENT


func _all_met(instance: Dictionary, needs: Array[String]) -> bool:
	for need in needs:
		if not is_met(instance, need):
			return false
	return true


func clear_cache() -> void:
	_cache.clear()


## Houses with a Well in reach: {house id: true} (rebuilt after buildings change).
func _watered() -> Dictionary:
	if not _cache.has("water"):
		var city = _city.get_ref()
		var ids := {}
		for instance: Dictionary in city.buildings.all():
			if instance["type"] != "well":
				continue
			var r: int = Buildings.get_building("well")["coverage"]["tiles"]
			var o: Vector2i = instance["origin"]
			for y in range(o.y - r, o.y + instance["size"].y + r):
				for x in range(o.x - r, o.x + instance["size"].x + r):
					var t := Vector2i(x, y)
					if city.grid.in_bounds(t):
						var id: int = city.grid.get_occupant(t)
						if state.has(id):
							ids[id] = true
		_cache["water"] = ids
	return _cache["water"]


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"state": state}


func load_save(d: Dictionary) -> void:
	state = d["state"]
	_cache.clear()
