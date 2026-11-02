@warning_ignore_start("integer_division") # calendar math uses whole days on purpose
extends RefCounted
## Fixed simulation tick and calendar. Game speed only changes how many ticks run
## per real second, never the rules. In this phase nothing else is simulated.

const Balance = preload("res://scripts/data/balance.gd")

signal ticked(tick: int)
signal day_changed(day: int)
signal season_changed(season: int)
signal year_changed(year: int)
signal speed_changed(speed: int, paused: bool)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_KEYS: Array[String] = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER"]

var tick := 0 # ticks since the start of the game
var speed := 1 # 1, 2 or 3
var paused := false
var _accumulator := 0.0 # ticks not yet run


## Runs as many ticks as `delta` real seconds are worth at the current speed.
## Returns the number of ticks run.
func advance(delta: float) -> int:
	if paused:
		return 0
	_accumulator += delta * Balance.TICKS_PER_SECOND * speed
	# Small epsilon so 1/60 s steps add up to whole ticks despite float rounding.
	var count := floori(_accumulator + 0.0001)
	if count > Balance.MAX_TICKS_PER_FRAME:
		count = Balance.MAX_TICKS_PER_FRAME
		_accumulator = 0.0
	else:
		_accumulator -= count
	for i in count:
		step()
	return count


## Runs exactly one tick.
func step() -> void:
	tick += 1
	ticked.emit(tick)
	if tick % Balance.TICKS_PER_DAY != 0:
		return
	day_changed.emit(get_day())
	var days := total_days()
	if days % Balance.DAYS_PER_SEASON != 0:
		return
	season_changed.emit(get_season())
	if (days / Balance.DAYS_PER_SEASON) % Balance.SEASONS_PER_YEAR == 0:
		year_changed.emit(get_year())


func set_speed(value: int) -> void:
	if not Balance.SPEEDS.has(value):
		return
	speed = value
	paused = false
	speed_changed.emit(speed, paused)


func set_paused(value: bool) -> void:
	paused = value
	speed_changed.emit(speed, paused)


func toggle_pause() -> void:
	set_paused(not paused)


# --- Calendar ---

## Whole days since the start of the game (0 on the first day).
func total_days() -> int:
	return tick / Balance.TICKS_PER_DAY


## Day within the season, 1..DAYS_PER_SEASON.
func get_day() -> int:
	return total_days() % Balance.DAYS_PER_SEASON + 1


## Season index (Season enum), 0..SEASONS_PER_YEAR-1.
func get_season() -> int:
	return (total_days() / Balance.DAYS_PER_SEASON) % Balance.SEASONS_PER_YEAR


func get_season_key() -> String:
	return SEASON_KEYS[get_season()]


## Year, starting at Balance.START_YEAR.
func get_year() -> int:
	return total_days() / (Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR) + Balance.START_YEAR
