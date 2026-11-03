extends Node3D
## Draws the walkers, each kind dressed so the player tells them apart at a glance:
##   Carrier       - white hemp clothes, jige (wooden A-frame) on the back, load colored by good;
##   Buyer         - indigo clothes, jige, rice on it on the way back;
##   Market vendor - persimmon-dyed clothes (galot), a basket on the head, rice in it while it lasts;
##   Shrine keeper - white robe with red and blue ribbons;
##   Settler       - dusty travel clothes and a big cloth bundle (bojagi).
## One MultiMesh per part, so hundreds of walkers stay cheap. Walkers of the building shown
## in the building window carry a small teal marker over their heads.
## Positions are smoothed between simulation ticks; only reads the city.

const Balance = preload("res://scripts/data/balance.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Grid = preload("res://scripts/sim/grid.gd")

const BODY_COLOR := "#ece6d8" # white hemp clothes
const JIGE_COLOR := "#8a5c35"
const SETTLER_COLOR := "#a88a52" # dusty travel clothes
const BUNDLE_COLOR := "#3f8f7a" # bojagi wrapping cloth
const BUYER_COLOR := "#4a5a7a" # indigo-dyed clothes
const VENDOR_COLOR := "#b5654a" # persimmon-dyed galot
const BASKET_COLOR := "#9a7b4f" # empty wicker
const KEEPER_COLOR := "#f6f3ec" # white robe
const RIBBON_RED := "#b8473a"
const RIBBON_BLUE := "#3d5a99"
const SIDE_OFFSET := 0.6 # meters to the right of the road center, so two-way traffic passes
const MARK_COLOR := "#3d8f84" # dancheong teal, as the frame of the chosen building

var city # scripts/sim/city.gd
var _layers := {} # part name -> MultiMeshInstance3D
var _items := {} # part name -> [transforms, colors], filled every frame
var highlight_home := 0 # building id whose walkers are marked (0: none)


func setup(city_ref) -> void:
	city = city_ref
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = Balance.HUMAN_HEIGHT
	capsule.radial_segments = 8
	capsule.rings = 2
	_layer("body", capsule)
	_layer("jige", _box(Vector3(0.5, 1.3, 0.12)))
	_layer("load", _box(Vector3(0.55, 0.55, 0.45)))
	_layer("basket", _box(Vector3(0.6, 0.22, 0.6)))
	_layer("ribbon", _box(Vector3(0.07, 0.8, 0.05)))
	_layer("mark", _box(Vector3(0.45, 0.45, 0.45)))
	_layers["mark"].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _layer(part: String, mesh: Mesh) -> void:
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
	m.roughness = 0.9
	node.material_override = m
	add_child(node)
	_layers[part] = node


func _process(_delta: float) -> void:
	if city == null:
		return
	for part: String in _layers:
		_items[part] = [[], []]
	var fraction: float = city.clock.tick_fraction()
	var carrier_ahead := fraction * Balance.CARRIER_SPEED / Balance.TICKS_PER_SECOND
	var settler_ahead := fraction * Balance.SETTLER_SPEED / Balance.TICKS_PER_SECOND
	var buyer_ahead := fraction * Balance.BUYER_SPEED / Balance.TICKS_PER_SECOND
	var roamer_ahead := fraction * Balance.ROAMER_SPEED / Balance.TICKS_PER_SECOND
	for w in city.carriers.all():
		var frame := _walker_frame(w, carrier_ahead)
		_porter(frame, BODY_COLOR, w["cargo"])
		_mark(w, frame)
	for w in city.settlers.all():
		var frame := _walker_frame(w, settler_ahead)
		_add("body", _body(frame), SETTLER_COLOR)
		_add("load", frame.translated_local(Vector3(0, 1.2, 0.35)).scaled_local(Vector3.ONE * 1.3), BUNDLE_COLOR)
	for w in city.services.all():
		_mark(w, _walker_frame(w, buyer_ahead if w["kind"] == "buyer" else roamer_ahead))
		match w["kind"]:
			"buyer":
				_porter(_walker_frame(w, buyer_ahead), BUYER_COLOR, w["good"] if w["cargo"] > 0 else "")
			"vendor":
				var frame := _walker_frame(w, roamer_ahead)
				_add("body", _body(frame), VENDOR_COLOR)
				var basket: String = Goods.GOODS["rice"]["color"] if w["food"] > 0 else BASKET_COLOR
				_add("basket", frame.translated_local(Vector3(0, Balance.HUMAN_HEIGHT + 0.11, 0)), basket)
			"keeper":
				var frame := _walker_frame(w, roamer_ahead)
				_add("body", _body(frame), KEEPER_COLOR)
				_add("ribbon", frame.translated_local(Vector3(-0.2, 1.05, 0.12)), RIBBON_RED)
				_add("ribbon", frame.translated_local(Vector3(0.2, 1.05, 0.12)), RIBBON_BLUE)
	for part: String in _layers:
		var mm: MultiMesh = _layers[part].multimesh
		var transforms: Array = _items[part][0]
		var colors: Array = _items[part][1]
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
			mm.set_instance_color(i, colors[i])


## A marker over the walker when its building is the one in the building window.
func _mark(w: Dictionary, frame: Transform3D) -> void:
	if highlight_home != 0 and w["home"] == highlight_home:
		var spin := Basis(Vector3.UP, PI * 0.25) * Basis(Vector3.RIGHT, PI * 0.25)
		_add("mark", Transform3D(spin, frame.origin + Vector3(0, Balance.HUMAN_HEIGHT + 0.9, 0)), MARK_COLOR)


## Someone with a jige on the back and maybe a load on it (carrier, buyer).
func _porter(frame: Transform3D, clothes: String, cargo: String) -> void:
	_add("body", _body(frame), clothes)
	_add("jige", frame.translated_local(Vector3(0, 1.0, 0.3)), JIGE_COLOR)
	if cargo != "":
		_add("load", frame.translated_local(Vector3(0, 1.45, 0.55)), Goods.GOODS[cargo]["color"])


func _body(frame: Transform3D) -> Transform3D:
	return frame.translated_local(Vector3(0, Balance.HUMAN_HEIGHT * 0.5, 0))


func _add(part: String, xform: Transform3D, color: String) -> void:
	_items[part][0].append(xform)
	_items[part][1].append(Color(color))


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
