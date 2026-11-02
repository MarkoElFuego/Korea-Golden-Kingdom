extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/data/balance.gd")
const SimClock = preload("res://scripts/sim/sim_clock.gd")

const DAYS_PER_YEAR := Balance.DAYS_PER_SEASON * Balance.SEASONS_PER_YEAR


func _run_frames(clock: SimClock, seconds: float, fps := 60) -> int:
	var ticks := 0
	for i in roundi(seconds * fps):
		ticks += clock.advance(1.0 / fps)
	return ticks


func test_starts_on_day_one_spring_year_one() -> void:
	var c := SimClock.new()
	check_eq(c.get_day(), 1, "day")
	check_eq(c.get_season(), SimClock.Season.SPRING, "season")
	check_eq(c.get_year(), Balance.START_YEAR, "year")


func test_one_second_at_1x() -> void:
	var c := SimClock.new()
	check_eq(_run_frames(c, 1.0), Balance.TICKS_PER_SECOND, "ticks in one second")
	check_eq(c.total_days(), 1, "one day passed")


func test_speeds_multiply_ticks() -> void:
	for s in Balance.SPEEDS:
		var c := SimClock.new()
		c.set_speed(s)
		check_eq(_run_frames(c, 2.0), Balance.TICKS_PER_SECOND * 2 * s, "ticks in 2 s at %dx" % s)


func test_pause_stops_time() -> void:
	var c := SimClock.new()
	c.set_paused(true)
	check_eq(_run_frames(c, 3.0), 0, "no ticks while paused")
	c.toggle_pause()
	check(not c.paused, "toggle resumes")
	check_eq(_run_frames(c, 1.0), Balance.TICKS_PER_SECOND, "runs again after resume")


func test_speed_key_unpauses() -> void:
	var c := SimClock.new()
	c.set_paused(true)
	c.set_speed(2)
	check(not c.paused, "choosing a speed resumes the game")
	c.set_speed(5)
	check_eq(c.speed, 2, "unknown speed is ignored")


func test_days_and_seasons_at_3x() -> void:
	var c := SimClock.new()
	c.set_speed(3)
	var days := []
	var seasons := []
	var years := []
	c.day_changed.connect(func(d: int) -> void: days.append(d))
	c.season_changed.connect(func(s: int) -> void: seasons.append(s))
	c.year_changed.connect(func(y: int) -> void: years.append(y))
	# One full year plus one season, in real seconds at 3x.
	var seconds := float((DAYS_PER_YEAR + Balance.DAYS_PER_SEASON) * Balance.TICKS_PER_DAY) / (Balance.TICKS_PER_SECOND * 3)
	_run_frames(c, seconds)
	check_eq(c.total_days(), DAYS_PER_YEAR + Balance.DAYS_PER_SEASON, "days passed")
	check_eq(days.size(), DAYS_PER_YEAR + Balance.DAYS_PER_SEASON, "one day signal per day")
	check_eq(seasons, [1, 2, 3, 0, 1], "seasons in order: summer, autumn, winter, spring, summer")
	check_eq(years, [Balance.START_YEAR + 1], "one new year")
	check_eq(c.get_year(), Balance.START_YEAR + 1, "year 2")
	check_eq(c.get_season(), SimClock.Season.SUMMER, "summer of year 2")
	check_eq(c.get_day(), 1, "first day of summer")


func test_calendar_wraps() -> void:
	var c := SimClock.new()
	for i in (Balance.DAYS_PER_SEASON - 1) * Balance.TICKS_PER_DAY:
		c.step()
	check_eq(c.get_day(), Balance.DAYS_PER_SEASON, "last day of spring")
	check_eq(c.get_season_key(), "SEASON_SPRING", "still spring")
	for i in Balance.TICKS_PER_DAY:
		c.step()
	check_eq(c.get_day(), 1, "day 1 again")
	check_eq(c.get_season_key(), "SEASON_SUMMER", "summer")


func test_long_frame_is_capped() -> void:
	var c := SimClock.new()
	c.set_speed(3)
	check_eq(c.advance(10.0), Balance.MAX_TICKS_PER_FRAME, "a 10 s hitch runs at most the cap")
	check_eq(c.advance(0.0), 0, "and does not carry the rest")
