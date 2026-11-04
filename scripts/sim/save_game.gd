extends RefCounted
## Saving and loading the city (CLAUDE.md, "Stabilnost pre obima").
##
## A save file is: "KGKS" (4 bytes), format version (4 bytes), payload length (4 bytes),
## SHA-256 of the payload (32 bytes), payload (the city's to_save() data, Godot binary).
## The checksum is tested before anything is decoded, so a damaged file is refused
## with a clear message instead of loading half a city.
##
## A file is never written over directly: the new save goes to "<name>.tmp", is read
## back and checked, and only then takes the old file's place. Autosaves rotate three
## copies (autosave_1 newest, autosave_3 oldest); the oldest goes only after the new one
## is safely on disk.

const City = preload("res://scripts/sim/city.gd")

const VERSION := 4 # raise when the saved data changes shape
const MAGIC := "KGKS"
const HEADER_SIZE := 44 # magic 4 + version 4 + length 4 + SHA-256 32
const SAVE_DIR := "user://saves"
const QUICKSAVE := "quicksave.sav"
const AUTOSAVES: Array[String] = ["autosave_1.sav", "autosave_2.sav", "autosave_3.sav"]

# Text keys (data/text/en.csv) returned as results.
const DONE := "" # no error
const ERR_SAVE_FAILED := "SAVE_FAILED"
const ERR_NO_SAVE := "LOAD_NO_SAVE"
const ERR_DAMAGED := "LOAD_DAMAGED"
const ERR_NEWER := "LOAD_NEWER_VERSION"
const ERR_OLDER := "LOAD_OLDER_VERSION"


# --- Bytes ---

## The whole city as save-file bytes.
static func pack(city) -> PackedByteArray:
	var payload := var_to_bytes(city.to_save())
	var out := StreamPeerBuffer.new()
	out.put_data(MAGIC.to_ascii_buffer())
	out.put_u32(VERSION)
	out.put_u32(payload.size())
	out.put_data(_hash(payload))
	out.put_data(payload)
	return out.data_array


## {"error": text key or "", "data": the saved city data}. Checks everything before decoding.
static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {"error": ERR_DAMAGED, "data": {}}
	var version := bytes.decode_u32(4)
	if version > VERSION:
		return {"error": ERR_NEWER, "data": {}}
	if version < VERSION:
		return {"error": ERR_OLDER, "data": {}}
	var length := bytes.decode_u32(8)
	var payload := bytes.slice(HEADER_SIZE)
	if payload.size() != length or _hash(payload) != bytes.slice(12, HEADER_SIZE):
		return {"error": ERR_DAMAGED, "data": {}}
	var data = bytes_to_var(payload)
	if not data is Dictionary or not data.has("clock"):
		return {"error": ERR_DAMAGED, "data": {}}
	return {"error": DONE, "data": data}


## A new city from save-file bytes: {"error", "city"}.
static func city_from_bytes(bytes: PackedByteArray) -> Dictionary:
	var result := unpack(bytes)
	if result["error"] != DONE:
		return {"error": result["error"], "city": null}
	var city := City.new(result["data"]["map_seed"])
	city.load_save(result["data"])
	return {"error": DONE, "city": city}


static func _hash(bytes: PackedByteArray) -> PackedByteArray:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish()


# --- Files ---

## Saves to `file` in `dir`. Returns "" or an error text key. The old file stays
## untouched unless the new one was written and checked.
static func write(city, file := QUICKSAVE, dir := SAVE_DIR) -> String:
	var tmp := _write_checked(pack(city), dir, file + ".tmp")
	if tmp == "":
		return ERR_SAVE_FAILED
	return DONE if _replace(tmp, dir.path_join(file)) else ERR_SAVE_FAILED


## Autosave: the new save becomes autosave_1, older ones move down, the oldest goes.
static func autosave(city, dir := SAVE_DIR) -> String:
	var tmp := _write_checked(pack(city), dir, "autosave.tmp")
	if tmp == "":
		return ERR_SAVE_FAILED
	for i in range(AUTOSAVES.size() - 1, 0, -1):
		var older := dir.path_join(AUTOSAVES[i - 1])
		if FileAccess.file_exists(older) and not _replace(older, dir.path_join(AUTOSAVES[i])):
			return ERR_SAVE_FAILED
	return DONE if _replace(tmp, dir.path_join(AUTOSAVES[0])) else ERR_SAVE_FAILED


## Loads one file: {"error", "city"}.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": ERR_NO_SAVE, "city": null}
	return city_from_bytes(FileAccess.get_file_as_bytes(path))


## The newest save in `dir` (quicksave or autosave), or "" when there is none.
static func latest(dir := SAVE_DIR) -> String:
	var best := ""
	var best_time := -1
	for file: String in [QUICKSAVE] + AUTOSAVES:
		var path := dir.path_join(file)
		if not FileAccess.file_exists(path):
			continue
		var time := FileAccess.get_modified_time(path)
		if time > best_time:
			best_time = time
			best = path
	return best


## Writes `bytes` to dir/name and reads them back. Returns the path, or "" on failure.
static func _write_checked(bytes: PackedByteArray, dir: String, name: String) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	var ok := f.get_error() == OK
	f.close()
	if not ok or FileAccess.get_file_as_bytes(path) != bytes:
		DirAccess.remove_absolute(path)
		return ""
	return path


## Moves `from` onto `to`. The old `to` is removed only right before the move, when the
## new file is already complete on disk.
static func _replace(from: String, to: String) -> bool:
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(to) != OK:
		return false
	return DirAccess.rename_absolute(from, to) == OK
