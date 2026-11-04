extends Node3D
## Service overlays (CLAUDE.md, "Čitljiv interfejs"): F1 water, F2 food, F3 Seonangdang,
## F5 Jang, F6 Onggi Jars (the last two for houses from tier 2, which want them), and
## F7 Gi: the ground of the whole map from red (low) through yellow to green (high),
## the Myeongdang in gold.
## Buildings fade, and every settled house gets a column, Zeus style: tall and green when
## the service is fresh, short and red when it is missing. The water overlay also tints
## the ground each Well reaches. The same key closes the overlay. Only reads the city.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")

signal changed(mode: String)

const GOOD := Color("#55803a")
const MID := Color("#d9a83a")
const BAD := Color("#b8473a")
const WATER_TINT := Color(0.35, 0.6, 0.85, 0.45)
const GI_GOLD := Color(1.0, 0.8, 0.2, 0.9) # the Myeongdang
const GI_ALPHA := 0.7
const COLUMN_WIDTH := 1.6 # meters
const COLUMN_MAX := 10.0 # meters, a fully served house
const REFRESH := 0.25 # seconds between redraws

var city # scripts/sim/city.gd
var city_view # scripts/view/city_view.gd (fades the buildings)
var mode := ""
var _columns: MultiMeshInstance3D
var _ground: MultiMeshInstance3D
var _wait := 0.0
var _gi_drawn := -1 # gi_map version on the ground now


func setup(city_ref, view) -> void:
	city = city_ref
	city_view = view
	_columns = _layer("Columns", _box(), false)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Balance.TILE_SIZE
	_ground = _layer("Ground", plane, true)


func _box() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(COLUMN_WIDTH, 1.0, COLUMN_WIDTH)
	return b


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


## Shows overlay `which`, or closes it when it is already shown.
func toggle(which: String) -> void:
	mode = "" if mode == which else which
	_columns.visible = mode != "" and mode != "gi"
	_ground.visible = mode == "water" or mode == "gi"
	_gi_drawn = -1
	city_view.set_faded(mode != "")
	_wait = 0.0
	changed.emit(mode)


func _process(delta: float) -> void:
	if mode == "":
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	if mode == "gi":
		if _gi_drawn != city.gi.version or _gi_drawn == -1:
			_draw_gi()
		return
	_draw_columns()
	if mode == "water":
		_draw_water()


func _draw_columns() -> void:
	var houses = city.houses
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for id: int in houses.state:
		var instance: Dictionary = city.buildings.get_instance(id)
		if instance["tier"] == 0 or (mode in ["jang", "jars"] and not houses.wants_jang(id)):
			continue
		var level := _level(instance)
		var h := maxf(0.4, level * COLUMN_MAX)
		var center := Grid.footprint_center(instance["origin"], instance["size"]) + Vector3(0, h * 0.5, 0)
		xforms.append(Transform3D(Basis.from_scale(Vector3(1, h, 1)), center))
		colors.append(_color(level))
	_fill(_columns.multimesh, xforms, colors)


## How well the house has this service, 0..1.
func _level(instance: Dictionary) -> float:
	var houses = city.houses
	var id: int = instance["id"]
	match mode:
		"water":
			return 1.0 if houses.is_met(instance, "water") else 0.0
		"food":
			return clampf(houses.state[id]["food"] / float(Houses.pantry_size(instance["tier"])), 0.0, 1.0)
		"seonangdang":
			var since: int = houses.days_since(id, "seonangdang")
			if since < 0:
				return 0.0
			return clampf(1.0 - since / float(Balance.SERVICE_DAYS), 0.0, 1.0)
		"jang":
			return clampf(houses.state[id]["jang"] / float(Houses.pantry_size(instance["tier"])), 0.0, 1.0)
		"jars":
			return clampf(houses.jars_days(id) / float(Balance.JARS_LAST_DAYS), 0.0, 1.0)
	return 0.0


static func _color(level: float) -> Color:
	if level <= 0.0:
		return BAD
	if level < 0.34:
		return BAD.lerp(MID, level / 0.34)
	return MID.lerp(GOOD, (level - 0.34) / 0.66)


func _draw_water() -> void:
	var tiles := {}
	for instance: Dictionary in city.buildings.all():
		if instance["type"] == "well":
			tiles.merge(city.coverage_preview("well", instance["origin"], instance["rotation"]))
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for t: Vector2i in tiles:
		xforms.append(Transform3D(Basis.IDENTITY, Grid.tile_to_world(t) + Vector3(0, 0.2, 0)))
		colors.append(WATER_TINT)
	_fill(_ground.multimesh, xforms, colors)


## Every tile tinted by its Gi.
func _draw_gi() -> void:
	var values: PackedByteArray = city.gi.values()
	_gi_drawn = city.gi.version
	var w: int = city.grid.width
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in values.size():
		@warning_ignore("integer_division")
		var t := Vector2i(i % w, i / w)
		var terrain: int = city.grid.get_terrain(t)
		if terrain == Terrain.MOUNTAIN or Terrain.is_water(terrain):
			continue # nothing is built there
		var ground := TerrainView.ground_top(city.grid, t) + 0.25 # on top of a rocky hill too
		xforms.append(Transform3D(Basis.IDENTITY, Grid.tile_to_world(t) + Vector3(0, ground, 0)))
		colors.append(gi_color(values[i]))
	_fill(_ground.multimesh, xforms, colors)


static func gi_color(gi: int) -> Color:
	if gi >= Balance.GI_MYEONGDANG:
		return GI_GOLD
	var c := _color(clampf((gi - 20) / 50.0, 0.0, 1.0)) # 20 and less red, 70 and more green
	c.a = GI_ALPHA
	return c


static func _fill(mm: MultiMesh, xforms: Array[Transform3D], colors: Array[Color]) -> void:
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
