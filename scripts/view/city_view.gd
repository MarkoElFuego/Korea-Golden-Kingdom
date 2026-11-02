extends Node3D
## Draws what stands in the city: building models, roads (one MultiMesh) and a warning
## sign over buildings without road access. Only reads the city and follows its signals.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")

const ROAD_COLOR := "#cbb994"
const ROAD_HEIGHT := 0.12
const WARNING_COLOR := "#b8473a"

var city # scripts/sim/city.gd
var _models := {} # instance id -> Node3D
var _warnings := {} # instance id -> Label3D
var _roads: MultiMeshInstance3D


func setup(city_ref) -> void:
	city = city_ref
	_roads = MultiMeshInstance3D.new()
	_roads.name = "Roads"
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	_roads.material_override = material
	add_child(_roads)
	city.building_added.connect(_on_building_added)
	city.building_removed.connect(_on_building_removed)
	city.roads_changed.connect(_rebuild_roads)
	for instance in city.buildings.all():
		_on_building_added(instance)
	_rebuild_roads()


func _on_building_added(instance: Dictionary) -> void:
	var model := Factory.building(instance["type"], instance["tier"])
	model.position = Grid.footprint_center(instance["origin"], instance["size"])
	model.rotation.y = instance["rotation"] * PI * 0.5
	add_child(model)
	_models[instance["id"]] = model
	_update_warning(instance)


func _on_building_removed(instance: Dictionary) -> void:
	var id: int = instance["id"]
	if _models.has(id):
		_models[id].queue_free()
		_models.erase(id)
	if _warnings.has(id):
		_warnings[id].queue_free()
		_warnings.erase(id)


func _rebuild_roads() -> void:
	var tiles: Array[Vector2i] = []
	var grid: Grid = city.grid
	for y in grid.height:
		for x in grid.width:
			if grid.is_road(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(Balance.TILE_SIZE, ROAD_HEIGHT, Balance.TILE_SIZE)
	mm.mesh = box
	mm.instance_count = tiles.size()
	var base := Color(ROAD_COLOR)
	for i in tiles.size():
		var center := Grid.tile_to_world(tiles[i]) + Vector3(0, ROAD_HEIGHT * 0.5, 0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, center))
		var shade := 0.97 + 0.06 * float((tiles[i].x * 7 + tiles[i].y * 13) % 5) / 4.0
		mm.set_instance_color(i, Color(base.r * shade, base.g * shade, base.b * shade))
	_roads.multimesh = mm
	for instance in city.buildings.all():
		_update_warning(instance)


## A red "!" floats over a building that no road touches.
func _update_warning(instance: Dictionary) -> void:
	var id: int = instance["id"]
	var needs_warning: bool = instance["type"] != "road" and not city.has_road_access(instance)
	if needs_warning and not _warnings.has(id):
		var marker := Label3D.new()
		marker.text = "!"
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		marker.font_size = 256
		marker.pixel_size = 0.03
		marker.outline_size = 48
		marker.modulate = Color(WARNING_COLOR)
		marker.outline_modulate = Color("#fdf8ec")
		var top: float = Factory.height_range(instance["type"], instance["tier"])["max"]
		marker.position = Grid.footprint_center(instance["origin"], instance["size"]) + Vector3(0, top + 2.5, 0)
		add_child(marker)
		_warnings[id] = marker
	elif not needs_warning and _warnings.has(id):
		_warnings[id].queue_free()
		_warnings.erase(id)
