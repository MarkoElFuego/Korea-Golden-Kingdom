extends PanelContainer
## Build menu along the bottom of the screen: Road, every MVP building grouped by
## category, and Demolish. Each button shows name and cost; hover for details.

const Buildings = preload("res://scripts/data/buildings.gd")
const BuildTool = preload("res://scripts/view/build_tool.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Objectives = preload("res://scripts/sim/objectives.gd")
const Scenario = preload("res://scripts/data/scenario.gd")

const PAPER := Color("#ece6d8")
const PAPER_DARK := Color("#d3cbb8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")
const GOLD := Color("#d4a23a")
const GLOW_FILL := Color("#f4d58a") # warm gold the glowing buttons breathe toward
const GLOW_BORDER := 5
const GLOW_SPEED := 4.0 # about one breath in 1.6 seconds
const MARKER_BOB := 10.0 # pixels

var tool: BuildTool
var _buttons := {} # "road", "demolish" or building id -> Button
var _tooltips := {} # building id -> its usual tooltip
var _glowing: Array[String] = [] # buttons the advisor points at (scripts/sim/guide.gd)
var _glow := _style(PAPER) # shared, its border breathes between wood and gold
var _glow_hover := _style(PAPER_DARK)
var _time := 0.0
var _marker: Label # the bobbing gold arrow over the next button


func setup(build_tool: BuildTool) -> void:
	tool = build_tool
	tool.mode_changed.connect(_on_mode_changed)
	tool.city.goal_changed.connect(refresh_locks)
	refresh_locks()


## The scenario keeps some buildings locked until their goal: greyed, with the goal named.
func refresh_locks() -> void:
	for id: String in _tooltips:
		var b: Button = _buttons[id]
		var locked: bool = not tool.city.is_unlocked(id)
		b.disabled = locked
		b.tooltip_text = _tooltips[id]
		if locked:
			var goal := Objectives.unlocked_by(id)
			var goal_name := tr("GOAL_%s_TITLE" % String(Scenario.GOALS[goal]["id"]).to_upper()) if goal >= 0 else ""
			b.tooltip_text = tr("UI_LOCKED_TIP") % [goal + 1, goal_name] + "\n\n" + _tooltips[id]


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
			_tooltips[id] = _tooltip(b)
			_add_button(row, id, "%s\n%s" % [tr(b["name_key"]), tr("UI_COST_FORMAT") % b["cost"]],
				_tooltips[id], func() -> void: tool.start_build(id))
	row.add_child(VSeparator.new())
	_marker = Label.new()
	_marker.text = "▼"
	_marker.top_level = true # placed by hand over a button, not by the menu's rows
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.add_theme_font_size_override("font_size", 34)
	_marker.add_theme_color_override("font_color", GOLD)
	_marker.add_theme_color_override("font_outline_color", INK)
	_marker.add_theme_constant_override("outline_size", 6)
	_marker.visible = false
	add_child(_marker)
	_add_button(row, "demolish", tr("UI_DEMOLISH"), tr("UI_DEMOLISH_TOOLTIP"), func() -> void: tool.start_demolish())


func _tooltip(b: Dictionary) -> String:
	var fp: Vector2i = b["footprint"]
	var text: String = tr("UI_BUILD_TOOLTIP_FORMAT") % [
		tr("CATEGORY_" + String(b["category"]).to_upper()), fp.x, fp.y, b["cost"], b["workers"]]
	if b["korean"] != "":
		text = tr(b["name_key"]) + "\n" + tr("UI_BUILD_TOOLTIP_KOREAN_FORMAT") % b["korean"] + "\n" + text
	else:
		text = tr(b["name_key"]) + "\n" + text
	var makes: String = b.get("produces", {}).get("good", "")
	if makes != "":
		var inputs: Array = b.get("workshop", {}).get("inputs", [])
		if inputs.is_empty():
			text += "\n" + tr("UI_BUILD_TOOLTIP_MAKES") % _good(makes)
		else:
			var names: Array[String] = []
			for good: String in inputs:
				names.append(_good(good))
			text += "\n" + tr("UI_BUILD_TOOLTIP_WORKSHOP") % [" + ".join(names), _good(makes)]
	if b.has("hint_key"):
		text += "\n\n" + tr(b["hint_key"])
	return text


func _good(good: String) -> String:
	return tr(Goods.GOODS[good]["name_key"])


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
	b.add_theme_stylebox_override("disabled", _style(PAPER_DARK))
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))
	b.pressed.connect(func() -> void:
		if b.button_pressed:
			action.call()
		else:
			tool.cancel())
	row.add_child(b)
	_buttons[key] = b


## The advisor's buttons glow: a thick gold border and a warm fill that breathe, and a gold
## marker bobbing over the button of the very next step (calm: no flashing, no colors jumping).
func _process(delta: float) -> void:
	if tool == null or tool.city.objectives == null:
		return
	var guide = tool.city.objectives.guide
	var lit: Array[String] = guide.buttons()
	if lit != _glowing:
		for key: String in _glowing:
			if _buttons.has(key):
				_buttons[key].add_theme_stylebox_override("normal", _style(PAPER))
				_buttons[key].add_theme_stylebox_override("hover", _style(PAPER_DARK))
		_glowing = lit.duplicate()
		for key: String in _glowing:
			if _buttons.has(key):
				_buttons[key].add_theme_stylebox_override("normal", _glow)
				_buttons[key].add_theme_stylebox_override("hover", _glow_hover)
	var next: String = guide.step().get("type", "")
	_marker.visible = _buttons.has(next) and not _buttons[next].button_pressed
	if _glowing.is_empty() and not _marker.visible:
		return
	_time += delta
	var t := 0.5 + 0.5 * sin(_time * GLOW_SPEED)
	_glow.border_color = WOOD.lerp(GOLD, t)
	_glow.bg_color = PAPER.lerp(GLOW_FILL, t)
	_glow_hover.border_color = _glow.border_color
	for s: StyleBoxFlat in [_glow, _glow_hover]:
		s.set_border_width_all(GLOW_BORDER)
	if _marker.visible:
		var b: Button = _buttons[next]
		_marker.size = _marker.get_minimum_size()
		_marker.global_position = b.global_position + Vector2(
			(b.size.x - _marker.size.x) * 0.5, -_marker.size.y - 6.0 - absf(sin(_time * GLOW_SPEED)) * MARKER_BOB)


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
