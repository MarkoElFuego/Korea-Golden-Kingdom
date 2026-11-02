extends RefCounted
## The whole simulated city, without graphics: map, clock and treasury.
## The view only reads this state.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")

@warning_ignore("unused_signal") # emitted from phase 2 (building costs)
signal treasury_changed(value: int)

var map_seed: int
var grid: Grid
var clock: SimClock
var treasury: int


func _init(seed_value: int = Balance.DEFAULT_MAP_SEED) -> void:
	map_seed = seed_value
	var terrain := MapGenerator.generate(map_seed, Balance.MAP_WIDTH, Balance.MAP_HEIGHT)
	grid = Grid.new(Balance.MAP_WIDTH, Balance.MAP_HEIGHT, terrain)
	clock = SimClock.new()
	treasury = Balance.START_TREASURY


## Advances the simulation by `delta` real seconds. Returns ticks run.
func advance(delta: float) -> int:
	return clock.advance(delta)
