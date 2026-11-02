extends "res://tests/test_base.gd"
## Placeholder models follow docs/art-bible.md: pivot at the footprint center on the
## ground, eaves at most 0.6 m past the footprint, height inside the height class,
## `door` marker on the south edge.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")

const HEIGHT_TOLERANCE := 0.05


func _models() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in Buildings.MVP_BUILDINGS:
		if b.has("tiers"):
			result.append({"id": b["id"], "tier": 0}) # vacant lot
			for t in b["tiers"]:
				result.append({"id": b["id"], "tier": t["tier"]})
		else:
			result.append({"id": b["id"], "tier": 1})
	return result


func _bounds(node: Node3D, parent_xf := Transform3D.IDENTITY) -> AABB:
	var xf := parent_xf * node.transform
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = xf * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		if child is Node3D:
			var child_box := _bounds(child, xf)
			if child_box.size == Vector3.ZERO:
				continue
			box = child_box if first else box.merge(child_box)
			first = false
	return box


func test_models_fit_footprint_and_height_class() -> void:
	for m in _models():
		var id: String = m["id"]
		var model := Factory.building(id, m["tier"])
		var label := "%s tier %d" % [id, m["tier"]]
		var fp: Vector2i = Buildings.get_building(id)["footprint"]
		var half := Vector2(fp.x, fp.y) * Balance.TILE_SIZE * 0.5 + Vector2.ONE * (Balance.MAX_EAVE_OVERHANG + 0.001)
		var box := _bounds(model)
		check(box.position.x >= -half.x and box.end.x <= half.x, "%s: inside footprint east-west (%.2f..%.2f)" % [label, box.position.x, box.end.x])
		check(box.position.z >= -half.y and box.end.z <= half.y, "%s: inside footprint north-south (%.2f..%.2f)" % [label, box.position.z, box.end.z])
		var range := Factory.height_range(id, m["tier"])
		check(box.end.y >= range["min"] - HEIGHT_TOLERANCE and box.end.y <= range["max"] + HEIGHT_TOLERANCE,
			"%s: height %.2f m in class %.1f..%.1f" % [label, box.end.y, range["min"], range["max"]])
		model.free()


func test_door_marker_on_south_edge() -> void:
	for m in _models():
		var id: String = m["id"]
		var model := Factory.building(id, m["tier"])
		var door := model.get_node_or_null("door") as Node3D
		check(door != null, "%s: has a door marker" % id)
		if door:
			var fp: Vector2i = Buildings.get_building(id)["footprint"]
			check_near(door.position.z, fp.y * Balance.TILE_SIZE * 0.5, "%s: door on the south edge" % id)
			check_near(door.position.y, 0.0, "%s: door on the ground" % id)
		model.free()


func test_human_is_1_7_m() -> void:
	var human := Factory.human()
	var box := _bounds(human)
	check_near(box.end.y, Balance.HUMAN_HEIGHT, "human height", 0.01)
	check_near(box.position.y, 0.0, "feet on the ground", 0.01)
	human.free()


func test_model_paths_follow_art_bible() -> void:
	check_eq(Factory.model_path("rice_paddy"), "res://art/buildings/rice_paddy.glb", "building path")
	check_eq(Factory.model_path("common_house", 2), "res://art/houses/common_tier2.glb", "house tier path")
