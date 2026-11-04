extends PanelContainer
## "Next step": one short sentence just above the build menu saying the one thing to do now
## (scripts/sim/guide.gd step()), following what the player is doing:
##   Road not chosen yet  -> "Click Road in the menu below"
##   Road chosen          -> "Drag the road from the arrow along the gold path"
##   a building to build  -> "Click Common House in the menu below", then "Place it on a gold mark"
##   nothing to build     -> what the goal is waiting for.
## Hanji paper with a gold border that breathes slowly. Only reads the city and the build tool.

const Buildings = preload("res://scripts/data/buildings.gd")
const BuildTool = preload("res://scripts/view/build_tool.gd")
const InfoPanel = preload("res://scripts/view/info_panel.gd")

const PAPER := Color("#ece6d8")
const WOOD := Color("#8a5c35")
const GOLD := Color("#d4a23a")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a") # dancheong red: the advisor found a problem
const BREATH := 3.0
const TEXT_SIZE := 24
const MAX_WIDTH := 1000.0 # pixels; longer advice wraps
const BOTTOM_GAP := 140 # above the build menu and the gold marker over its buttons

var city # scripts/sim/city.gd
var tool: BuildTool
var _head: Label
var _text: Label
var _style: StyleBoxFlat
var _time := 0.0


func setup(city_ref, build_tool: BuildTool) -> void:
	city = city_ref
	tool = build_tool


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -BOTTOM_GAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = PAPER
	_style.border_color = GOLD
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(2)
	_style.content_margin_left = 24
	_style.content_margin_right = 24
	_style.content_margin_top = 8
	_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_head = Label.new()
	_head.text = tr("UI_STEP_NEXT")
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_theme_font_size_override("font_size", 15)
	_head.add_theme_color_override("font_color", Color(INK, 0.7))
	box.add_child(_head)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", TEXT_SIZE)
	_text.add_theme_color_override("font_color", INK)
	box.add_child(_text)
	visible = false


func _process(delta: float) -> void:
	if city == null or city.objectives == null or city.objectives.won():
		visible = false
		return
	var line := text_for(city.objectives, tool.mode, tool.building_type)
	visible = line != ""
	if not visible:
		return
	if _text.text != line:
		_text.text = line
		var wide: float = _text.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		_text.custom_minimum_size.x = minf(wide + 4.0, MAX_WIDTH) # long advice wraps to two lines
		var problem := is_problem(city.objectives.guide.step())
		_head.text = tr("UI_STEP_PROBLEM" if problem else "UI_STEP_NEXT")
		_head.add_theme_color_override("font_color", ACCENT if problem else Color(INK, 0.7))
	reset_size() # fit the sentence (a wrapped label knows its height only after its width)
	position = Vector2((get_parent_area_size().x - size.x) * 0.5, get_parent_area_size().y - BOTTOM_GAP - size.y) # middle, above the menu
	_time += delta
	_style.border_color = WOOD.lerp(GOLD, 0.5 + 0.5 * sin(_time * BREATH))


## The sentence for the guide's step, given the build tool's mode and building.
func text_for(objectives, mode: int, building_type: String) -> String:
	var step: Dictionary = objectives.guide.step()
	var placing: bool = mode == BuildTool.Mode.BUILD and building_type == step.get("type", "")
	if step.get("silver", false) and not placing:
		return tr("STEP_SILVER") % _name(step["type"])
	match step.get("kind", ""):
		"connect":
			var name := _name(step["building"])
			return tr("STEP_CONNECT_DRAG" if mode == BuildTool.Mode.ROAD else "STEP_CONNECT_CLICK") % name
		"road":
			return tr("STEP_ROAD_DRAG" if mode == BuildTool.Mode.ROAD else "STEP_ROAD_CLICK")
		"workers":
			if step["houses"] == 0:
				return tr("STEP_WORKERS_WAIT") % _name(step["building"])
			if placing:
				return tr("STEP_BUILD_PLACE") % _name(step["type"])
			return tr("STEP_WORKERS_HOUSES") % [_name(step["building"]), step["have"], step["need"], step["houses"]]
		"water", "food":
			if placing:
				return tr("STEP_BUILD_PLACE") % _name(step["type"])
			return tr("STEP_WATER" if step["kind"] == "water" else "STEP_FOOD") % step["houses"]
		"rice_far", "rice_more":
			if placing:
				return tr("STEP_BUILD_PLACE") % _name(step["type"])
			if step["kind"] == "rice_far":
				return tr("STEP_RICE_FAR") % [step["hungry"], step["trip_days"]]
			return tr("STEP_RICE_MORE") % [step["hungry"], step["paddies"]]
		"goods":
			return InfoPanel.status_text(self, step["note"])
		"stray":
			if placing:
				return tr("STEP_STRAY_PLACE")
			return tr("STEP_STRAY_MARKET" if step["building"] == "market" else "STEP_STRAY_SHRINE") % step["tiles"]
		"build":
			var name := _name(step["type"])
			if placing:
				return tr("STEP_BUILD_PLACE" if step.has("origin") else "STEP_BUILD_PLACE_ANY") % name
			if step.has("goal_houses"):
				return tr("STEP_GOAL_HOUSES") % [step["goal_houses"], step["have"], step["more"]]
			return tr("STEP_BUILD_CLICK") % name
		"wait":
			return tr("GOAL_%s_STEP" % String(objectives.goal()["id"]).to_upper())
	return ""


## True when the step is a problem the advisor found (not just the goal's next building).
static func is_problem(step: Dictionary) -> bool:
	return step.get("kind", "") in ["connect", "workers", "water", "food", "rice_far", "rice_more", "goods", "stray"] or step.get("silver", false)


func _name(id: String) -> String:
	return tr(Buildings.get_building(id)["name_key"])
