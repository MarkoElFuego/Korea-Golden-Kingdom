extends RefCounted
## Moving a walker along its path of road tiles, shared by every walker type.
## A walker Dictionary has "path" (road tiles), "index" (tile it is on) and
## "progress" (0..1 toward path[index + 1]).


## Moves `w` forward by `step` tiles. Returns true when it reached the last tile.
static func advance(w: Dictionary, step: float) -> bool:
	w["progress"] += step
	var last: int = w["path"].size() - 1
	while w["progress"] >= 1.0 and w["index"] < last:
		w["index"] += 1
		w["progress"] -= 1.0
	if w["index"] >= last:
		w["progress"] = 0.0
		return true
	return false


## Starts `w` on a new path (the name avoids Resource.set_path on the script object).
static func follow(w: Dictionary, path: Array[Vector2i]) -> void:
	w["path"] = path
	w["index"] = 0
	w["progress"] = 0.0


static func here(w: Dictionary) -> Vector2i:
	return w["path"][w["index"]]


## True when every tile still ahead is a road.
static func path_still_open(w: Dictionary, grid) -> bool:
	for i in range(w["index"], w["path"].size()):
		if not grid.is_road(w["path"][i]):
			return false
	return true
