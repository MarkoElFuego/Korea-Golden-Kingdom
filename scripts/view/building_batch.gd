extends Node3D
## Draws every building of one kind together. Each kind (building type, and tier for
## houses) is "baked" once: all parts of its model are merged into one mesh with one
## surface per material. One MultiMesh per kind then draws all of its buildings, so the
## graphics card gets one call per kind and material, not one per part of every building.
## Works the same for placeholders and the owner's .glb models (docs/art-bible.md).
## Only draws; city_view.gd tells it what stands where.

const Factory = preload("res://scripts/view/placeholder_factory.gd")

var _kinds := {} # model key -> {"node": MultiMeshInstance3D, "members": {id: Transform3D}, "dirty": bool}
var _key_of := {} # building id -> model key
var _transparency := 0.0


static func key(type: String, tier: int) -> String:
	return "%s_%d" % [type, tier]


## Shows a building. A building already shown moves to its new kind and place.
func add(id: int, type: String, tier: int, xform: Transform3D) -> void:
	remove(id)
	var k := key(type, tier)
	if not _kinds.has(k):
		_kinds[k] = _new_kind(k, type, tier)
	_kinds[k]["members"][id] = xform
	_kinds[k]["dirty"] = true
	_key_of[id] = k


func remove(id: int) -> void:
	if not _key_of.has(id):
		return
	var kind: Dictionary = _kinds[_key_of[id]]
	kind["members"].erase(id)
	kind["dirty"] = true
	_key_of.erase(id)


func has(id: int) -> bool:
	return _key_of.has(id)


func kind_of(id: int) -> String:
	return _key_of.get(id, "")


func transform_of(id: int) -> Transform3D:
	return _kinds[_key_of[id]]["members"][id]


## How many buildings are drawn (all kinds, or one kind).
func count(kind := "") -> int:
	if kind != "":
		return _kinds[kind]["members"].size() if _kinds.has(kind) else 0
	return _key_of.size()


## Draw calls per frame for buildings (before shadows): one per kind in use and material.
func draw_calls() -> int:
	var n := 0
	for kind: Dictionary in _kinds.values():
		if not kind["members"].is_empty():
			n += (kind["node"] as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
	return n


func set_transparency(value: float) -> void:
	_transparency = value
	for kind: Dictionary in _kinds.values():
		kind["node"].transparency = value


func _process(_delta: float) -> void:
	flush()


## Sends changed kinds to the graphics card (once per frame at most).
func flush() -> void:
	for kind: Dictionary in _kinds.values():
		if not kind["dirty"]:
			continue
		kind["dirty"] = false
		var mm: MultiMesh = kind["node"].multimesh
		var members: Dictionary = kind["members"]
		mm.instance_count = members.size()
		var i := 0
		for xform: Transform3D in members.values():
			mm.set_instance_transform(i, xform)
			i += 1


func _new_kind(k: String, type: String, tier: int) -> Dictionary:
	var model := Factory.building(type, tier)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bake(model)
	model.free()
	var node := MultiMeshInstance3D.new()
	node.name = k
	node.multimesh = mm
	node.transparency = _transparency
	add_child(node)
	return {"node": node, "members": {}, "dirty": false}


## Merges every mesh under `root` into one mesh, one surface per material.
static func bake(root: Node3D) -> ArrayMesh:
	var tools := {} # material (or null) -> SurfaceTool
	_collect(root, Transform3D.IDENTITY, tools)
	var mesh := ArrayMesh.new()
	for material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


static func _collect(node: Node, xform: Transform3D, tools: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var material: Material = mi.material_override
			if material == null:
				material = mi.get_surface_override_material(s)
			if material == null:
				material = mi.mesh.surface_get_material(s)
			if not tools.has(material):
				tools[material] = SurfaceTool.new()
			(tools[material] as SurfaceTool).append_from(mi.mesh, s, xform)
	for child in node.get_children():
		if child is Node3D:
			_collect(child, xform * (child as Node3D).transform, tools)
