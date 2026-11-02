extends RefCounted
## Square tile grid: terrain, occupancy and tile <-> world (meters) conversion.
## Tile (0, 0) is the north-west corner. +x goes east, +y goes south (world +Z).
## World origin (0, 0, 0) is the north-west corner of tile (0, 0).

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")

const EMPTY := -1

var width: int
var height: int
var terrain: PackedByteArray
var occupant: PackedInt32Array # building instance id per tile, EMPTY when free


func _init(w: int, h: int, terrain_data := PackedByteArray()) -> void:
	width = w
	height = h
	if terrain_data.size() == w * h:
		terrain = terrain_data
	else:
		terrain = PackedByteArray()
		terrain.resize(w * h)
		terrain.fill(Terrain.GRASS)
	occupant = PackedInt32Array()
	occupant.resize(w * h)
	occupant.fill(EMPTY)


# --- Conversion ---

static func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3((tile.x + 0.5) * Balance.TILE_SIZE, 0.0, (tile.y + 0.5) * Balance.TILE_SIZE)


static func world_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / Balance.TILE_SIZE), floori(pos.z / Balance.TILE_SIZE))


## World position of a footprint's pivot (its center, at ground level).
## origin = north-west tile of the footprint.
static func footprint_center(origin: Vector2i, size: Vector2i) -> Vector3:
	return Vector3((origin.x + size.x * 0.5) * Balance.TILE_SIZE, 0.0, (origin.y + size.y * 0.5) * Balance.TILE_SIZE)


# --- Tiles ---

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func index(tile: Vector2i) -> int:
	return tile.y * width + tile.x


func get_terrain(tile: Vector2i) -> int:
	return terrain[index(tile)]


func set_terrain(tile: Vector2i, value: int) -> void:
	terrain[index(tile)] = value


func is_occupied(tile: Vector2i) -> bool:
	return occupant[index(tile)] != EMPTY


# --- Footprints ---

## Why a footprint can or cannot be placed: "" when it fits,
## otherwise "out_of_bounds", "occupied" or "terrain".
func check_footprint(origin: Vector2i, size: Vector2i, allowed_terrain: Array[int]) -> String:
	for dy in size.y:
		for dx in size.x:
			var t := origin + Vector2i(dx, dy)
			if not in_bounds(t):
				return "out_of_bounds"
	for dy in size.y:
		for dx in size.x:
			var t := origin + Vector2i(dx, dy)
			if is_occupied(t):
				return "occupied"
			if not allowed_terrain.has(get_terrain(t)):
				return "terrain"
	return ""


func can_place(origin: Vector2i, size: Vector2i, allowed_terrain: Array[int]) -> bool:
	return check_footprint(origin, size, allowed_terrain) == ""


## Marks the footprint as taken by building `instance_id`. Returns false (and changes
## nothing) when it does not fit.
func occupy(origin: Vector2i, size: Vector2i, instance_id: int, allowed_terrain: Array[int]) -> bool:
	if not can_place(origin, size, allowed_terrain):
		return false
	for dy in size.y:
		for dx in size.x:
			occupant[index(origin + Vector2i(dx, dy))] = instance_id
	return true


func vacate(origin: Vector2i, size: Vector2i) -> void:
	for dy in size.y:
		for dx in size.x:
			var t := origin + Vector2i(dx, dy)
			if in_bounds(t):
				occupant[index(t)] = EMPTY


func count_terrain(value: int) -> int:
	var n := 0
	for v in terrain:
		if v == value:
			n += 1
	return n
