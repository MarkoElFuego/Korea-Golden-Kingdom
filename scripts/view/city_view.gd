extends Node3D
## Draws what stands in the city: buildings (one MultiMesh per kind, building_batch.gd),
## goods in their yards (one MultiMesh per good), roads (one MultiMesh), a red "!" over
## buildings without road access and a calm amber sign over producers that stand still,
## with a small box in the color of the good they lack.
## Only reads the city and follows its signals.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")
const BuildingBatch = preload("res://scripts/view/building_batch.gd")

const ROAD_COLOR := "#cbb994"
const ROAD_HEIGHT := 0.12
const WARNING_COLOR := "#b8473a"
const FADED := 0.75 # building transparency while a service overlay is shown
const STUCK_COLOR := "#c98a2b" # amber, quieter than the red "!"
const STUCK_REFRESH := 0.5 # seconds between checks for stopped producers

var city # scripts/sim/city.gd
var batch: BuildingBatch
var _warnings := {} # instance id -> Label3D
var _roads: MultiMeshInstance3D
var _goods := {} # good -> {building id: Array[Transform3D]}, boxes in yards
var _goods_layers := {} # good -> MultiMeshInstance3D
var _goods_dirty := {} # goods whose boxes changed since the last frame
var _faded := false
var _stuck := {} # instance id -> [sign Node3D, good it is about]
var _stuck_wait := 0.0


func setup(city_ref) -> void:
	city = city_ref
	batch = BuildingBatch.new()
	batch.name = "Buildings"
	add_child(batch)
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


## A house rose or fell a tier (or a lot got its first settlers): it moves to its new kind.
func _on_house_changed(instance: Dictionary) -> void:
	if batch.has(instance["id"]):
		batch.add(instance["id"], instance["type"], instance["tier"], _xform(instance))


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
	batch.add(instance["id"], instance["type"], instance["tier"], _xform(instance))
	_update_warning(instance)
	_update_goods(instance["id"])


## Where a building stands: footprint center, turned in 90-degree steps.
static func _xform(instance: Dictionary) -> Transform3D:
	var turn := Basis(Vector3.UP, instance["rotation"] * PI * 0.5)
	return Transform3D(turn,Grid.footprint_center(instance["origin"], instance["size"]))


## Fades every building so overlay columns stand out (and brings them back).
func set_faded(on: bool) -> void:
	_faded = on
	batch.set_transparency(FADED if on else 0.0)
	for layer: MultiMeshInstance3D in _goods_layers.values():
		layer.transparency = FADED if on else 0.0


## Goods shown in the yard: sacks of rice by the Granary, piles in the Storehouse slots,
## and the small store of a producing building next to its door. Rebuilt when stock changes.
func _update_goods(id: int) -> void:
	for good: String in _goods:
		if _goods[good].erase(id):
			_goods_dirty[good] = true
	if not batch.has(id) or not city.economy.state.has(id):
		return
	var instance: Dictionary = city.buildings.get_instance(id)
	var stock: Dictionary = city.economy.state[id]["stock"]
	if stock.is_empty():
		return
	var at := _xform(instance)
	var half := Vector2(Buildings.get_building(instance["type"])["footprint"]) * Balance.TILE_SIZE * 0.5
	match instance["type"]:
		"granary":
			_granary_sacks(id, at, stock.get("rice", 0))
		"storehouse":
			_storehouse_slots(id, at, stock)
		_:
			var n := 0
			for good: String in stock:
				for k in stock[good]:
					_goods_box(id, at, Vector3(0.8, 0.6, 0.8), Vector3(half.x - 1.0 - n * 1.0, 0.3, half.y - 0.8), good)
					n += 1


func _granary_sacks(id: int, at: Transform3D, loads: int) -> void:
	# Two rows of eight on each side of the steps, then a second layer.
	var columns: Array[float] = [-5.4, -4.5, -3.6, -2.7, 2.7, 3.6, 4.5, 5.4]
	for n in loads:
		var layer := floori(n / 16.0)
		var row := floori((n % 16) / 8.0)
		var col := n % 8
		_goods_box(id, at, Vector3(0.8, 0.55, 0.65), Vector3(columns[col], 0.28 + layer * 0.55, 4.6 + row * 0.8), "rice")


func _storehouse_slots(id: int, at: Transform3D, stock: Dictionary) -> void:
	# Eight slots along the front, one good per slot, up to four loads high.
	var slot_size: int = Buildings.get_building("storehouse")["storage"]["slot_size"]
	var goods: Array = stock.keys()
	goods.sort()
	var slot := 0
	for good: String in goods:
		var left: int = stock[good]
		while left > 0 and slot < 8:
			var loads := mini(left, slot_size)
			_goods_box(id, at, Vector3(1.1, 0.35 * loads, 1.6), Vector3(-5.25 + slot * 1.5, 0.175 * loads, 4.6), good)
			left -= loads
			slot += 1


## One box of a good in building `id`'s yard; `center` is in the building's own space.
func _goods_box(id: int, at: Transform3D, size: Vector3, center: Vector3, good: String) -> void:
	if not _goods.has(good):
		_goods[good] = {}
	if not _goods[good].has(id):
		_goods[good][id] = []
	_goods[good][id].append(at * Transform3D(Basis.from_scale(size), center))
	_goods_dirty[good] = true


## How many goods boxes stand in yards (for tests).
func goods_boxes(good: String) -> int:
	var n := 0
	for boxes: Array in _goods.get(good, {}).values():
		n += boxes.size()
	return n


func _process(delta: float) -> void:
	flush()
	_stuck_wait -= delta
	if _stuck_wait <= 0.0:
		_stuck_wait = STUCK_REFRESH
		update_stuck()


## Puts a sign over every producer that stands still and takes it off the others.
func update_stuck() -> void:
	var now := {}
	for item: Dictionary in city.supply.stopped():
		now[item["id"]] = item["status"]["good"]
	for id: int in _stuck.keys():
		if not now.has(id) or now[id] != _stuck[id][1]:
			_stuck[id][0].queue_free()
			_stuck.erase(id)
	for id: int in now:
		if not _stuck.has(id):
			_stuck[id] = [_stuck_sign(city.buildings.get_instance(id), now[id]), now[id]]


## Producers with a sign over them (for tests).
func stuck_ids() -> Array:
	return _stuck.keys()


func _stuck_sign(instance: Dictionary, good: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Stuck"
	var top: float = Factory.height_range(instance["type"], instance["tier"])["max"]
	root.position = Grid.footprint_center(instance["origin"], instance["size"]) + Vector3(0, top + 2.5, 0)
	var mark := Label3D.new()
	mark.text = "?"
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.font_size = 200
	mark.pixel_size = 0.03
	mark.outline_size = 40
	mark.modulate = Color(STUCK_COLOR)
	mark.outline_modulate = Color("#fdf8ec")
	root.add_child(mark)
	if good != "":
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 1.1
		box.mesh = mesh
		box.position = Vector3(0, -2.2, 0)
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(Goods.GOODS[good]["color"])
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		box.material_override = m
		root.add_child(box)
	add_child(root)
	return root


## Sends changed goods to the graphics card (once per frame at most).
func flush() -> void:
	batch.flush()
	for good: String in _goods_dirty:
		if not _goods_layers.has(good):
			_goods_layers[good] = _goods_layer(good)
		var mm: MultiMesh = _goods_layers[good].multimesh
		mm.instance_count = goods_boxes(good)
		var i := 0
		for boxes: Array in _goods[good].values():
			for xform: Transform3D in boxes:
				mm.set_instance_transform(i, xform)
				i += 1
	_goods_dirty.clear()


func _goods_layer(good: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new() # 1 m cube, scaled per box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Goods.GOODS[good]["color"])
	m.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.name = "Goods_" + good
	node.multimesh = mm
	node.material_override = m
	node.transparency = FADED if _faded else 0.0
	add_child(node)
	return node


func _on_building_removed(instance: Dictionary) -> void:
	var id: int = instance["id"]
	batch.remove(id)
	_update_goods(id)
	if _warnings.has(id):
		_warnings[id].queue_free()
		_warnings.erase(id)
	if _stuck.has(id):
		_stuck[id][0].queue_free()
		_stuck.erase(id)


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
