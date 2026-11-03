extends "res://tests/test_base.gd"
## The demo town (scenes/demo_town.tscn) is built whole and every chain in it works.

const Balance = preload("res://scripts/data/balance.gd")
const DemoTown = preload("res://scripts/sim/demo_town.gd")


func test_demo_town_is_built_whole_and_works() -> void:
	var c = DemoTown.build()
	check_eq(DemoTown.failures, [] as Array[String], "every building fits")
	check(c.population() > 200, "people live here (%d)" % c.population())
	check_eq(c.supply.stopped().size(), 0, "nothing stands still at the start")
	for i in 60 * Balance.TICKS_PER_DAY:
		c.clock.step()
	check(c.economy.produced.get("rice", 0) > 0, "rice grows")
	check(c.economy.produced.get("onggi_jars", 0) > 0, "the kiln makes jars")
	check(c.economy.produced.get("jang", 0) > 0, "Jang is made")
	check(c.population() > 200, "the town lives on (%d people)" % c.population())
