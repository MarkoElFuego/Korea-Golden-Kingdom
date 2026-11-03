extends RefCounted
## Every building standing in the city. Roads are not here; they live in the grid.
##
## An instance is a Dictionary:
##   id: int (1, 2, 3... never reused), type: String (buildings.gd id),
##   origin: Vector2i (north-west tile), size: Vector2i (footprint after rotation),
##   rotation: int (0..3, see Grid.DOOR_DIRECTIONS), tier: int (houses: 0 = vacant lot)

var _items := {} # id -> instance
var _next_id := 1


func add(type: String, origin: Vector2i, size: Vector2i, rotation: int, tier: int) -> Dictionary:
	var instance := {
		"id": _next_id, "type": type, "origin": origin, "size": size,
		"rotation": rotation, "tier": tier,
	}
	_items[_next_id] = instance
	_next_id += 1
	return instance


func remove(id: int) -> Dictionary:
	var instance: Dictionary = _items.get(id, {})
	_items.erase(id)
	return instance


func get_instance(id: int) -> Dictionary:
	return _items.get(id, {})


func has(id: int) -> bool:
	return _items.has(id)


func count() -> int:
	return _items.size()


## All instances in the order they were built.
## (Ids only grow and a Dictionary keeps insertion order, so no sorting is needed.)
func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_items.values())
	return result


# --- Saving (save_game.gd) ---

func to_save() -> Dictionary:
	return {"items": _items, "next_id": _next_id}


func load_save(d: Dictionary) -> void:
	_items = d["items"]
	_next_id = d["next_id"]
