extends Node3D
## Draws the terrain: one MultiMesh of boxes per terrain type (one box per tile),
## plus a MultiMesh of placeholder trees on Forest. Only reads the grid.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")

const BOTTOM := -2.0 # meters, underside of every tile box
const TOP := {
	Terrain.RIVER: -0.5,
	Terrain.SEA: -0.8,
}
const COLOR_VARIATION := 0.035 # random brightness per tile
const CHECKER := 0.02 # alternate tiles slightly, so the 4 m grid can be read
const TREES_PER_FOREST_TILE := 2
const TREE_COLOR := "#6f8f4e"
const TREE_COLOR_DARK := "#55703a"


func build(grid: Grid, checker := true) -> void:
	for child in get_children():
		child.queue_free()
	var mountain_depth := _mountain_depth(grid)
	var per_type: Array[Array] = []
	for i in Terrain.COUNT:
		per_type.append([])
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			per_type[grid.get_terrain(tile)].append(tile)
	for terrain_type in Terrain.COUNT:
		var tiles: Array = per_type[terrain_type]
		if tiles.is_empty():
			continue
		add_child(_build_tiles(terrain_type, tiles, mountain_depth, grid.width, checker))
	if not per_type[Terrain.FOREST].is_empty():
		add_child(_build_trees(per_type[Terrain.FOREST]))


func _build_tiles(terrain_type: int, tiles: Array, mountain_depth: PackedInt32Array, width: int, checker: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = tiles.size()
	var base := Color(Terrain.INFO[terrain_type]["color"])
	var t := Balance.TILE_SIZE
	for i in tiles.size():
		var tile: Vector2i = tiles[i]
		var h := _hash01(tile.x, tile.y)
		var top := _tile_top(terrain_type, h, mountain_depth[tile.y * width + tile.x])
		var thickness := top - BOTTOM
		var xf := Transform3D(Basis.from_scale(Vector3(t, thickness, t)),
			Vector3((tile.x + 0.5) * t, BOTTOM + thickness * 0.5, (tile.y + 0.5) * t))
		mm.set_instance_transform(i, xf)
		var shade := 1.0 + (h - 0.5) * 2.0 * COLOR_VARIATION
		if checker and (tile.x + tile.y) % 2 == 0:
			shade += CHECKER
		var c := base
		if terrain_type == Terrain.MOUNTAIN:
			c = Color("#9e998f").lerp(Color("#bdb8ad"), clampf(top / 14.0, 0.0, 1.0))
		mm.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade))
	var node := MultiMeshInstance3D.new()
	node.name = "Terrain_" + Terrain.INFO[terrain_type]["id"]
	node.multimesh = mm
	node.material_override = _material(Terrain.is_water(terrain_type))
	return node


func _tile_top(terrain_type: int, h: float, depth: int) -> float:
	match terrain_type:
		Terrain.MOUNTAIN:
			return minf(2.0 + depth * 2.2 + h * 1.5, 18.0)
		Terrain.ROCKY_HILL:
			return 0.6 + h * 0.6
		Terrain.RIVER, Terrain.SEA:
			return TOP[terrain_type]
	return 0.0


func _build_trees(tiles: Array) -> MultiMeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	mm.instance_count = tiles.size() * TREES_PER_FOREST_TILE
	var t := Balance.TILE_SIZE
	var light := Color(TREE_COLOR)
	var dark := Color(TREE_COLOR_DARK)
	var rng := RandomNumberGenerator.new()
	for i in tiles.size():
		var tile: Vector2i = tiles[i]
		rng.seed = tile.x * 92821 + tile.y * 68917 + 7
		for k in TREES_PER_FOREST_TILE:
			var radius := rng.randf_range(1.0, 1.5)
			var height := rng.randf_range(4.5, 7.0)
			var pos := Vector3((tile.x + rng.randf_range(0.25, 0.75)) * t, height * 0.5, (tile.y + rng.randf_range(0.25, 0.75)) * t)
			mm.set_instance_transform(i * TREES_PER_FOREST_TILE + k, Transform3D(Basis.from_scale(Vector3(radius, height, radius)), pos))
			mm.set_instance_color(i * TREES_PER_FOREST_TILE + k, dark.lerp(light, rng.randf()))
	var node := MultiMeshInstance3D.new()
	node.name = "Trees"
	node.multimesh = mm
	node.material_override = _material(false)
	return node


func _material(water: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true # palette colors are sRGB hex values
	m.albedo_color = Color.WHITE
	m.roughness = 0.7 if water else 1.0
	return m


## For every mountain tile, how many tiles it lies from the nearest non-mountain tile.
func _mountain_depth(grid: Grid) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(grid.width * grid.height)
	depth.fill(-1)
	var frontier: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if grid.get_terrain(Vector2i(x, y)) != Terrain.MOUNTAIN:
				depth[y * grid.width + x] = 0
				frontier.append(Vector2i(x, y))
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var head := 0
	while head < frontier.size():
		var tile := frontier[head]
		head += 1
		var d := depth[tile.y * grid.width + tile.x]
		for dir in dirs:
			var n := tile + dir
			if grid.in_bounds(n) and depth[n.y * grid.width + n.x] == -1:
				depth[n.y * grid.width + n.x] = d + 1
				frontier.append(n)
	# Map edge counts as more mountain, not as valley.
	for i in depth.size():
		if depth[i] == -1:
			depth[i] = 1
	return depth


## Stable pseudo-random 0..1 per tile (looks only, not simulation).
static func _hash01(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10006.0
