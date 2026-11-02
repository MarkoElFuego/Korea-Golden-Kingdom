extends Node3D
## Gallery of placeholder models: all 15 MVP buildings on a grass grid, the Common House
## in all three MVP tiers, an English name above each and a person beside each for scale.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")
const CameraRig = preload("res://scripts/view/camera_rig.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")
const InputSetup = preload("res://scripts/view/input_setup.gd")
const TextLoader = preload("res://scripts/view/text_loader.gd")
const SceneSetup = preload("res://scripts/view/scene_setup.gd")

const GRID_SIZE := Vector2i(44, 24)
const ROW_WIDTH := 42 # tiles before starting a new row
const GAP := 4 # tiles between models

var grid: Grid


func _ready() -> void:
	InputSetup.ensure_actions()
	TextLoader.install()
	SceneSetup.add_environment(self)

	grid = Grid.new(GRID_SIZE.x, GRID_SIZE.y)
	var terrain := TerrainView.new()
	terrain.name = "Ground"
	add_child(terrain)
	terrain.build(grid, true)

	var cursor := Vector2i(2, 3)
	var row_depth := 0
	var next_id := 1
	for item in _items():
		var fp: Vector2i = Buildings.get_building(item["id"])["footprint"]
		if cursor.x + fp.x > ROW_WIDTH:
			cursor = Vector2i(2, cursor.y + row_depth + GAP + 1)
			row_depth = 0
		if not grid.occupy(cursor, fp, next_id, grid_land()):
			push_error("Gallery: no room for %s at %s" % [item["id"], cursor])
			continue
		_place(item, cursor, fp)
		next_id += 1
		cursor.x += fp.x + GAP
		row_depth = maxi(row_depth, fp.y)

	var rig := CameraRig.new()
	rig.name = "CameraRig"
	rig.zoom = 100.0
	add_child(rig)
	var size := Vector2(GRID_SIZE) * Balance.TILE_SIZE
	rig.set_bounds(Vector2.ZERO, size)
	rig.focus_on(Vector3(size.x * 0.5, 0, size.y * 0.5))

	_add_hint()


func grid_land() -> Array[int]:
	return Buildings.allowed_terrain("road") # plain ground: any default buildable terrain


## Everything to show: each building once, the house once per tier.
func _items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in Buildings.MVP_BUILDINGS:
		if b.has("tiers"):
			for t in b["tiers"]:
				result.append({"id": b["id"], "tier": t["tier"],
					"title": tr("HOUSE_TIER_FORMAT") % [tr(t["name_key"]), t["tier"]], "korean": b["korean"]})
		else:
			result.append({"id": b["id"], "tier": 1, "title": tr(b["name_key"]), "korean": b["korean"]})
	return result


func _place(item: Dictionary, origin: Vector2i, fp: Vector2i) -> void:
	var center := Grid.footprint_center(origin, fp)
	var model := Factory.building(item["id"], item["tier"])
	model.position = center
	add_child(model)

	var label := Label3D.new()
	label.text = item["title"] if item["korean"] == "" else "%s\n(%s)" % [item["title"], item["korean"]]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.pixel_size = 0.026
	label.outline_size = 18
	label.modulate = Color("#fdf8ec")
	label.outline_modulate = Color("#3a2e22")
	label.position = center + Vector3(0, Factory.height_range(item["id"], item["tier"])["max"] + 2.0, 0)
	add_child(label)

	var human := Factory.human()
	var half := Vector2(fp) * Balance.TILE_SIZE * 0.5
	human.position = center + Vector3(half.x + 0.8, 0, half.y - 0.6)
	add_child(human)


func _add_hint() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ece6d8")
	style.border_color = Color("#8a5c35")
	style.border_width_bottom = 3
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var label := Label.new()
	label.text = "%s  ·  %s" % [tr("UI_GALLERY_TITLE"), tr("UI_GALLERY_HINT")]
	label.add_theme_color_override("font_color", Color("#3a2e22"))
	label.add_theme_font_size_override("font_size", 22)
	panel.add_child(label)
	ui.add_child(panel)
