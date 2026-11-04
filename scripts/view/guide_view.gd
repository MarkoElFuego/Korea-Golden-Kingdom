extends Node3D
## The advisor's plan on the map (scripts/sim/guide.gd), only reads the city:
##   gold marks    - the outline of every building still to build, where it fits best
##                   (the next one brighter);
##   gold road     - planned road tiles: the first street, roads to planned fields, a road
##                   to a building cut off from the town;
##   the arrow     - a wooden arrow with a red dancheong head bobbing over the next step
##                   (where to start dragging the road, or the next mark), with a note;
##   "Needs a road" over a building cut off from the town.
## Everything breathes slowly; nothing flashes.

const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Balance = preload("res://scripts/data/balance.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")

const GOLD := Color(0.93, 0.62, 0.12) # deep gold, to stand out on the green
const MARK_ALPHA := Vector2(0.45, 0.65) # other marks breathe between these
const NEXT_ALPHA := Vector2(0.6, 0.95) # the next mark
const ROAD_ALPHA := Vector2(0.55, 0.9)
const HEAD := Color("#b8473a") # dancheong red
const SHAFT := Color("#8a5c35") # wood
const HOVER := 8.0 # meters over the ground
const BOB := 1.0 # meters up and down
const ARROW_SCALE := 1.8 # big enough to find at the usual zoom
const BREATH := 3.0

var city # scripts/sim/city.gd
var _marks: Array[MeshInstance3D] = []
var _mark_mat: StandardMaterial3D
var _next_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _road: MultiMeshInstance3D
var _arrow: Node3D
var _note: Label3D
var _cut_note: Label3D
var _time := 0.0
var _shown := {} # the spot drawn now
var _drawn := [] # ghosts, roads and step drawn now
var _ground := 0.0 # ground height under the spot


func setup(city_ref) -> void:
	city = city_ref
	_mark_mat = _material(GOLD, true)
	_next_mat = _material(GOLD, true)
	_road_mat = _material(GOLD, true)

	_road = MultiMeshInstance3D.new()
	_road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var tile := PlaneMesh.new()
	tile.size = Vector2.ONE * Balance.TILE_SIZE * 0.8
	mm.mesh = tile
	_road.multimesh = mm
	_road.material_override = _road_mat
	add_child(_road)

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

	_note = _label(Color("#3a2e22"))
	_cut_note = _label(HEAD)
	_cut_note.text = tr("UI_GUIDE_NEEDS_ROAD")
	visible = false


func _label(color: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 36
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color("#ece6d8")
	add_child(l)
	return l


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
	var guide = city.objectives.guide
	var now := [guide.ghosts(), guide.roads(), guide.step()]
	visible = not (now[0].is_empty() and now[1].is_empty() and guide.spot().is_empty())
	if not visible:
		return
	if now != _drawn:
		_drawn = now.duplicate(true)
		_redraw(guide)
	_time += delta
	var t := 0.5 + 0.5 * sin(_time * BREATH)
	_mark_mat.albedo_color.a = lerpf(MARK_ALPHA.x, MARK_ALPHA.y, t)
	_next_mat.albedo_color.a = lerpf(NEXT_ALPHA.x, NEXT_ALPHA.y, t)
	_road_mat.albedo_color.a = lerpf(ROAD_ALPHA.x, ROAD_ALPHA.y, t)
	_arrow.position.y = _ground + HOVER + sin(_time * 2.0) * BOB


func _redraw(guide) -> void:
	var ghosts: Array[Dictionary] = guide.ghosts()
	var step: Dictionary = guide.step()
	while _marks.size() < ghosts.size():
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		m.mesh = plane
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_marks.append(m)
	for i in _marks.size():
		_marks[i].visible = i < ghosts.size()
		if i >= ghosts.size():
			continue
		var g: Dictionary = ghosts[i]
		var ground := TerrainView.footprint_ground(city.grid, g["origin"], g["size"])
		var centre := Grid.footprint_center(g["origin"], g["size"])
		_marks[i].position = Vector3(centre.x, ground + 0.2, centre.z)
		_marks[i].scale = Vector3(g["size"].x * Balance.TILE_SIZE * 0.95, 1.0, g["size"].y * Balance.TILE_SIZE * 0.95)
		var next: bool = step.get("origin", Vector2i(-1, -1)) == g["origin"] and step.get("type", "") == g["type"]
		_marks[i].material_override = _next_mat if next else _mark_mat

	var roads: Array[Vector2i] = guide.roads()
	_road.multimesh.instance_count = roads.size()
	for i in roads.size():
		var p := Grid.footprint_center(roads[i], Vector2i.ONE)
		var y := TerrainView.footprint_ground(city.grid, roads[i], Vector2i.ONE) + 0.25
		_road.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, y, p.z)))

	_cut_note.visible = step.get("kind", "") == "connect"
	if _cut_note.visible:
		var c := Grid.footprint_center(step["building_origin"], step["building_size"])
		_cut_note.position = Vector3(c.x, TerrainView.footprint_ground(city.grid, step["building_origin"], step["building_size"]) + 10.0, c.z)

	var spot: Dictionary = guide.spot()
	_shown = spot.duplicate()
	_arrow.visible = not spot.is_empty()
	_note.visible = _arrow.visible
	if spot.is_empty():
		return
	var origin: Vector2i = spot["origin"]
	var size: Vector2i = spot["size"]
	var centre := Grid.footprint_center(origin, size)
	_ground = TerrainView.footprint_ground(city.grid, origin, size)
	_arrow.position = Vector3(centre.x, _ground + HOVER, centre.z)
	_note.position = Vector3(centre.x, _ground + HOVER + 8.0, centre.z)
	match step.get("kind", ""):
		"connect":
			_note.text = tr("UI_GUIDE_CONNECT") % tr(Buildings.get_building(step["building"])["name_key"])
		"road":
			_note.text = tr("UI_GUIDE_ROAD")
		_:
			_note.text = tr("UI_GUIDE_HERE") % tr(Buildings.get_building(spot["type"])["name_key"])


## Where the camera should look to see the arrow (Vector3.INF when there is none).
func target() -> Vector3:
	if not visible or _shown.is_empty():
		return Vector3.INF
	return Grid.footprint_center(_shown["origin"], _shown["size"])
