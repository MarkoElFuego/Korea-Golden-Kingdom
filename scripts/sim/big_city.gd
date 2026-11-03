extends RefCounted
## The "big city" for performance checks (CLAUDE.md: 60 FPS with 3,000 residents and
## 400 walkers). A flat fertile valley with a street grid; every block holds Choga Houses
## with their Well, Market, Seonangdang, Granary and Rice Paddies, and a Storehouse with an
## Onggi Kiln, so all walker kinds (and kiln fetchers) are on the streets. Houses start settled and fed, so the test runs at full size at once.
## Used by tests/test_performance.gd and scenes/big_city.tscn.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const Houses = preload("res://scripts/sim/houses.gd")

const WIDTH := 128
const HEIGHT := 112
## What stands in each 3-tile slot along a block, repeating.
const PATTERN: Array[String] = [
	"common_house", "common_house", "well", "common_house", "common_house", "market",
	"common_house", "common_house", "seonangdang", "common_house", "common_house", "granary",
	"common_house", "rice_paddy", "common_house", "rice_paddy", "storehouse", "onggi_kiln",
]


static func build() -> City:
	var c := City.new()
	c.grid = Grid.new(WIDTH, HEIGHT)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 10000000
	# Streets every 4 rows, avenues every 16 columns.
	for y in range(0, HEIGHT, 4):
		c.build_road(Vector2i(0, y), Vector2i(WIDTH - 1, y))
	for x in range(0, WIDTH, 16):
		c.build_road(Vector2i(x, 0), Vector2i(x, HEIGHT - 1))
	c.set_entrance(Vector2i(0, 0))
	var slot := 0
	for y in range(1, HEIGHT - 3, 4):
		for x in range(1, WIDTH - 3, 3):
			var type := PATTERN[slot % PATTERN.size()]
			slot += 1
			if c.place_building(type, Vector2i(x, y)) != "":
				continue # an avenue is in the way
			var id: int = c.building_at(Vector2i(x, y))["id"]
			match type:
				"common_house":
					_settle(c, id)
				"granary":
					c.economy.add(id, "rice", 24)
				"market":
					c.economy.add(id, "rice", 12)
				"storehouse":
					c.economy.add(id, "clay", 16)
					c.economy.add(id, "wood", 16)
	c.labor.recompute(c.buildings.all(), c.houses, c.economy)
	return c


## A Choga House with its people, a full pantry and a recent shrine visit.
static func _settle(c: City, id: int) -> void:
	var house: Dictionary = c.buildings.get_instance(id)
	house["tier"] = 2
	var s: Dictionary = c.houses.state[id]
	s["residents"] = Houses.capacity(2)
	s["food"] = Houses.pantry_size(2)
	s["visits"] = {"seonangdang": 0, "market": 0}
