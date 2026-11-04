extends RefCounted
## The demo town (scenes/demo_town.tscn): a small working town on a hand-made valley, for
## trying the game without building from scratch. Every chain runs from the start:
## Rice Paddies -> Granary -> Markets -> houses; Clay Pit and Woodcutter -> Onggi Kiln ->
## Onggi Jars -> Jangdokdae; Soybean Fields and Salt Pans -> Jangdokdae -> Jang; Markets
## sell rice, Jang and Onggi Jars, so Choga Houses can become Giwa Houses.
## Houses start lived in (some already Choga Houses), a few lots wait for settlers, and
## there is Silver to build on.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")

const WIDTH := 64
const HEIGHT := 32
const SILVER := 5000
const VACANT_LOTS := 4 # the last houses wait for settlers

## Buildings that could not be placed, as "type at tile: reason" (empty when all fit).
static var failures: Array[String] = []


static func build() -> City:
	failures.clear()
	var c := City.new()
	c.grid = Grid.new(WIDTH, HEIGHT)
	_terrain(c.grid)
	c.treasury = 1000000 # pays for the town itself; set to SILVER at the end
	c.set_entrance(Vector2i(0, 10))
	c.build_road(Vector2i(0, 10), Vector2i(WIDTH - 1, 10)) # the valley road, to the sea
	c.build_road(Vector2i(0, 16), Vector2i(53, 16)) # the street of houses
	c.build_road(Vector2i(31, 10), Vector2i(31, 16))
	c.build_road(Vector2i(53, 10), Vector2i(53, 16))

	# North of the valley road: fields, and Salt Pans on the shore.
	for x in [1, 4, 7, 10]:
		_place(c, "rice_paddy", Vector2i(x, 7))
	for x in [13, 16, 19, 22]:
		_place(c, "soybean_field", Vector2i(x, 7))
	for x in [55, 58, 61]:
		_place(c, "salt_pans", Vector2i(x, 7))

	# South of the valley road: the workshops and the town center.
	_place(c, "clay_pit", Vector2i(1, 11))
	_place(c, "woodcutter", Vector2i(4, 11))
	_place(c, "onggi_kiln", Vector2i(8, 11))
	var store := _place(c, "storehouse", Vector2i(12, 11))
	var yard := _place(c, "jangdokdae", Vector2i(16, 11))
	var granary := _place(c, "granary", Vector2i(19, 11))
	var market := _place(c, "market", Vector2i(23, 11))
	_place(c, "seonangdang", Vector2i(27, 11))
	_place(c, "well", Vector2i(29, 11))

	# The street of houses, east of the center, with wells between the rows.
	var houses: Array[int] = []
	for y in [11, 14, 17]:
		for x in range(32, 52, 2):
			houses.append(_place(c, "common_house", Vector2i(x, y)))
	for y in [13, 19]:
		for x in [35, 42, 49]:
			_place(c, "well", Vector2i(x, y))
	# West part of the street: a second Market and Seonangdang with their houses.
	var market2 := _place(c, "market", Vector2i(2, 17))
	_place(c, "seonangdang", Vector2i(6, 17))
	for x in range(7, 29, 2):
		houses.append(_place(c, "common_house", Vector2i(x, 17)))
	for x in [10, 18, 26]:
		_place(c, "well", Vector2i(x, 19))

	# Stock to start with, and the people.
	_add(c, granary, "rice", 16)
	_add(c, market, "rice", 8)
	_add(c, market2, "rice", 8)
	_add(c, store, "clay", 4)
	_add(c, store, "wood", 4)
	_add(c, store, "onggi_jars", 2)
	_add(c, yard, "onggi_jars", 3)
	_add(c, yard, "soybeans", 1)
	_add(c, yard, "salt", 1)
	houses = houses.filter(func(id: int) -> bool: return id != 0)
	for i in houses.size() - VACANT_LOTS:
		_settle(c, houses[i], 2 if i % 3 == 0 else 1)
	c.houses.clear_cache()
	c.labor.recompute(c.buildings.all(), c.houses, c.economy)
	c.treasury = SILVER
	c.command_log.clear() # the demo is the starting point, not a list of player commands
	return c


## Fertile valley floor, a rocky hill for clay, a wood beside it, the shore and the sea in
## the east, and grass where the houses stand.
static func _terrain(grid: Grid) -> void:
	grid.terrain.fill(Terrain.FERTILE_PLAIN)
	for y in range(14, HEIGHT):
		for x in WIDTH:
			grid.set_terrain(Vector2i(x, y), Terrain.GRASS)
	for y in range(11, 13):
		for x in range(1, 3):
			grid.set_terrain(Vector2i(x, y), Terrain.ROCKY_HILL)
	for y in range(13, 15):
		for x in range(3, 8):
			grid.set_terrain(Vector2i(x, y), Terrain.FOREST)
	for y in range(0, 13):
		for x in range(54, WIDTH):
			grid.set_terrain(Vector2i(x, y), Terrain.SEA if y < 4 else Terrain.SHORE)


## Places a building; returns its id, or 0 (and notes why) when it does not fit.
static func _place(c: City, type: String, at: Vector2i) -> int:
	var reason := c.place_building(type, at)
	if reason != "":
		failures.append("%s at %s: %s" % [type, at, reason])
		return 0
	return c.building_at(at)["id"]


static func _add(c: City, id: int, good: String, loads: int) -> void:
	if id != 0:
		c.economy.add(id, good, loads)


## A house with its people, a full pantry and a recent shrine visit.
static func _settle(c: City, id: int, tier: int) -> void:
	c.buildings.get_instance(id)["tier"] = tier
	var s: Dictionary = c.houses.state[id]
	s["residents"] = Houses.capacity(tier)
	s["food"] = Houses.pantry_size(tier)
	s["visits"] = {"seonangdang": 0, "market": 0}
