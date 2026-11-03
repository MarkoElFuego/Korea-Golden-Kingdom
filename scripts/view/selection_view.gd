extends Node3D
## The building chosen in the building window, on the map: a thin frame around it and,
## when "Show range" is on, the tiles it reaches with a column over every house in range
## (green: the house has its service now, red: it does not). Only reads the city.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")

const FRAME_COLOR := Color("#3d8f84") # dancheong teal
const RANGE_TINT := Color(0.25, 0.56, 0.48, 0.3) # as when placing a building
const SERVED := Color("#55803a")
const NOT_SERVED := Color("#b8473a")
const FRAME_WIDTH := 0.3 # meters
const COLUMN := Vector3(1.4, 4.0, 1.4) # meters
const REFRESH := 0.5 # seconds

var city # scripts/sim/city.gd
var selected := 0 # building id, 0 when none
var show_range := false # the player's choice; kept for the next building
var _frame: MultiMeshInstance3D
var _tiles: MultiMeshInstance3D
var _columns: MultiMeshInstance3D
var _wait := 0.0


func setup(city_ref) -> void:
	city = city_ref
	_frame = _layer("Frame", BoxMesh.new(), false)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Balance.TILE_SIZE
	_tiles = _layer("Range", plane, true)
	var box := BoxMesh.new()
	box.size = COLUMN
	_columns = _layer("Houses", box, false)


func select(id: int) -> void:
	selected = id
	refresh()


func set_show_range(on: bool) -> void:
	show_range = on
	refresh()


## True when the selected building has a range to show (Well, Market, Seonangdang).
func has_range() -> bool:
	var instance: Dictionary = city.buildings.get_instance(selected)
	return not instance.is_empty() and not city.coverage_preview(instance["type"], instance["origin"], instance["rotation"]).is_empty()


func _process(delta: float) -> void:
	if selected == 0:
		return
	_wait -= delta
	if _wait <= 0.0:
		refresh()


func refresh() -> void:
	_wait = REFRESH
	var instance: Dictionary = city.buildings.get_instance(selected) if selected != 0 else {}
	if instance.is_empty():
		selected = 0
		for layer in [_frame, _tiles, _columns]:
			layer.visible = false
		return
	_draw_frame(instance)
	var ranged := show_range and has_range()
	_tiles.visible = ranged
	_columns.visible = ranged
	if ranged:
		_draw_range(city.range_of(instance))


## Four thin bars around the footprint, on the ground it stands on.
func _draw_frame(instance: Dictionary) -> void:
	var size := Vector2(instance["size"]) * Balance.TILE_SIZE
	var center := Grid.footprint_center(instance["origin"], instance["size"])
	center.y = TerrainView.footprint_ground(city.grid, instance["origin"], instance["size"]) + 0.15
	var w := FRAME_WIDTH
	var bars: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(size.x + w, 0.3, w)), center + Vector3(0, 0, -size.y * 0.5)),
		Transform3D(Basis.from_scale(Vector3(size.x + w, 0.3, w)), center + Vector3(0, 0, size.y * 0.5)),
		Transform3D(Basis.from_scale(Vector3(w, 0.3, size.y + w)), center + Vector3(-size.x * 0.5, 0, 0)),
		Transform3D(Basis.from_scale(Vector3(w, 0.3, size.y + w)), center + Vector3(size.x * 0.5, 0, 0)),
	]
	var colors: Array[Color] = [FRAME_COLOR, FRAME_COLOR, FRAME_COLOR, FRAME_COLOR]
	_fill(_frame.multimesh, bars, colors)
	_frame.visible = true


func _draw_range(reach: Dictionary) -> void:
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for t: Vector2i in reach["tiles"]:
		xforms.append(Transform3D(Basis.IDENTITY, Grid.tile_to_world(t) + Vector3(0, 0.2, 0)))
		colors.append(RANGE_TINT)
	_fill(_tiles.multimesh, xforms, colors)
	xforms = []
	colors = []
	for id: int in reach["houses"]:
		var house: Dictionary = city.buildings.get_instance(id)
		var top: float = Balance.TILE_SIZE + COLUMN.y * 0.5
		xforms.append(Transform3D(Basis.IDENTITY, Grid.footprint_center(house["origin"], house["size"]) + Vector3(0, top, 0)))
		colors.append(SERVED if reach["houses"][id] else NOT_SERVED)
	_fill(_columns.multimesh, xforms, colors)


## Houses in range with and without the service (for tests): {"served": n, "not": n}.
func house_counts() -> Dictionary:
	var instance: Dictionary = city.buildings.get_instance(selected)
	var result := {"served": 0, "not": 0}
	for served: bool in city.range_of(instance)["houses"].values():
		result["served" if served else "not"] += 1
	return result


func _layer(layer_name: String, mesh: Mesh, see_through: bool) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = layer_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	node.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


static func _fill(mm: MultiMesh, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
