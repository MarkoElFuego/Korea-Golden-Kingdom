extends Node3D
## Draws what stands in the city: building models, goods in their yards, roads (one
## MultiMesh) and a warning sign over buildings without road access.
## Only reads the city and follows its signals.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")

const ROAD_COLOR := "#cbb994"
const ROAD_HEIGHT := 0.12
const WARNING_COLOR := "#b8473a"
const FADED := 0.75 # building transparency while a service overlay is shown

var city # scripts/sim/city.gd
var _models := {} # instance id -> Node3D
var _warnings := {} # instance id -> Label3D
var _roads: MultiMeshInstance3D
var _goods_materials := {} # good -> material
var _faded := false


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
	city.economy.stock_changed.connect(_update_goods)
	city.house_changed.connect(_on_house_changed)
	for instance in city.buildings.all():
		_on_building_added(instance)
	_rebuild_roads()
	_add_entrance_marker()


## A house rose or fell a tier (or a lot got its first settlers): swap the model.
func _on_house_changed(instance: Dictionary) -> void:
	var id: int = instance["id"]
	if not _models.has(id):
		return
	_models[id].queue_free()
	_models.erase(id)
	_on_building_added(instance)


## Granite way-marker with a red cap beside the valley entrance, so the player sees
## where settlers come in.
func _add_entrance_marker() -> void:
	var marker := Node3D.new()
	marker.name = "EntranceMarker"
	var stone := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 2.4, 0.6)
	stone.mesh = box
	stone.position = Vector3(0, 1.2, 0)
	var granite := StandardMaterial3D.new()
	granite.albedo_color = Color("#bdb8ad")
	stone.material_override = granite
	marker.add_child(stone)
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.75, 0.3, 0.75)
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 2.55, 0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(WARNING_COLOR)
	cap.material_override = red
	marker.add_child(cap)
	# North-west corner of the entrance tile, off the walking line.
	marker.position = Grid.tile_to_world(city.entrance) + Vector3(-1.4, 0, -1.4)
	add_child(marker)


func _on_building_added(instance: Dictionary) -> void:
	var model := Factory.building(instance["type"], instance["tier"])
	model.position = Grid.footprint_center(instance["origin"], instance["size"])
	model.rotation.y = instance["rotation"] * PI * 0.5
	add_child(model)
	_models[instance["id"]] = model
	_update_warning(instance)
	_update_goods(instance["id"])
	if _faded:
		_set_transparency(model, FADED)


## Fades every building so overlay columns stand out (and brings them back).
func set_faded(on: bool) -> void:
	_faded = on
	for model: Node3D in _models.values():
		_set_transparency(model, FADED if on else 0.0)


static func _set_transparency(node: Node, value: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = value
	for child in node.get_children():
		_set_transparency(child, value)


## Goods shown in the yard: sacks of rice by the Granary, piles in the Storehouse slots,
## and the small store of a producing building next to its door. Rebuilt when stock changes.
func _update_goods(id: int) -> void:
	if not _models.has(id) or not city.economy.state.has(id):
		return
	var model: Node3D = _models[id]
	var old := model.get_node_or_null("Goods")
	if old:
		model.remove_child(old)
		old.queue_free()
	var instance: Dictionary = city.buildings.get_instance(id)
	var stock: Dictionary = city.economy.state[id]["stock"]
	if stock.is_empty():
		return
	var pile := Node3D.new()
	pile.name = "Goods"
	model.add_child(pile)
	var half := Vector2(Buildings.get_building(instance["type"])["footprint"]) * Balance.TILE_SIZE * 0.5
	match instance["type"]:
		"granary":
			_granary_sacks(pile, stock.get("rice", 0))
		"storehouse":
			_storehouse_slots(pile, stock)
		_:
			var n := 0
			for good: String in stock:
				for k in stock[good]:
					_goods_box(pile, Vector3(0.8, 0.6, 0.8), Vector3(half.x - 1.0 - n * 1.0, 0.3, half.y - 0.8), good)
					n += 1


func _granary_sacks(pile: Node3D, loads: int) -> void:
	# Two rows of eight on each side of the steps, then a second layer.
	var columns: Array[float] = [-5.4, -4.5, -3.6, -2.7, 2.7, 3.6, 4.5, 5.4]
	for n in loads:
		var layer := floori(n / 16.0)
		var row := floori((n % 16) / 8.0)
		var col := n % 8
		_goods_box(pile, Vector3(0.8, 0.55, 0.65), Vector3(columns[col], 0.28 + layer * 0.55, 4.6 + row * 0.8), "rice")


func _storehouse_slots(pile: Node3D, stock: Dictionary) -> void:
	# Eight slots along the front, one good per slot, up to four loads high.
	var slot_size: int = Buildings.get_building("storehouse")["storage"]["slot_size"]
	var goods: Array = stock.keys()
	goods.sort()
	var slot := 0
	for good: String in goods:
		var left: int = stock[good]
		while left > 0 and slot < 8:
			var loads := mini(left, slot_size)
			_goods_box(pile, Vector3(1.1, 0.35 * loads, 1.6), Vector3(-5.25 + slot * 1.5, 0.175 * loads, 4.6), good)
			left -= loads
			slot += 1


func _goods_box(parent: Node3D, size: Vector3, center: Vector3, good: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	if not _goods_materials.has(good):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(Goods.GOODS[good]["color"])
		m.roughness = 1.0
		_goods_materials[good] = m
	mi.material_override = _goods_materials[good]
	parent.add_child(mi)


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
