extends "res://tests/test_base.gd"
## Drawing buildings together (building_batch.gd): every building in the city is drawn
## exactly once, in its place and turned the right way, through building, demolishing,
## houses changing tier and loading a save; goods in yards follow the stock.

const Balance = preload("res://scripts/data/balance.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const City = preload("res://scripts/sim/city.gd")
const BigCity = preload("res://scripts/sim/big_city.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const CityView = preload("res://scripts/view/city_view.gd")
const BuildingBatch = preload("res://scripts/view/building_batch.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")


func _city() -> City:
	var c := City.new()
	c.grid = Grid.new(32, 16)
	c.grid.terrain.fill(Terrain.FERTILE_PLAIN)
	c.treasury = 100000
	c.build_road(Vector2i(0, 5), Vector2i(31, 5))
	return c


func _view(c: City) -> CityView:
	var v := CityView.new()
	v.setup(c)
	v.flush()
	return v


func _drawn(v: CityView, kind: String) -> int:
	return v.batch.count(kind)


func test_every_building_drawn_once() -> void:
	var c := _city()
	c.place_building("granary", Vector2i(2, 6))
	c.place_building("well", Vector2i(8, 6))
	c.place_building("common_house", Vector2i(10, 6))
	c.place_building("common_house", Vector2i(12, 6))
	var v := _view(c)
	check_eq(v.batch.count(), c.buildings.all().size(), "drawn = built")
	check_eq(_drawn(v, "common_house_0"), 2, "two empty lots, one kind")
	c.place_building("market", Vector2i(14, 6))
	c.demolish(Vector2i(8, 6), Vector2i(8, 6))
	v.flush()
	check_eq(v.batch.count(), c.buildings.all().size(), "after building and demolishing")
	check_eq(_drawn(v, "well_1"), 0, "the well is gone")
	v.free()


func test_house_moves_to_its_new_tier() -> void:
	var c := _city()
	c.place_building("common_house", Vector2i(10, 6))
	var v := _view(c)
	var house: Dictionary = c.building_at(Vector2i(10, 6))
	house["tier"] = 2
	c.house_changed.emit(house)
	v.flush()
	check_eq(_drawn(v, "common_house_0"), 0, "no longer an empty lot")
	check_eq(_drawn(v, "common_house_2"), 1, "drawn as a Choga House")
	check_eq(v.batch.count(), 1, "still drawn once")
	v.free()


func test_building_stands_in_place_and_turns() -> void:
	var c := _city()
	c.place_building("granary", Vector2i(2, 6), 1)
	var v := _view(c)
	var g: Dictionary = c.building_at(Vector2i(2, 6))
	var xf := v.batch.transform_of(g["id"])
	check(xf.origin.is_equal_approx(Grid.footprint_center(g["origin"], g["size"])), "at the footprint center")
	check(xf.basis.z.is_equal_approx(Vector3.RIGHT), "turned 90 degrees (south side faces east)")
	v.free()


func test_goods_follow_the_stock() -> void:
	var c := _city()
	c.place_building("granary", Vector2i(2, 6))
	var id: int = c.building_at(Vector2i(2, 6))["id"]
	var v := _view(c)
	check_eq(v.goods_boxes("rice"), 0, "empty yard")
	c.economy.add(id, "rice", 12)
	check_eq(v.goods_boxes("rice"), 12, "twelve sacks")
	c.economy.add(id, "rice", -5)
	check_eq(v.goods_boxes("rice"), 7, "seven left")
	c.demolish(Vector2i(2, 6), Vector2i(2, 6))
	check_eq(v.goods_boxes("rice"), 0, "gone with the Granary")
	v.free()


func test_baked_model_keeps_its_shape_with_one_part_per_material() -> void:
	for kind: Array in [["common_house", 2], ["granary", 1], ["market", 1], ["seonangdang", 1]]:
		var model := Factory.building(kind[0], kind[1])
		var materials := {}
		var parts := _parts(model, materials)
		var mesh := BuildingBatch.bake(model)
		var label := "%s tier %d" % kind
		check(parts > materials.size(), "%s: %d parts become %d" % [label, parts, materials.size()])
		check_eq(mesh.get_surface_count(), materials.size(), label + ": one surface per material")
		check(mesh.get_aabb().size.y > 1.0, label + ": has volume")
		model.free()


func _parts(node: Node, materials: Dictionary) -> int:
	var n := 0
	if node is MeshInstance3D:
		n += 1
		materials[(node as MeshInstance3D).material_override] = true
	for child in node.get_children():
		n += _parts(child, materials)
	return n


func test_loaded_city_is_drawn_whole() -> void:
	var c := _city()
	c.place_building("granary", Vector2i(2, 6))
	c.place_building("common_house", Vector2i(10, 6))
	var b: City = SaveGame.city_from_bytes(SaveGame.pack(c))["city"]
	var v := _view(b)
	check_eq(v.batch.count(), b.buildings.all().size(), "all buildings of the loaded city")
	v.free()


func test_big_city_needs_few_draw_calls() -> void:
	var c := BigCity.build()
	var start := Time.get_ticks_msec()
	var v := _view(c)
	var ms := Time.get_ticks_msec() - start
	check_eq(v.batch.count(), c.buildings.all().size(), "%d buildings drawn" % v.batch.count())
	check(v.batch.draw_calls() < 200, "%d draw calls for buildings (was one per part)" % v.batch.draw_calls())
	check(ms < 3000, "view ready in %d ms" % ms)
	v.free()


func test_stopped_producer_gets_a_sign() -> void:
	var c := _city()
	c.labor.extra_workers = 100
	c.place_building("onggi_kiln", Vector2i(2, 6))
	var kiln: int = c.building_at(Vector2i(2, 6))["id"]
	var v := _view(c)
	v.update_stuck()
	check_eq(v.stuck_ids(), [kiln], "a kiln without Clay or Wood gets a sign")
	c.economy.add(kiln, "clay", 2)
	c.economy.add(kiln, "wood", 2)
	v.update_stuck()
	check_eq(v.stuck_ids(), [], "working again: the sign goes")
	v.free()
