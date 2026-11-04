extends Node3D
## Draws the dokkaebi event (scripts/sim/dokkaebi.gd); only reads the city.
##   Dokkaebi fires (dokkaebibul) - pale blue flames floating over the hill they come from,
##                                  from the warning until dawn;
##   Dokkaebi                     - stocky indigo figures with a horn and a blue fire beside
##                                  them, the stolen load on the back on the way home;
##   Night                        - while they walk, the sun dims to a bluish night.
## Temporary shapes until the owner's models (docs/art-bible.md): capsule, box, sphere.

const Balance = preload("res://scripts/data/balance.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")

const BODY_COLOR := "#5563b8" # indigo, light enough to read at night
const HORN_COLOR := "#d9cba3" # bone
const FIRE_COLOR := Color(0.45, 0.7, 1.0) # dokkaebibul
const FLAMES_PER_FIRE := 7
const SCALE := 1.3 # dokkaebi are bigger than people
const SIDE_OFFSET := 0.6
const NIGHT_SUN := Color("#8ea4dc")
const NIGHT_SUN_ENERGY := 0.3
const NIGHT_AMBIENT := 0.25
const NIGHT_SKY := 0.3 # sky brightness at night
const NIGHT_FADE := 1.5 # seconds to fall or lift

var city # scripts/sim/city.gd
var sun: DirectionalLight3D
var environment: Environment
var night := 0.0 # 0 day .. 1 night (for tests and the view)
var _day_sun := Color.WHITE
var _day_energy := 1.0
var _day_ambient := 1.0
var _day_sky := 1.0
var _layers := {} # part -> MultiMeshInstance3D
var _items := {}
var _time := 0.0


func setup(city_ref, sun_ref: DirectionalLight3D = null, environment_ref: Environment = null) -> void:
	city = city_ref
	sun = sun_ref
	environment = environment_ref
	if sun:
		_day_sun = sun.light_color
		_day_energy = sun.light_energy
	if environment:
		_day_ambient = environment.ambient_light_energy
		_day_sky = environment.background_energy_multiplier
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = Balance.HUMAN_HEIGHT * 0.85
	body.radial_segments = 8
	body.rings = 2
	_layer("body", body, false)
	var horn := BoxMesh.new()
	horn.size = Vector3(0.12, 0.35, 0.12)
	_layer("horn", horn, false)
	var load := BoxMesh.new()
	load.size = Vector3(0.6, 0.6, 0.5)
	_layer("load", load, false)
	var flame := SphereMesh.new()
	flame.radius = 0.6
	flame.height = 1.5 # a tall drop of fire
	flame.radial_segments = 8
	flame.rings = 4
	_layer("flame", flame, true)


func _layer(part: String, mesh: Mesh, glowing: bool) -> void:
	var node := MultiMeshInstance3D.new()
	node.name = part.capitalize()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	node.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if glowing:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		m.roughness = 0.9
	node.material_override = m
	add_child(node)
	_layers[part] = node


func _process(delta: float) -> void:
	if city == null:
		return
	_time += delta
	var target := 1.0 if city.dokkaebi.is_night() else 0.0
	night = move_toward(night, target, delta / NIGHT_FADE)
	_light()
	for part: String in _layers:
		_items[part] = [[], []]
	for tile: Vector2i in city.dokkaebi.fires():
		_fire(tile)
	var ahead: float = city.clock.tick_fraction() * Balance.DOKKAEBI_SPEED / Balance.TICKS_PER_SECOND
	for w: Dictionary in city.dokkaebi.all():
		if w["wait"] <= 0:
			_dokkaebi(w, ahead)
	for part: String in _layers:
		var mm: MultiMesh = _layers[part].multimesh
		var transforms: Array = _items[part][0]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
			mm.set_instance_color(i, _items[part][1][i])


func _light() -> void:
	if sun:
		sun.light_color = _day_sun.lerp(NIGHT_SUN, night)
		sun.light_energy = lerpf(_day_energy, NIGHT_SUN_ENERGY, night)
	if environment:
		environment.ambient_light_energy = lerpf(_day_ambient, NIGHT_AMBIENT, night)
		environment.background_energy_multiplier = lerpf(_day_sky, NIGHT_SKY, night)


## A few flames bobbing over the hill tile.
func _fire(tile: Vector2i) -> void:
	var center := Grid.tile_to_world(tile)
	center.y = TerrainView.ground_top(city.grid, tile) + 2.0
	for i in FLAMES_PER_FIRE:
		var a := _time * 0.7 + i * TAU / FLAMES_PER_FIRE
		var pos := center + Vector3(cos(a) * 3.0, sin(_time * 2.1 + i) * 0.8 + (i % 3) * 0.8, sin(a) * 3.0)
		var flicker := 0.75 + 0.25 * sin(_time * 9.0 + i * 1.7)
		_add("flame", Transform3D(Basis.from_scale(Vector3.ONE * flicker), pos), Color(FIRE_COLOR, 0.8))


func _dokkaebi(w: Dictionary, ahead: float) -> void:
	var frame := _frame(w, ahead).scaled_local(Vector3.ONE * SCALE)
	var hop := absf(sin(_time * 6.0 + w["id"])) * 0.15 # a bouncing, mischievous walk
	var body := frame.translated_local(Vector3(0, Balance.HUMAN_HEIGHT * 0.42 + hop, 0)).scaled_local(Vector3(1.1, 1.0, 1.0))
	_add("body", body, Color(BODY_COLOR))
	_add("horn", frame.translated_local(Vector3(0, Balance.HUMAN_HEIGHT * 0.85 + 0.15 + hop, -0.05)), Color(HORN_COLOR))
	var orb := frame.translated_local(Vector3(0.7, 1.3 + sin(_time * 4.0 + w["id"]) * 0.2, -0.3))
	_add("flame", Transform3D(Basis.from_scale(Vector3.ONE * 0.7), orb.origin), Color(FIRE_COLOR, 0.9))
	if w["cargo"] != "":
		_add("load", frame.translated_local(Vector3(0, 1.3 + hop, 0.45)), Color(Goods.GOODS[w["cargo"]]["color"]))


func _add(part: String, xform: Transform3D, color: Color) -> void:
	_items[part][0].append(xform)
	_items[part][1].append(color)


## Where the dokkaebi stands and which way it faces (as in walker_view.gd).
func _frame(w: Dictionary, ahead: float) -> Transform3D:
	var path: Array = w["path"]
	var i: int = w["index"]
	var a: Vector3 = Grid.tile_to_world(path[i])
	var b: Vector3 = Grid.tile_to_world(path[mini(i + 1, path.size() - 1)])
	var t := minf(w["progress"] + ahead, 1.0) if i < path.size() - 1 else 0.0
	var pos := a.lerp(b, t)
	var dir := b - a
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var facing := Basis.looking_at(dir.normalized(), Vector3.UP)
	pos += facing.x * SIDE_OFFSET
	pos.y = 0.12
	return Transform3D(facing, pos)
