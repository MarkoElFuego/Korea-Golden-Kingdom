extends "res://tests/test_base.gd"
## Saving and loading (phase 5): a loaded city plays on exactly like the original,
## autosaves rotate, and damaged, foreign or failed files never cost the player a save.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const DIR := "user://test_saves"


## A small working town: fields, storage, market, shrine, wells, houses filling with settlers.
func _town() -> City:
	var c := City.new()
	c.grid = Grid.new(48, 24)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.labor.extra_workers = 30
	c.set_entrance(Vector2i(0, 5))
	c.build_road(Vector2i(0, 5), Vector2i(47, 5))
	c.build_road(Vector2i(12, 5), Vector2i(12, 20))
	c.build_road(Vector2i(12, 12), Vector2i(40, 12))
	c.place_building("rice_paddy", Vector2i(30, 6))
	c.place_building("rice_paddy", Vector2i(34, 6))
	c.place_building("granary", Vector2i(38, 6))
	c.economy.add(c.building_at(Vector2i(38, 6))["id"], "rice", 12)
	c.place_building("market", Vector2i(13, 6))
	c.place_building("seonangdang", Vector2i(13, 13))
	c.place_building("jangseung", Vector2i(30, 12))
	for x in range(14, 28, 2):
		c.place_building("common_house", Vector2i(x, 13))
	c.place_building("well", Vector2i(20, 15))
	return c


func _run_ticks(c: City, ticks: int) -> void:
	for i in ticks:
		c.clock.step()


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		DirAccess.remove_absolute(DIR.path_join(sub))


# --- The same city after loading ---

func test_loaded_city_plays_on_exactly_like_the_original() -> void:
	var a := _town()
	_run_ticks(a, 55 * Balance.TICKS_PER_DAY + 7) # mid-day, walkers mid-step
	check(a.carriers.count() + a.settlers.count() + a.services.count() > 0, "walkers are out")
	var loaded := SaveGame.city_from_bytes(SaveGame.pack(a))
	check_eq(loaded["error"], "", "loads")
	var b: City = loaded["city"]
	check_eq(b.population(), a.population(), "same people")
	check_eq(b.clock.tick, a.clock.tick, "same moment")
	_run_ticks(a, 1000)
	_run_ticks(b, 1000)
	check(a.population() > 0, "the town lives (%d people)" % a.population())
	check_eq(b.houses.state, a.houses.state, "houses")
	check_eq(b.economy.state, a.economy.state, "goods")
	check_eq(b.carriers.walkers, a.carriers.walkers, "carriers")
	check_eq(b.settlers.walkers, a.settlers.walkers, "settlers")
	check_eq(b.services.walkers, a.services.walkers, "vendors, keepers, buyers")
	check_eq(b.treasury, a.treasury, "treasury")
	check(SaveGame.pack(b) == SaveGame.pack(a), "and byte for byte the same save")


func test_loaded_city_takes_commands() -> void:
	var a := _town()
	_run_ticks(a, 200)
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(a))["city"]
	check_eq(b.place_building("well", Vector2i(24, 15)), "", "can build")
	check_eq(b.build_road(Vector2i(40, 12), Vector2i(40, 20)), 8, "can lay roads")
	check(b.demolish(Vector2i(13, 6), Vector2i(13, 6)) > 0, "can demolish")
	_run_ticks(b, 300)


# --- Files ---

func test_quicksave_and_load_from_disk() -> void:
	_clean()
	var a := _town()
	_run_ticks(a, 300)
	check_eq(SaveGame.write(a, SaveGame.QUICKSAVE, DIR), "", "saved")
	check_eq(SaveGame.latest(DIR), DIR.path_join(SaveGame.QUICKSAVE), "it is the latest save")
	var result := SaveGame.read(DIR.path_join(SaveGame.QUICKSAVE))
	check_eq(result["error"], "", "read back")
	check_eq(result["city"].population(), a.population(), "same city")
	check(not FileAccess.file_exists(DIR.path_join(SaveGame.QUICKSAVE + ".tmp")), "no temporary file left")
	_clean()


func test_autosave_keeps_three_copies() -> void:
	_clean()
	var c := _town()
	for silver in [101, 102, 103, 104]:
		c.treasury = silver
		check_eq(SaveGame.autosave(c, DIR), "", "autosave %d" % silver)
	var expect := [104, 103, 102]
	for i in 3:
		var r := SaveGame.read(DIR.path_join(SaveGame.AUTOSAVES[i]))
		check_eq(r["city"].treasury if r["city"] else -1, expect[i], SaveGame.AUTOSAVES[i])
	check_eq(DirAccess.get_files_at(DIR).size(), 3, "three files, the oldest is gone")
	_clean()


func test_failed_save_leaves_the_old_file() -> void:
	_clean()
	var c := _town()
	c.treasury = 111
	SaveGame.write(c, SaveGame.QUICKSAVE, DIR)
	DirAccess.make_dir_recursive_absolute(DIR.path_join(SaveGame.QUICKSAVE + ".tmp")) # blocks the new file
	c.treasury = 222
	check_eq(SaveGame.write(c, SaveGame.QUICKSAVE, DIR), SaveGame.ERR_SAVE_FAILED, "the save fails")
	check_eq(SaveGame.read(DIR.path_join(SaveGame.QUICKSAVE))["city"].treasury, 111, "the old save still loads")
	_clean()


func test_no_save_yet() -> void:
	_clean()
	check_eq(SaveGame.latest(DIR), "", "nothing to load")
	check_eq(SaveGame.read(DIR.path_join(SaveGame.QUICKSAVE))["error"], SaveGame.ERR_NO_SAVE, "clear message")


# --- Damaged and foreign files ---

func test_damaged_files_are_refused() -> void:
	var good := SaveGame.pack(_town())
	var flipped := good.duplicate()
	flipped[good.size() / 2] ^= 0xFF
	var cases := {
		"one byte changed": flipped,
		"cut short": good.slice(0, good.size() - 100),
		"empty": PackedByteArray(),
		"not a save": "Hello, Seorabeol".to_utf8_buffer(),
		"header only": good.slice(0, SaveGame.HEADER_SIZE),
	}
	for label: String in cases:
		var r := SaveGame.city_from_bytes(cases[label])
		check_eq(r["error"], SaveGame.ERR_DAMAGED, label)
		check(r["city"] == null, label + ": no half-loaded city")


func test_other_versions_say_so() -> void:
	var newer := SaveGame.pack(_town())
	newer.encode_u32(4, SaveGame.VERSION + 1)
	check_eq(SaveGame.city_from_bytes(newer)["error"], SaveGame.ERR_NEWER, "newer game version")
	var older := SaveGame.pack(_town())
	older.encode_u32(4, SaveGame.VERSION - 1)
	check_eq(SaveGame.city_from_bytes(older)["error"], SaveGame.ERR_OLDER, "older game version")
