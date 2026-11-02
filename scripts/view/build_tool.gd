extends Node3D
## The player's build tools: place a building, drag a road, demolish an area.
## Shows a see-through ghost, colored tiles (green = fits, red = blocked, teal = coverage)
## and a note by the cursor with cost or the reason it cannot be built.
## Rules are decided by the city; this only previews them and sends the command.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")

signal mode_changed(mode: int, building_type: String)

enum Mode { NONE, BUILD, ROAD, DEMOLISH }

const COLOR_OK := Color(0.35, 0.75, 0.35, 0.55)
const COLOR_BAD := Color(0.85, 0.28, 0.22, 0.6)
const COLOR_COVERAGE := Color(0.25, 0.56, 0.48, 0.3)
const OVERLAY_HEIGHT := 0.2 # meters above the ground, over roads
const GHOST_TRANSPARENCY := 0.35

var city # scripts/sim/city.gd
var camera: Camera3D
var cursor_note: Label # in the UI layer; positioned by this tool

var mode := Mode.NONE
var building_type := ""
var rotation_step := 0

var _ghost: Node3D
var _ghost_key := ""
var _overlay: MultiMeshInstance3D
var _drag_start := Vector2i.ZERO
var _dragging := false


func _ready() -> void:
	_overlay = MultiMeshInstance3D.new()
	_overlay.name = "Overlay"
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_overlay.material_override = m
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay)


# --- Modes ---

func start_build(type: String) -> void:
	_set_mode(Mode.BUILD, type)


func start_road() -> void:
	_set_mode(Mode.ROAD, "")


func start_demolish() -> void:
	_set_mode(Mode.DEMOLISH, "")


func cancel() -> void:
	_set_mode(Mode.NONE, "")


func _set_mode(new_mode: Mode, type: String) -> void:
	mode = new_mode
	building_type = type
	_dragging = false
	_clear_preview()
	mode_changed.emit(mode, building_type)


# --- Frame update ---

func _process(_delta: float) -> void:
	if mode == Mode.NONE or _mouse_over_ui():
		_clear_preview()
		return
	var tile: Variant = _mouse_tile()
	if tile == null:
		_clear_preview()
		return
	match mode:
		Mode.BUILD:
			_preview_building(tile)
		Mode.ROAD:
			_preview_road(tile)
		Mode.DEMOLISH:
			_preview_demolish(tile)


func _preview_building(tile: Vector2i) -> void:
	var data := Buildings.get_building(building_type)
	var origin := _origin_for(tile)
	var size := Grid.rotated_size(data["footprint"], rotation_step)
	var reason: String = city.check_building(building_type, origin, rotation_step)

	var key := "%s/%d" % [building_type, rotation_step]
	if key != _ghost_key:
		if _ghost:
			_ghost.queue_free()
		_ghost = Factory.building(building_type, 0 if data.has("tiers") else 1)
		_set_transparency(_ghost, GHOST_TRANSPARENCY)
		add_child(_ghost)
		_ghost_key = key
	_ghost.visible = true
	_ghost.position = Grid.footprint_center(origin, size)
	_ghost.rotation.y = rotation_step * PI * 0.5

	var cells: Array = []
	for t: Vector2i in city.coverage_preview(building_type, origin, rotation_step):
		cells.append([t, COLOR_COVERAGE])
	for dy in size.y:
		for dx in size.x:
			cells.append([origin + Vector2i(dx, dy), COLOR_OK if reason == "" else COLOR_BAD])
	_show_cells(cells)

	var lines: Array[String] = [tr(data["name_key"]), tr("UI_COST_FORMAT") % data["cost"]]
	var bad := reason != ""
	if bad:
		lines.append(tr(reason))
	elif not _has_road_access(origin, size):
		lines.append(tr("WARN_NO_ROAD_ACCESS"))
	lines.append(tr("UI_TOOL_HINT"))
	_show_note("\n".join(lines), bad)


func _preview_road(tile: Vector2i) -> void:
	var start := _drag_start if _dragging else tile
	var plan: Dictionary = city.plan_road(start, tile)
	var cells: Array = []
	for t: Vector2i in plan["tiles"]:
		cells.append([t, COLOR_OK])
	for t: Vector2i in plan["blocked"]:
		cells.append([t, COLOR_BAD])
	_show_cells(cells)
	var bad: bool = plan["cost"] > city.treasury
	var text: String = tr("UI_ROAD_PREVIEW_FORMAT") % [plan["tiles"].size(), plan["cost"]]
	if bad:
		text += "\n" + tr("REASON_NOT_ENOUGH_SILVER")
	_show_note(text, bad)


func _preview_demolish(tile: Vector2i) -> void:
	var start := _drag_start if _dragging else tile
	var plan: Dictionary = city.plan_demolish(start, tile)
	var cells: Array = []
	for y in range(mini(start.y, tile.y), maxi(start.y, tile.y) + 1):
		for x in range(mini(start.x, tile.x), maxi(start.x, tile.x) + 1):
			cells.append([Vector2i(x, y), COLOR_BAD])
	for id: int in plan["buildings"]:
		var instance: Dictionary = city.buildings.get_instance(id)
		for dy in instance["size"].y:
			for dx in instance["size"].x:
				cells.append([instance["origin"] + Vector2i(dx, dy), COLOR_BAD])
	_show_cells(cells)
	_show_note(tr("UI_DEMOLISH_PREVIEW_FORMAT") % (plan["roads"].size() + plan["buildings"].size()), false)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_road", false, true):
		start_road()
	elif event.is_action_pressed("tool_demolish", false, true):
		start_demolish()
	elif mode == Mode.NONE:
		return
	elif event.is_action_pressed("tool_cancel", false, true):
		cancel()
	elif event.is_action_pressed("tool_rotate", false, true) and mode == Mode.BUILD:
		rotation_step = posmod(rotation_step + 1, 4)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		# Wheel and middle button stay with the camera.
		_on_mouse_button(event as InputEventMouseButton)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		cancel()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var tile: Variant = _mouse_tile()
	if tile == null:
		_dragging = false
		return
	match mode:
		Mode.BUILD:
			if mb.pressed:
				city.place_building(building_type, _origin_for(tile), rotation_step)
		Mode.ROAD, Mode.DEMOLISH:
			if mb.pressed:
				_drag_start = tile
				_dragging = true
			elif _dragging:
				_dragging = false
				if mode == Mode.ROAD:
					city.build_road(_drag_start, tile)
				else:
					city.demolish(_drag_start, tile)


# --- Helpers ---

## North-west tile for a building whose footprint is centered under the cursor.
func _origin_for(tile: Vector2i) -> Vector2i:
	var size := Grid.rotated_size(Buildings.get_building(building_type)["footprint"], rotation_step)
	return tile - Vector2i(floori((size.x - 1) / 2.0), floori((size.y - 1) / 2.0))


func _has_road_access(origin: Vector2i, size: Vector2i) -> bool:
	return city.has_road_access({"origin": origin, "size": size})


## Tile under the mouse on the ground plane (y = 0), or null outside the map.
func _mouse_tile() -> Variant:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return null
	var hit := from + dir * (-from.y / dir.y)
	var tile := Grid.world_to_tile(hit)
	return tile if city.grid.in_bounds(tile) else null


func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _show_cells(cells: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * (Balance.TILE_SIZE - 0.2)
	mm.mesh = quad
	mm.instance_count = cells.size()
	for i in cells.size():
		var center := Grid.tile_to_world(cells[i][0]) + Vector3(0, OVERLAY_HEIGHT, 0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, center))
		mm.set_instance_color(i, cells[i][1])
	_overlay.multimesh = mm
	_overlay.visible = true


func _show_note(text: String, bad: bool) -> void:
	if cursor_note == null:
		return
	cursor_note.text = text
	cursor_note.add_theme_color_override("font_color", Color("#b8473a") if bad else Color("#3a2e22"))
	cursor_note.reset_size()
	cursor_note.position = get_viewport().get_mouse_position() + Vector2(24, 24)
	cursor_note.visible = true


func _clear_preview() -> void:
	if _ghost:
		_ghost.visible = false
	_overlay.visible = false
	if cursor_note:
		cursor_note.visible = false


static func _set_transparency(node: Node, value: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = value
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_transparency(child, value)
