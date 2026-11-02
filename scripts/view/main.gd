extends Node3D
## Main game scene: generates the city, draws terrain, buildings, roads and walkers, camera,
## top bar, build menu and building window, and runs the simulation clock.

const Balance = preload("res://scripts/data/balance.gd")
const City = preload("res://scripts/sim/city.gd")
const CameraRig = preload("res://scripts/view/camera_rig.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")
const CityView = preload("res://scripts/view/city_view.gd")
const BuildTool = preload("res://scripts/view/build_tool.gd")
const BuildMenu = preload("res://scripts/view/build_menu.gd")
const TopBar = preload("res://scripts/view/top_bar.gd")
const InputSetup = preload("res://scripts/view/input_setup.gd")
const TextLoader = preload("res://scripts/view/text_loader.gd")
const SceneSetup = preload("res://scripts/view/scene_setup.gd")
const UiTheme = preload("res://scripts/view/ui_theme.gd")
const WalkerView = preload("res://scripts/view/walker_view.gd")
const InfoPanel = preload("res://scripts/view/info_panel.gd")

var city: City
var camera_rig: CameraRig
var build_tool: BuildTool


func _ready() -> void:
	InputSetup.ensure_actions()
	TextLoader.install()
	city = City.new(Balance.DEFAULT_MAP_SEED)

	SceneSetup.add_environment(self)

	var terrain := TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(city.grid, false)

	var city_view := CityView.new()
	city_view.name = "CityView"
	add_child(city_view)
	city_view.setup(city)

	var walker_view := WalkerView.new()
	walker_view.name = "Walkers"
	add_child(walker_view)
	walker_view.setup(city)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	var size := Vector2(city.grid.width, city.grid.height) * Balance.TILE_SIZE
	camera_rig.set_bounds(Vector2.ZERO, size)
	camera_rig.focus_on(Vector3(size.x * 0.5, 0, size.y * 0.5))

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var ui_root := Control.new()
	ui_root.name = "Root"
	ui_root.theme = UiTheme.make()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ui_root)
	var bar := TopBar.new()
	bar.name = "TopBar"
	ui_root.add_child(bar)
	bar.setup(city)

	build_tool = BuildTool.new()
	build_tool.name = "BuildTool"
	build_tool.city = city
	build_tool.camera = camera_rig.camera
	build_tool.cursor_note = _make_cursor_note()
	ui_root.add_child(build_tool.cursor_note)
	add_child(build_tool)

	var menu := BuildMenu.new()
	menu.name = "BuildMenu"
	ui_root.add_child(menu)
	menu.setup(build_tool)

	var info := InfoPanel.new()
	info.name = "InfoPanel"
	info.city = city
	ui_root.add_child(info)
	build_tool.building_selected.connect(info.show_building)
	build_tool.mode_changed.connect(func(_m: int, _t: String) -> void: info.close_panel())


## Small paper note that follows the cursor while a build tool is active.
func _make_cursor_note() -> Label:
	var note := Label.new()
	note.name = "CursorNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.visible = false
	note.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ece6d8")
	style.border_color = Color("#8a5c35")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	note.add_theme_stylebox_override("normal", style)
	return note


func _process(delta: float) -> void:
	city.advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_pause", false, true):
		city.clock.toggle_pause()
	elif event.is_action_pressed("game_speed_1", false, true):
		city.clock.set_speed(1)
	elif event.is_action_pressed("game_speed_2", false, true):
		city.clock.set_speed(2)
	elif event.is_action_pressed("game_speed_3", false, true):
		city.clock.set_speed(3)
