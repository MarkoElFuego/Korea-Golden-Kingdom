extends RefCounted
## The common labour pool (docs/koncept.md, "Stanovanje"): a share of all residents work,
## and buildings take workers in the order they were built. A building with half its
## workers works at half speed; with none it stops. Nobody walks to work.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")

var population := 0
var workforce := 0 # people able to work
var needed := 0 # workers all buildings together want
var assigned := {} # building id -> workers it has
## Workers that do not come from houses (tests, later a scenario's starting crew).
var extra_workers := 0


## Shares out the workforce again. Called when buildings or residents change.
func recompute(buildings: Array[Dictionary], houses, economy) -> void:
	population = houses.population()
	workforce = floori(population * Balance.WORKER_SHARE) + extra_workers
	needed = 0
	var left := workforce
	for instance in buildings:
		var want: int = Buildings.get_building(instance["type"])["workers"]
		if want == 0:
			continue
		needed += want
		var n := mini(want, left)
		left -= n
		assigned[instance["id"]] = n
		economy.set_efficiency(instance["id"], float(n) / want)


func forget(id: int) -> void:
	assigned.erase(id)


## Workers in use (at most the workforce).
func employed() -> int:
	return mini(workforce, needed)
