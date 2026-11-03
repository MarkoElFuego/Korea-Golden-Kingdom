extends Node3D
## Main game scene: generates the city, draws terrain, buildings, roads and walkers, camera,
## top bar, build menu and building window, and runs the simulation clock.
## Ctrl+S saves, Ctrl+L loads the newest save, and the game autosaves at the start of every
## season. Loading reloads this scene with the loaded city.

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
const OverlayView = preload("res://scripts/view/overlay_view.gd")
const GoodsPanel = preload("res://scripts/view/goods_panel.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")

const OVERLAY_KEYS := {"water": "F1", "food": "F2", "seonangdang": "F3"}
const NOTICE_SECONDS := 3.0

## Set before (re)loading this scene to play a given city (a loaded save, the big city test).
static var pending_city: City = null
static var pending_notice := ""
## Shows frames per second and walker counts (big city test scene).
static var show_fps := false

var city: City
var camera_rig: CameraRig
var build_tool: BuildTool
var overlay: OverlayView
var goods_panel: GoodsPanel
var _overlay_label: Label
var _notice: Label
var _notice_time := 0.0
var _fps_label: Label
var _fps_wait := 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
	TextLoader.install()
	if pending_city != null:
		city = pending_city
		pending_city = null
	else:
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

	overlay = OverlayView.new()
	overlay.name = "Overlay"
	add_child(overlay)
	overlay.setup(city, city_view)

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

	goods_panel = GoodsPanel.new()
	goods_panel.name = "GoodsPanel"
	goods_panel.city = city
	ui_root.add_child(goods_panel)
	bar.goods_requested.connect(goods_panel.toggle)

	_overlay_label = _paper_label("OverlayLabel", 72)
	ui_root.add_child(_overlay_label)
	overlay.changed.connect(_on_overlay_changed)
	_notice = _paper_label("Notice", 128)
	ui_root.add_child(_notice)
	if show_fps:
		_fps_label = _paper_label("Fps", 72)
		_fps_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_fps_label.grow_horizontal = Control.GROW_DIRECTION_END
		_fps_label.offset_left = 20
		_fps_label.visible = true
		ui_root.add_child(_fps_label)

	city.clock.season_changed.connect(func(_s: int) -> void: _autosave())
	if pending_notice != "":
		notice(pending_notice)
		pending_notice = ""


## Paper label under the top bar (overlay name, notices).
func _paper_label(label_name: String, top: float) -> Label:
	var label := Label.new()
	label.name = label_name
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#3a2e22"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ece6d8")
	style.border_color = Color("#8a5c35")
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_content_margin_all(10)
	label.add_theme_stylebox_override("normal", style)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = top
	return label


## A short message under the top bar that goes away by itself.
func notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_time = NOTICE_SECONDS


func _save() -> void:
	var error := SaveGame.write(city)
	notice(tr("SAVE_DONE") if error == "" else tr(error))


func _autosave() -> void:
	var error := SaveGame.autosave(city)
	notice(tr("AUTOSAVE_DONE") if error == "" else tr(error))


func _load() -> void:
	var path := SaveGame.latest()
	if path == "":
		notice(tr(SaveGame.ERR_NO_SAVE))
		return
	var result := SaveGame.read(path)
	if result["error"] != "":
		notice(tr(result["error"]))
		return
	var loaded: City = result["city"]
	pending_city = loaded
	pending_notice = tr("LOAD_DONE") % [tr(loaded.clock.get_season_key()), loaded.clock.get_year()]
	get_tree().reload_current_scene()


func _on_overlay_changed(mode: String) -> void:
	_overlay_label.visible = mode != ""
	if mode != "":
		_overlay_label.text = tr("UI_OVERLAY_FORMAT") % [tr("OVERLAY_" + mode.to_upper()), OVERLAY_KEYS[mode]]


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
	if _notice_time > 0.0:
		_notice_time -= delta
		_notice.visible = _notice_time > 0.0
	if _fps_label:
		_fps_wait -= delta
		if _fps_wait <= 0.0:
			_fps_wait = 0.5
			var walkers: int = city.carriers.count() + city.settlers.count() + city.services.count()
			var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_fps_label.text = tr("UI_FPS_FORMAT") % [Engine.get_frames_per_second(), calls, city.population(), walkers]
			print(_fps_label.text) # readable in the console when measuring


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_save", false, true):
		_save()
	elif event.is_action_pressed("game_load", false, true):
		_load()
	elif event.is_action_pressed("game_pause", false, true):
		city.clock.toggle_pause()
	elif event.is_action_pressed("game_speed_1", false, true):
		city.clock.set_speed(1)
	elif event.is_action_pressed("game_speed_2", false, true):
		city.clock.set_speed(2)
	elif event.is_action_pressed("game_speed_3", false, true):
		city.clock.set_speed(3)
	elif event.is_action_pressed("goods_window", false, true):
		goods_panel.toggle()
	else:
		for mode: String in OVERLAY_KEYS:
			if event.is_action_pressed("overlay_" + mode, false, true):
				overlay.toggle(mode)
				get_viewport().set_input_as_handled()
