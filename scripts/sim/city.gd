extends RefCounted
## The whole simulated city, without graphics: map, clock, treasury, buildings and roads.
## The view only reads this state and sends the player's commands here.
## Every command checks its rules first; when a rule fails nothing changes.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")
const BuildingRegistry = preload("res://scripts/sim/building_registry.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")

signal treasury_changed(value: int)
signal building_added(instance: Dictionary)
signal building_removed(instance: Dictionary)
signal roads_changed()

var map_seed: int
var grid: Grid
var clock: SimClock
var treasury: int
var buildings: BuildingRegistry
## Player commands in order, for replays and determinism tests.
var command_log: Array = []


func _init(seed_value: int = Balance.DEFAULT_MAP_SEED) -> void:
	map_seed = seed_value
	var terrain := MapGenerator.generate(map_seed, Balance.MAP_WIDTH, Balance.MAP_HEIGHT)
	grid = Grid.new(Balance.MAP_WIDTH, Balance.MAP_HEIGHT, terrain)
	clock = SimClock.new()
	treasury = Balance.START_TREASURY
	buildings = BuildingRegistry.new()


## Advances the simulation by `delta` real seconds. Returns ticks run.
func advance(delta: float) -> int:
	return clock.advance(delta)


# --- Buildings ---

## Why `type` cannot be built here: a text key, or "" when it can.
func check_building(type: String, origin: Vector2i, rotation := 0) -> String:
	var data := Buildings.get_building(type)
	if data.is_empty() or type == "road":
		return "REASON_UNKNOWN_BUILDING"
	var size := Grid.rotated_size(data["footprint"], rotation)
	if data.get("on_road", false):
		return _check_on_road(data, origin, size)
	match grid.check_footprint(origin, size, Buildings.allowed_terrain(type)):
		"out_of_bounds":
			return "REASON_OUT_OF_BOUNDS"
		"occupied":
			return "REASON_OCCUPIED"
		"terrain":
			return Buildings.terrain_reason(type)
	var near: Dictionary = data.get("near_terrain", {})
	if not near.is_empty() and not Coverage.terrain_near(grid, origin, size, near["terrain"], near["tiles"]):
		return near["reason_key"]
	if treasury < data["cost"]:
		return "REASON_NOT_ENOUGH_SILVER"
	return ""


## Rules for a building that stands on a road (Jangseung).
func _check_on_road(data: Dictionary, origin: Vector2i, size: Vector2i) -> String:
	for dy in size.y:
		for dx in size.x:
			var t := origin + Vector2i(dx, dy)
			if not grid.in_bounds(t):
				return "REASON_OUT_OF_BOUNDS"
			if grid.is_blocked(t):
				return "REASON_OCCUPIED"
			if not grid.is_road(t):
				return "REASON_NEEDS_ROAD"
	if treasury < data["cost"]:
		return "REASON_NOT_ENOUGH_SILVER"
	return ""


## Builds `type` with its north-west tile at `origin`. Returns "" or the reason it failed.
func place_building(type: String, origin: Vector2i, rotation := 0) -> String:
	var reason := check_building(type, origin, rotation)
	if reason != "":
		return reason
	var data := Buildings.get_building(type)
	var size := Grid.rotated_size(data["footprint"], rotation)
	var tier := 0 if data.has("tiers") else 1 # a new house is a vacant lot
	var instance := buildings.add(type, origin, size, posmod(rotation, 4), tier)
	if data.get("on_road", false):
		for dy in size.y:
			for dx in size.x:
				grid.blockers[origin + Vector2i(dx, dy)] = instance["id"] # the tile stays a road
	else:
		grid.occupy(origin, size, instance["id"], Buildings.allowed_terrain(type))
	_change_treasury(-data["cost"])
	command_log.append(["place", type, origin, rotation])
	building_added.emit(instance)
	return ""


## Tiles the building would serve if built here (Well radius, walker streets).
func coverage_preview(type: String, origin: Vector2i, rotation := 0) -> Dictionary:
	var data := Buildings.get_building(type)
	if data.is_empty():
		return {}
	return Coverage.for_building(grid, data, origin, Grid.rotated_size(data["footprint"], rotation))


func has_road_access(instance: Dictionary) -> bool:
	if Buildings.get_building(instance.get("type", "")).get("on_road", false):
		return true # it stands on the road itself
	return Coverage.has_road_access(grid, instance["origin"], instance["size"])


func building_at(tile: Vector2i) -> Dictionary:
	if not grid.in_bounds(tile):
		return {}
	if grid.is_blocked(tile):
		return buildings.get_instance(grid.blockers[tile])
	return buildings.get_instance(grid.get_occupant(tile))


# --- Roads ---

## What dragging a road from `a` to `b` would do:
## {"tiles": new road tiles, "blocked": tiles a road cannot use, "cost": Silver}.
## Tiles that already have a road are in neither list.
func plan_road(a: Vector2i, b: Vector2i) -> Dictionary:
	var allowed := Buildings.allowed_terrain("road")
	var tiles: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	for t in Grid.l_path(a, b):
		if grid.is_road(t):
			continue
		if grid.can_place(t, Vector2i.ONE, allowed):
			tiles.append(t)
		else:
			blocked.append(t)
	var cost: int = tiles.size() * Buildings.get_building("road")["cost"]
	return {"tiles": tiles, "blocked": blocked, "cost": cost}


## Builds the road along the L from `a` to `b`, skipping tiles it cannot use.
## Stops when the treasury runs out. Returns the number of tiles built.
func build_road(a: Vector2i, b: Vector2i) -> int:
	var price: int = Buildings.get_building("road")["cost"]
	var built := 0
	for t in plan_road(a, b)["tiles"]:
		if treasury < price:
			break
		grid.set_road(t)
		treasury -= price
		built += 1
	if built > 0:
		command_log.append(["road", a, b])
		treasury_changed.emit(treasury)
		roads_changed.emit()
	return built


# --- Demolish ---

## What demolishing the rectangle between `a` and `b` would remove:
## {"roads": road tiles, "buildings": instance ids}.
## A Jangseung is removed first: its road tile stays and goes only on a second demolish.
func plan_demolish(a: Vector2i, b: Vector2i) -> Dictionary:
	var roads: Array[Vector2i] = []
	var ids: Array[int] = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			var t := Vector2i(x, y)
			if not grid.in_bounds(t):
				continue
			var occ := grid.get_occupant(t)
			if grid.is_blocked(t):
				if not ids.has(grid.blockers[t]):
					ids.append(grid.blockers[t])
			elif occ == Grid.ROAD:
				roads.append(t)
			elif occ != Grid.EMPTY and not ids.has(occ):
				ids.append(occ)
	return {"roads": roads, "buildings": ids}


## Removes every road and building in the rectangle. Silver is not returned
## (Balance.DEMOLISH_REFUND). Returns how many roads and buildings were removed.
func demolish(a: Vector2i, b: Vector2i) -> int:
	var plan := plan_demolish(a, b)
	var refund := 0
	for t: Vector2i in plan["roads"]:
		grid.clear_tile(t)
	for id: int in plan["buildings"]:
		var instance := buildings.remove(id)
		if Buildings.get_building(instance["type"]).get("on_road", false):
			for dy in instance["size"].y:
				for dx in instance["size"].x:
					grid.blockers.erase(instance["origin"] + Vector2i(dx, dy))
		else:
			grid.vacate(instance["origin"], instance["size"])
		refund += floori(Buildings.get_building(instance["type"])["cost"] * Balance.DEMOLISH_REFUND)
		building_removed.emit(instance)
	var removed: int = plan["roads"].size() + plan["buildings"].size()
	if removed == 0:
		return 0
	command_log.append(["demolish", a, b])
	if refund > 0:
		_change_treasury(refund)
	if not plan["roads"].is_empty():
		roads_changed.emit()
	return removed


## Runs one entry from a command log (replays, tests).
func apply_command(command: Array) -> void:
	match command[0]:
		"place":
			place_building(command[1], command[2], command[3])
		"road":
			build_road(command[1], command[2])
		"demolish":
			demolish(command[1], command[2])


func _change_treasury(amount: int) -> void:
	treasury += amount
	treasury_changed.emit(treasury)
