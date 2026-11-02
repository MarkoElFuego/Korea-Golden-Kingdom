extends Node3D
## Draws the carriers: body (capsule, 1.7 m), jige (wooden A-frame on the back) and the
## load on it, colored by good. Three MultiMeshes, so hundreds of walkers stay cheap.
## Positions are smoothed between simulation ticks; only reads the city.

const Balance = preload("res://scripts/data/balance.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Grid = preload("res://scripts/sim/grid.gd")

const BODY_COLOR := "#ece6d8" # white hemp clothes
const JIGE_COLOR := "#8a5c35"
const SIDE_OFFSET := 0.6 # meters to the right of the road center, so two-way traffic passes

var city # scripts/sim/city.gd
var _body: MultiMeshInstance3D
var _jige: MultiMeshInstance3D
var _load: MultiMeshInstance3D


func setup(city_ref) -> void:
	city = city_ref
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = Balance.HUMAN_HEIGHT
	capsule.radial_segments = 8
	capsule.rings = 2
	_body = _layer("Bodies", capsule)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.5, 1.3, 0.12)
	_jige = _layer("Jige", frame)
	var cargo := BoxMesh.new()
	cargo.size = Vector3(0.55, 0.55, 0.45)
	_load = _layer("Loads", cargo)


func _layer(layer_name: String, mesh: Mesh) -> MultiMeshInstance3D:
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
	m.roughness = 0.9
	node.material_override = m
	add_child(node)
	return node


func _process(_delta: float) -> void:
	if city == null:
		return
	var walkers: Array[Dictionary] = city.carriers.all()
	var count := walkers.size()
	var loaded := 0
	for w in walkers:
		if w["cargo"] != "":
			loaded += 1
	_body.multimesh.instance_count = count
	_jige.multimesh.instance_count = count
	_load.multimesh.instance_count = loaded
	var step := Balance.CARRIER_SPEED / Balance.TICKS_PER_SECOND
	var ahead: float = city.clock.tick_fraction() * step
	var body_color := Color(BODY_COLOR)
	var jige_color := Color(JIGE_COLOR)
	var li := 0
	for i in count:
		var w := walkers[i]
		var frame := _walker_frame(w, ahead)
		_body.multimesh.set_instance_transform(i, frame.translated_local(Vector3(0, Balance.HUMAN_HEIGHT * 0.5, 0)))
		_body.multimesh.set_instance_color(i, body_color)
		_jige.multimesh.set_instance_transform(i, frame.translated_local(Vector3(0, 1.0, 0.3)))
		_jige.multimesh.set_instance_color(i, jige_color)
		if w["cargo"] != "":
			_load.multimesh.set_instance_transform(li, frame.translated_local(Vector3(0, 1.45, 0.55)))
			_load.multimesh.set_instance_color(li, Color(Goods.GOODS[w["cargo"]]["color"]))
			li += 1


## Where the walker stands and which way it faces (local -Z = walking direction,
## so the jige sits on local +Z, the back).
func _walker_frame(w: Dictionary, ahead: float) -> Transform3D:
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
	# Keep to the right side of the road.
	pos += facing.x * SIDE_OFFSET
	pos.y = 0.12 # road surface
	return Transform3D(facing, pos)
