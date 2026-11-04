extends Node3D
## The advisor's arrow on the map (scripts/sim/guide.gd): a wooden arrow with a red dancheong
## head bobbing over a good spot for the next building of the goal, the building's outline on
## the ground in soft gold, and a note ("Rice Paddy here"). Only reads the city.

const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Balance = preload("res://scripts/data/balance.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")

const GOLD := Color(0.86, 0.68, 0.25, 0.45)
const HEAD := Color("#b8473a") # dancheong red
const SHAFT := Color("#8a5c35") # wood
const HOVER := 8.0 # meters over the ground
const BOB := 1.0 # meters up and down
const ARROW_SCALE := 1.8 # big enough to find at the usual zoom

var city # scripts/sim/city.gd
var _outline: MeshInstance3D
var _arrow: Node3D
var _note: Label3D
var _time := 0.0
var _shown := {} # the spot drawn now
var _ground := 0.0 # ground height under the spot


func setup(city_ref) -> void:
	city = city_ref
	_outline = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_outline.mesh = plane
	_outline.material_override = _material(GOLD, true)
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)

	_arrow = Node3D.new()
	add_child(_arrow)
	_arrow.scale = Vector3.ONE * ARROW_SCALE
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 3.0, 0.5)
	shaft.mesh = box
	shaft.position.y = 2.6
	shaft.material_override = _material(SHAFT, false)
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.3
	cone.bottom_radius = 0.0 # the point faces down
	cone.height = 1.8
	cone.radial_segments = 4 # a squared arrowhead, like a carved one
	head.mesh = cone
	head.position.y = 0.9
	head.material_override = _material(HEAD, false)
	_arrow.add_child(head)

	_note = Label3D.new()
	_note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_note.no_depth_test = true
	_note.fixed_size = true
	_note.pixel_size = 0.0012
	_note.font_size = 36
	_note.outline_size = 10
	_note.modulate = Color("#3a2e22")
	_note.outline_modulate = Color("#ece6d8")
	add_child(_note)
	visible = false


func _material(color: Color, see_through: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _process(delta: float) -> void:
	if city == null or city.objectives == null:
		visible = false
		return
	var spot: Dictionary = city.objectives.guide.spot()
	visible = not spot.is_empty()
	if not visible:
		return
	_time += delta
	if spot != _shown:
		_shown = spot.duplicate()
		_place(spot)
	_arrow.position.y = _ground + HOVER + sin(_time * 2.0) * BOB



func _place(spot: Dictionary) -> void:
	var origin: Vector2i = spot["origin"]
	var size: Vector2i = spot["size"]
	var centre := Grid.footprint_center(origin, size)
	_ground = TerrainView.footprint_ground(city.grid, origin, size)
	_outline.position = Vector3(centre.x, _ground + 0.2, centre.z)
	_outline.scale = Vector3(size.x * Balance.TILE_SIZE, 1.0, size.y * Balance.TILE_SIZE)
	_arrow.position = Vector3(centre.x, _ground + HOVER, centre.z)
	_note.position = Vector3(centre.x, _ground + HOVER + 8.0, centre.z)
	if spot["type"] == "road":
		_note.text = tr("UI_GUIDE_ROAD")
	else:
		_note.text = tr("UI_GUIDE_HERE") % tr(Buildings.get_building(spot["type"])["name_key"])


## Where the camera should look to see the arrow (Vector3.INF when there is none).
func target() -> Vector3:
	if not visible or _shown.is_empty():
		return Vector3.INF
	return Grid.footprint_center(_shown["origin"], _shown["size"])
