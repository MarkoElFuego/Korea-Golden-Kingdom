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
## a shrine keeper's visit counts for SERVICE_DAYS days.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")

const HOUSE := "common_house"

## id -> {"residents": people, "incoming": people walking here, "missing_days": days,
##        "food": portions in the pantry, "visits": {service: tick of the last walker}}
var state := {}
var _city: WeakRef
var _cache := {} # coverage maps, built at most once per day (cleared in daily())


func _init(city) -> void:
	_city = weakref(city)


func add_building(instance: Dictionary) -> void:
	if instance["type"] == HOUSE:
		state[instance["id"]] = {"residents": 0, "incoming": 0, "missing_days": 0, "food": 0, "visits": {}}


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
	var result: Array[String] = []
	for t in range(1, tier + 1):
		for need: String in tier_data(t)["needs"]:
			result.append(need)
	return result


## People this house can still take, counting settlers already on the way.
func room(instance: Dictionary) -> int:
	var s: Dictionary = state[instance["id"]]
	return capacity(instance["tier"]) - s["residents"] - s["incoming"]


func is_met(instance: Dictionary, need: String) -> bool:
	var city = _city.get_ref()
	match need:
		"road":
			return city.has_road_access(instance)
		"water":
			return _covered(instance, _water_tiles())
		"food":
			return state[instance["id"]]["food"] > 0
		"seonangdang":
			var since := days_since(instance["id"], "seonangdang")
			return since >= 0 and since < Balance.SERVICE_DAYS
	return false # goods that do not exist yet (Jang, Onggi Jars)


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
	_cache.clear()
	var city = _city.get_ref()
	for s: Dictionary in state.values():
		s["food"] = maxi(0, s["food"] - s["residents"])
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


func _covered(instance: Dictionary, tiles: Dictionary) -> bool:
	for dy in instance["size"].y:
		for dx in instance["size"].x:
			if tiles.has(instance["origin"] + Vector2i(dx, dy)):
				return true
	return false


func clear_cache() -> void:
	_cache.clear()


func _water_tiles() -> Dictionary:
	if not _cache.has("water"):
		var city = _city.get_ref()
		var tiles := {}
		for instance: Dictionary in city.buildings.all():
			if instance["type"] == "well":
				tiles.merge(city.coverage_preview("well", instance["origin"], instance["rotation"]))
		_cache["water"] = tiles
	return _cache["water"]
