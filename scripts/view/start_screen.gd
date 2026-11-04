extends Control
## The first screen: New game (the MVP scenario), Continue (the newest save), Demo town, Quit.
## Hanji paper and wood, like the rest of the interface. The real menu and settings come
## after the MVP.

const Main = preload("res://scripts/view/main.gd")
const City = preload("res://scripts/sim/city.gd")
const Balance = preload("res://scripts/data/balance.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const InputSetup = preload("res://scripts/view/input_setup.gd")
const TextLoader = preload("res://scripts/view/text_loader.gd")
const UiTheme = preload("res://scripts/view/ui_theme.gd")

const PAPER := Color("#ece6d8")
const PAPER_DARK := Color("#d3cbb8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")

var _message: Label


func _ready() -> void:
	InputSetup.ensure_actions()
	TextLoader.install()
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = PAPER
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = 420
	center.add_child(box)

	var title := _label(tr("GAME_TITLE"), 44)
	box.add_child(title)
	var sub := _label(tr("UI_START_SUBTITLE"), 20)
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)
	var line := ColorRect.new()
	line.color = ACCENT # a thin dancheong line
	line.custom_minimum_size = Vector2(0, 3)
	box.add_child(line)

	box.add_child(_button(tr("UI_START_NEW"), tr("UI_START_NEW_TIP"), _new_game))
	var cont := _button(tr("UI_START_CONTINUE"), tr("UI_START_CONTINUE_TIP"), _continue)
	cont.disabled = SaveGame.latest() == ""
	box.add_child(cont)
	box.add_child(_button(tr("UI_START_DEMO"), tr("UI_START_DEMO_TIP"), func() -> void:
		get_tree().change_scene_to_file("res://scenes/demo_town.tscn")))
	box.add_child(_button(tr("UI_START_QUIT"), "", func() -> void: get_tree().quit()))
	_message = _label("", 18)
	_message.add_theme_color_override("font_color", ACCENT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)


func _new_game() -> void:
	var city := City.new(Balance.DEFAULT_MAP_SEED)
	city.start_scenario()
	Main.pending_city = city
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue() -> void:
	var path := SaveGame.latest()
	if path == "":
		_message.text = tr(SaveGame.ERR_NO_SAVE)
		return
	var result := SaveGame.read(path)
	if result["error"] != "":
		_message.text = tr(result["error"])
		return
	var loaded: City = result["city"]
	Main.pending_city = loaded
	Main.pending_notice = tr("LOAD_DONE") % [tr(loaded.clock.get_season_key()), loaded.clock.get_year()]
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	return l


func _button(text: String, tooltip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(420, 52)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))
	b.add_theme_stylebox_override("normal", _style(PAPER))
	b.add_theme_stylebox_override("hover", _style(PAPER_DARK))
	b.add_theme_stylebox_override("pressed", _style(PAPER_DARK))
	b.add_theme_stylebox_override("disabled", _style(PAPER))
	b.pressed.connect(action)
	return b


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = WOOD
	s.set_border_width_all(1)
	s.border_width_bottom = 3
	s.set_corner_radius_all(2)
	return s
