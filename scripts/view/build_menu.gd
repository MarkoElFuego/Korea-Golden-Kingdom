extends PanelContainer
## Build menu along the bottom of the screen: Road, every MVP building grouped by
## category, and Demolish. Each button shows name and cost; hover for details.

const Buildings = preload("res://scripts/data/buildings.gd")
const BuildTool = preload("res://scripts/view/build_tool.gd")

const PAPER := Color("#ece6d8")
const PAPER_DARK := Color("#d3cbb8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")

var tool: BuildTool
var _buttons := {} # "road", "demolish" or building id -> Button


func setup(build_tool: BuildTool) -> void:
	tool = build_tool
	tool.mode_changed.connect(_on_mode_changed)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = WOOD
	style.border_width_top = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 64
	add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)

	var road: Dictionary = Buildings.get_building("road")
	_add_button(row, "road", "%s\n%s" % [tr(road["name_key"]), tr("UI_COST_FORMAT") % road["cost"]],
		tr("UI_ROAD_TOOLTIP"), func() -> void: tool.start_road())
	var last_category := "infrastructure"
	for category in Buildings.CATEGORIES:
		for b in Buildings.MVP_BUILDINGS:
			if b["category"] != category or b["id"] == "road":
				continue
			if category != last_category:
				row.add_child(VSeparator.new())
				last_category = category
			var id: String = b["id"]
			_add_button(row, id, "%s\n%s" % [tr(b["name_key"]), tr("UI_COST_FORMAT") % b["cost"]],
				_tooltip(b), func() -> void: tool.start_build(id))
	row.add_child(VSeparator.new())
	_add_button(row, "demolish", tr("UI_DEMOLISH"), tr("UI_DEMOLISH_TOOLTIP"), func() -> void: tool.start_demolish())


func _tooltip(b: Dictionary) -> String:
	var fp: Vector2i = b["footprint"]
	var text: String = tr("UI_BUILD_TOOLTIP_FORMAT") % [
		tr("CATEGORY_" + String(b["category"]).to_upper()), fp.x, fp.y, b["cost"], b["workers"]]
	if b["korean"] != "":
		text = tr(b["name_key"]) + "\n" + tr("UI_BUILD_TOOLTIP_KOREAN_FORMAT") % b["korean"] + "\n" + text
	else:
		text = tr(b["name_key"]) + "\n" + text
	if b.has("hint_key"):
		text += "\n\n" + tr(b["hint_key"])
	return text


func _add_button(row: HBoxContainer, key: String, text: String, tooltip: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(92, 56)
	b.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_hover_pressed_color", PAPER)
	b.add_theme_stylebox_override("normal", _style(PAPER))
	b.add_theme_stylebox_override("hover", _style(PAPER_DARK))
	b.add_theme_stylebox_override("pressed", _style(ACCENT))
	b.add_theme_stylebox_override("hover_pressed", _style(ACCENT))
	b.pressed.connect(func() -> void:
		if b.button_pressed:
			action.call()
		else:
			tool.cancel())
	row.add_child(b)
	_buttons[key] = b


func _on_mode_changed(mode: int, building_type: String) -> void:
	var active := ""
	match mode:
		BuildTool.Mode.BUILD:
			active = building_type
		BuildTool.Mode.ROAD:
			active = "road"
		BuildTool.Mode.DEMOLISH:
			active = "demolish"
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == active)


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = WOOD
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 6
	s.content_margin_right = 6
	return s
