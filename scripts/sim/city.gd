extends RefCounted
## The whole simulated city, without graphics: map, clock, treasury, buildings, roads,
## goods, carriers, houses, settlers and the labour pool.
## The view only reads this state and sends the player's commands here.
## Every command checks its rules first; when a rule fails nothing changes.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")
const BuildingRegistry = preload("res://scripts/sim/building_registry.gd")
const Coverage = preload("res://scripts/sim/coverage.gd")
const RoadNetwork = preload("res://scripts/sim/road_network.gd")
const Economy = preload("res://scripts/sim/economy.gd")
const Carriers = preload("res://scripts/sim/carriers.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Labor = preload("res://scripts/sim/labor.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const Settlers = preload("res://scripts/sim/settlers.gd")

signal treasury_changed(value: int)
signal building_added(instance: Dictionary)
signal building_removed(instance: Dictionary)
signal roads_changed()
signal house_changed(instance: Dictionary) # tier or residents changed
signal population_changed()

var map_seed: int
var grid: Grid
var clock: SimClock
var treasury: int
var buildings: BuildingRegistry
var network: RoadNetwork
var economy: Economy
var carriers: Carriers
var labor: Labor
var houses: Houses
var settlers: Settlers
## Road tile on the map edge where settlers come into the valley (cannot be demolished).
var entrance: Vector2i
## Player commands in order, each [tick, name, args...], for replays and determinism tests.
var command_log: Array = []


func _init(seed_value: int = Balance.DEFAULT_MAP_SEED) -> void:
	map_seed = seed_value
	var map := MapGenerator.generate_with_entrance(map_seed, Balance.MAP_WIDTH, Balance.MAP_HEIGHT)
	var terrain: PackedByteArray = map["terrain"]
	grid = Grid.new(Balance.MAP_WIDTH, Balance.MAP_HEIGHT, terrain)
	clock = SimClock.new()
	treasury = Balance.START_TREASURY
	buildings = BuildingRegistry.new()
	entrance = map["entrance"]
	grid.set_road(entrance)
	network = RoadNetwork.new()
	network.rebuild(grid)
	economy = Economy.new(clock)
	carriers = Carriers.new(self)
	labor = Labor.new()
	houses = Houses.new(self)
	settlers = Settlers.new(self)
	settlers.arrived.connect(_on_settlers_arrived)
	clock.day_changed.connect(_on_day)
	clock.season_changed.connect(_on_season)
	clock.ticked.connect(_on_tick)


## Advances the simulation by `delta` real seconds. Returns ticks run.
func advance(delta: float) -> int:
	return clock.advance(delta)


## One simulation tick: production, carriers, settlers.
func _on_tick(_tick: int) -> void:
	economy.produce_tick()
	carriers.tick()
	settlers.tick()


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
	economy.add_building(instance)
	carriers.on_building_added(instance)
	houses.add_building(instance)
	_change_treasury(-data["cost"])
	command_log.append([clock.tick, "place", type, origin, rotation])
	_recompute_labor()
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
		command_log.append([clock.tick, "road", a, b])
		treasury_changed.emit(treasury)
		_on_roads_changed()
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
				if t != entrance: # the valley entrance always stays
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
	if not plan["roads"].is_empty():
		network.rebuild(grid) # carriers re-plan on the new streets
	for id: int in plan["buildings"]:
		var instance := buildings.remove(id)
		if Buildings.get_building(instance["type"]).get("on_road", false):
			for dy in instance["size"].y:
				for dx in instance["size"].x:
					grid.blockers.erase(instance["origin"] + Vector2i(dx, dy))
		else:
			grid.vacate(instance["origin"], instance["size"])
		refund += floori(Buildings.get_building(instance["type"])["cost"] * Balance.DEMOLISH_REFUND)
		carriers.on_building_removed(instance)
		settlers.on_building_removed(instance)
		houses.remove_building(instance)
		labor.forget(instance["id"])
		building_removed.emit(instance)
	var removed: int = plan["roads"].size() + plan["buildings"].size()
	if removed == 0:
		return 0
	command_log.append([clock.tick, "demolish", a, b])
	if not plan["buildings"].is_empty():
		_recompute_labor()
	if refund > 0:
		_change_treasury(refund)
	if not plan["roads"].is_empty():
		carriers.on_roads_changed()
		settlers.on_roads_changed()
		roads_changed.emit()
	return removed


func _on_roads_changed() -> void:
	network.rebuild(grid)
	carriers.on_roads_changed()
	settlers.on_roads_changed()
	roads_changed.emit()


## Runs one entry from a command log (without its tick).
func apply_command(command: Array) -> void:
	match command[1]:
		"place":
			place_building(command[2], command[3], command[4])
		"road":
			build_road(command[2], command[3])
		"demolish":
			demolish(command[2], command[3])


## Replays a command log from the start: runs ticks up to each command's tick, then the
## command, then ticks up to `until_tick`. Same seed + same log = same city.
func replay(commands: Array, until_tick: int) -> void:
	for command in commands:
		while clock.tick < command[0]:
			clock.step()
		apply_command(command)
	while clock.tick < until_tick:
		clock.step()


# --- Building window ---

## What a building is doing, for the building window: {"key": text key, "args": [...]}.
## Empty key when there is nothing to say.
func status(instance: Dictionary) -> Dictionary:
	var data := Buildings.get_building(instance["type"])
	if data.has("tiers") and instance["tier"] == 0:
		return {"key": "STATUS_WAITING_SETTLERS", "args": []}
	if data.get("produces_later", false):
		return {"key": "STATUS_WAITS_FERMENTATION", "args": []}
	var p := Economy.production(instance["type"])
	if not p.is_empty():
		var start := Coverage.access_road(grid, instance)
		if start == Carriers.NO_TILE:
			return {"key": "STATUS_NO_ROAD_CARRIERS", "args": []}
		var full := economy.stock(instance["id"], p["good"]) >= Balance.PRODUCER_STORE
		if economy.state[instance["id"]]["carrier"] != 0 and not full:
			return {"key": "STATUS_CARRIER_OUT", "args": [roundi(economy.progress(instance) * 100)]}
		if carriers.find_storage(start, p["good"]).is_empty() and economy.stock(instance["id"], p["good"]) > 0:
			var key := "STATUS_NO_GRANARY" if Goods.kind(p["good"]) == "food" else "STATUS_NO_STOREHOUSE"
			return {"key": key, "args": []}
		return {"key": "STATUS_PRODUCING", "args": [roundi(economy.progress(instance) * 100)]}
	if not Economy.storage(instance["type"]).is_empty():
		var used := economy.total_stock(instance["id"])
		var cap := Economy.capacity(instance["type"])
		if not has_road_access(instance):
			return {"key": "STATUS_NO_ROAD_CARRIERS", "args": []}
		return {"key": "STATUS_STORAGE_FULL" if used >= cap else "STATUS_STORAGE", "args": [used, cap]}
	if not has_road_access(instance):
		return {"key": "WARN_NO_ROAD_ACCESS", "args": []}
	return {"key": "", "args": []}


## Moves the valley entrance (tests and custom maps): the new tile becomes a road.
func set_entrance(tile: Vector2i) -> void:
	entrance = tile
	grid.set_road(tile)
	_on_roads_changed()


func population() -> int:
	return labor.population


func _on_settlers_arrived(house: Dictionary) -> void:
	_recompute_labor()
	house_changed.emit(house)


## Once a day houses rise or fall a tier.
func _on_day(_day: int) -> void:
	var changed := houses.daily()
	if changed.is_empty():
		return
	_recompute_labor()
	for house in changed:
		house_changed.emit(house)


## At the end of every season the houses pay a small tax (MVP, no Tax Office yet).
func _on_season(_season: int) -> void:
	var silver := houses.tax()
	if silver > 0:
		_change_treasury(silver)


func _recompute_labor() -> void:
	var before := labor.population
	labor.recompute(buildings.all(), houses, economy)
	houses.clear_cache() # staffing changes what Granaries and shrines provide
	if labor.population != before:
		population_changed.emit()


func _change_treasury(amount: int) -> void:
	treasury += amount
	treasury_changed.emit(treasury)
