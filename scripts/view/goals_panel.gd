extends Control
## The scenario on screen (scripts/sim/objectives.gd); only reads the city.
##   Goals panel  - top left: "Goal 3 of 9", the goal's name, each condition with how far it is
##                  and a tick when done, "?" to hear the advisor again, and (after
##                  Scenario.STUCK_DAYS on one goal) what the Goods report says is missing;
##   Advisor      - a paper note in the middle when a goal begins: what to do and which keys help;
##   Victory      - when the last goal is done: the city in a few numbers, then free play.
## Calm hanji paper and wood; nothing flashes.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Houses = preload("res://scripts/sim/houses.gd")
const Scenario = preload("res://scripts/data/scenario.gd")
const InfoPanel = preload("res://scripts/view/info_panel.gd")

const PAPER := Color("#ece6d8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")
const DONE := Color("#55703a")
const REFRESH := 0.5 # seconds

var city # scripts/sim/city.gd
var _panel: PanelContainer
var _heading: Label
var _title: Label
var _lines: RichTextLabel
var _advisor: PanelContainer
var _advisor_title: Label
var _advisor_text: Label
var _victory: PanelContainer
var _victory_text: Label
var _wait := 0.0


func setup(city_ref) -> void:
	city = city_ref
	visible = city.objectives != null
	if not visible:
		return
	city.goal_changed.connect(refresh)
	refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = _paper(6)
	_panel.position = Vector2(20, 72)
	_panel.custom_minimum_size.x = 360
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_heading = _label(15)
	_heading.modulate = Color(1, 1, 1, 0.75)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_heading)
	var again := Button.new()
	again.text = "?"
	again.flat = true
	again.focus_mode = Control.FOCUS_NONE
	again.tooltip_text = tr("UI_GOAL_ADVICE_TIP")
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_color_override("font_color", INK)
	again.pressed.connect(func() -> void: _show_advisor(true))
	head.add_child(again)
	_title = _label(21)
	box.add_child(_title)
	_lines = RichTextLabel.new()
	_lines.bbcode_enabled = true
	_lines.fit_content = true
	_lines.scroll_active = false
	_lines.custom_minimum_size.x = 340
	_lines.add_theme_color_override("default_color", INK)
	_lines.add_theme_font_size_override("normal_font_size", 17)
	_lines.add_theme_font_size_override("italics_font_size", 16)
	box.add_child(_lines)

	_advisor = _paper(6)
	_advisor.visible = false
	_advisor.custom_minimum_size.x = 560
	_advisor.set_anchors_preset(Control.PRESET_CENTER)
	_advisor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_advisor.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_advisor)
	var abox := VBoxContainer.new()
	abox.add_theme_constant_override("separation", 12)
	_advisor.add_child(abox)
	var who := _label(15)
	who.text = tr("UI_ADVISOR")
	who.modulate = Color(1, 1, 1, 0.75)
	abox.add_child(who)
	_advisor_title = _label(24)
	abox.add_child(_advisor_title)
	_advisor_text = _label(18)
	_advisor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advisor_text.custom_minimum_size.x = 528
	abox.add_child(_advisor_text)
	var ok := _button(tr("UI_ADVISOR_OK"))
	ok.pressed.connect(_close_advisor)
	abox.add_child(ok)

	_victory = _paper(6)
	_victory.visible = false
	_victory.custom_minimum_size.x = 560
	_victory.set_anchors_preset(Control.PRESET_CENTER)
	_victory.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_victory.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_victory)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_victory.add_child(vbox)
	var vtitle := _label(28)
	vtitle.text = tr("UI_VICTORY_TITLE")
	vbox.add_child(vtitle)
	_victory_text = _label(18)
	_victory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_text.custom_minimum_size.x = 528
	vbox.add_child(_victory_text)
	var go_on := _button(tr("UI_VICTORY_CONTINUE"))
	go_on.pressed.connect(func() -> void:
		city.objectives.victory_seen = true
		_victory.visible = false)
	vbox.add_child(go_on)


func _process(delta: float) -> void:
	if city == null or city.objectives == null:
		return
	_wait -= delta
	if _wait <= 0.0:
		refresh()


## Redraws the panel; opens the advisor for a new goal and the victory note once.
func refresh() -> void:
	_wait = REFRESH
	var o = city.objectives
	if o.won():
		_panel.visible = false
		if not o.victory_seen and not _victory.visible:
			_victory_text.text = _victory_summary()
			_victory.visible = true
		return
	var g: Dictionary = o.goal()
	_heading.text = tr("UI_GOAL_NUMBER") % [o.index + 1, Scenario.GOALS.size()]
	_title.text = tr(_key(g, "TITLE"))
	var lines: Array[String] = []
	for p: Dictionary in o.progress():
		lines.append(_condition_line(p))
	var unlocks: Array = g["unlocks"]
	if not unlocks.is_empty():
		var names: Array[String] = []
		for id: String in unlocks:
			names.append(tr(Buildings.get_building(id)["name_key"]))
		lines.append("[i]%s[/i]" % (tr("UI_GOAL_UNLOCKED") % ", ".join(names)))
	var help := stuck_note()
	if not help.is_empty():
		lines.append("[color=%s]%s[/color]" % [ACCENT.to_html(false), tr("UI_GOAL_STUCK") % InfoPanel.status_text(self, help)])
	_lines.text = "\n".join(lines)
	_panel.visible = not _advisor.visible
	if o.advice_seen < o.index and not _advisor.visible:
		_show_advisor(false)


## After Scenario.STUCK_DAYS on one goal: what the Goods report says about the goal's goods
## ({"key", "args"} or {}).
func stuck_note() -> Dictionary:
	var o = city.objectives
	if o.days_on_goal() < Scenario.STUCK_DAYS:
		return {}
	var goods: Array = o.goal()["goods"]
	for row: Dictionary in city.supply.report():
		if goods.has(row["good"]) and not row["note"].is_empty():
			return row["note"]
	return {}


func _condition_line(p: Dictionary) -> String:
	var c: Dictionary = p["condition"]
	var text := ""
	match c["type"]:
		"road_tiles":
			text = tr("COND_ROAD_TILES")
		"population":
			text = tr("COND_POPULATION")
		"buildings":
			text = tr("COND_BUILDINGS") % tr(Buildings.get_building(c["building"])["name_key"])
		"houses_tier":
			text = tr("COND_HOUSES_TIER") % tr(Houses.tier_data(c["tier"])["name_key"])
		"houses_with":
			text = tr("COND_HOUSES_WITH") % tr("NEED_" + String(c["need"]).to_upper())
		"produced":
			text = tr("COND_PRODUCED") % tr(Goods.GOODS[c["good"]]["name_key"])
		"dokkaebi_night":
			text = tr("COND_DOKKAEBI_NIGHT")
	if c["type"] != "dokkaebi_night":
		text += "  %d / %d" % [mini(p["have"], p["need"]), p["need"]]
	if p["done"]:
		return "[color=%s]✓ %s[/color]" % [DONE.to_html(false), text]
	return "○ " + text


func _show_advisor(_again: bool) -> void:
	var o = city.objectives
	if o.won():
		return
	_advisor_title.text = tr(_key(o.goal(), "TITLE"))
	_advisor_text.text = tr(_key(o.goal(), "ADVICE"))
	_advisor.visible = true
	_panel.visible = false


func _close_advisor() -> void:
	city.objectives.advice_seen = city.objectives.index
	_advisor.visible = false
	_panel.visible = true


func _victory_summary() -> String:
	var tiled := 0
	for id: int in city.houses.state:
		if city.buildings.get_instance(id)["tier"] >= Houses.max_tier():
			tiled += 1
	var made := 0
	for good: String in city.economy.produced:
		made += city.economy.produced[good]
	return tr("UI_VICTORY_TEXT") % [city.population(), tiled, made, city.clock.get_year()]


static func _key(g: Dictionary, part: String) -> String:
	return "GOAL_%s_%s" % [String(g["id"]).to_upper(), part]


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(160, 40)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = PAPER if state == "normal" else Color("#d3cbb8")
		s.border_color = WOOD
		s.set_border_width_all(1)
		s.border_width_bottom = 3
		s.set_corner_radius_all(2)
		b.add_theme_stylebox_override(state, s)
	return b


func _paper(lintel: int) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = WOOD
	style.set_border_width_all(2)
	style.border_width_top = lintel # wooden lintel
	style.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", style)
	return p
