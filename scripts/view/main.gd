extends Node3D
## Main game scene: generates the city, draws the terrain, camera and top bar,
## and runs the simulation clock.

const Balance = preload("res://scripts/data/balance.gd")
const City = preload("res://scripts/sim/city.gd")
const CameraRig = preload("res://scripts/view/camera_rig.gd")
const TerrainView = preload("res://scripts/view/terrain_view.gd")
const TopBar = preload("res://scripts/view/top_bar.gd")
const InputSetup = preload("res://scripts/view/input_setup.gd")
const TextLoader = preload("res://scripts/view/text_loader.gd")
const SceneSetup = preload("res://scripts/view/scene_setup.gd")

var city: City
var camera_rig: CameraRig


func _ready() -> void:
	InputSetup.ensure_actions()
	TextLoader.install()
	city = City.new(Balance.DEFAULT_MAP_SEED)

	SceneSetup.add_environment(self)

	var terrain := TerrainView.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(city.grid, false)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	var size := Vector2(city.grid.width, city.grid.height) * Balance.TILE_SIZE
	camera_rig.set_bounds(Vector2.ZERO, size)
	camera_rig.focus_on(Vector3(size.x * 0.5, 0, size.y * 0.5))

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var bar := TopBar.new()
	bar.name = "TopBar"
	ui.add_child(bar)
	bar.setup(city)


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
