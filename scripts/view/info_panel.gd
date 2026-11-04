extends PanelContainer
## Building window: click a building (with no build tool active) to see what it holds
## and, in one sentence, what it is doing or what it is missing; its workers, what each
## of its walkers is doing, and (for Well, Market, Seonangdang) a "Show range" button.
## The chosen building is framed on the map and its walkers marked. Only reads the city.

const Buildings = preload("res://scripts/data/buildings.gd")
const Goods = preload("res://scripts/data/goods.gd")
const Balance = preload("res://scripts/data/balance.gd")
const Houses = preload("res://scripts/sim/houses.gd")

const PAPER := Color("#ece6d8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")

var city # scripts/sim/city.gd
var selection # scripts/view/selection_view.gd: the frame and range on the map
var walker_view # scripts/view/walker_view.gd: marks this building's walkers
var building_id := 0

var _title: Label
var _subtitle: Label
var _stock: Label
var _status: Label
var _workers: Label
var _house: RichTextLabel # residents, flavor line and needs with ✓ / ✗
var _release: Button # Jangdokdae: release Jang when Fresh, or only when Ripe
var _city_workers: Label # the labour pool of the whole city
var _walkers: Label # one line per walker of this building
var _range: Button # Show range / Hide range


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(380, 0)
	# Top right corner, under the top bar.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -400
	offset_right = -20
	offset_top = 72
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = WOOD
	style.set_border_width_all(2)
	style.border_width_top = 6 # wooden lintel
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = _label(24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = tr("UI_PANEL_CLOSE_TIP")
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", INK)
	close.pressed.connect(close_panel)
	header.add_child(close)
	_subtitle = _label(16)
	_subtitle.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_subtitle)
	box.add_child(HSeparator.new())
	_workers = _label(18)
	box.add_child(_workers)
	_city_workers = _label(15)
	_city_workers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_workers.custom_minimum_size.x = 348
	_city_workers.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_city_workers)
	_house = RichTextLabel.new()
	_house.bbcode_enabled = true
	_house.fit_content = true
	_house.scroll_active = false
	_house.custom_minimum_size.x = 348
	_house.add_theme_color_override("default_color", INK)
	_house.add_theme_font_size_override("normal_font_size", 18)
	_house.add_theme_font_size_override("italics_font_size", 17)
	box.add_child(_house)
	_stock = _label(18)
	box.add_child(_stock)
	_status = _label(18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 348
	box.add_child(_status)
	_release = Button.new()
	_release.focus_mode = Control.FOCUS_NONE
	_release.tooltip_text = tr("UI_JANG_RELEASE_TIP")
	_release.add_theme_font_size_override("font_size", 18)
	_release.pressed.connect(func() -> void:
		city.set_ripe_only(building_id, not city.fermentation.ripe_only(building_id)))
	box.add_child(_release)
	_walkers = _label(16)
	_walkers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_walkers.custom_minimum_size.x = 348
	box.add_child(_walkers)
	_range = Button.new()
	_range.focus_mode = Control.FOCUS_NONE
	_range.tooltip_text = tr("UI_SHOW_RANGE_TIP")
	_range.add_theme_font_size_override("font_size", 18)
	_range.pressed.connect(func() -> void:
		if selection:
			selection.set_show_range(not selection.show_range))
	box.add_child(_range)


func show_building(id: int) -> void:
	building_id = id
	visible = id != 0
	if selection:
		selection.select(id)
	if walker_view:
		walker_view.highlight_home = id
	_refresh()


func close_panel() -> void:
	show_building(0)


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("tool_cancel", false, true):
		close_panel()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if building_id == 0:
		return
	var instance: Dictionary = city.buildings.get_instance(building_id)
	if instance.is_empty():
		close_panel() # demolished
		return
	var data := Buildings.get_building(instance["type"])
	var title := tr(data["name_key"])
	if data.has("tiers"):
		title = tr("HOUSE_VACANT_LOT") if instance["tier"] == 0 else tr(data["tiers"][instance["tier"] - 1]["name_key"])
	_title.text = title
	# The Korean term beside the English name: "jangdokdae  ·  Fermentation".
	var korean: String = data["korean"]
	if data.has("tiers") and instance["tier"] > 0:
		korean = data["tiers"][instance["tier"] - 1].get("korean", korean)
	var category := tr("CATEGORY_" + String(data["category"]).to_upper())
	_subtitle.text = category if korean == "" else korean + "  ·  " + category

	var lines: Array[String] = []
	var state: Dictionary = city.economy.state.get(building_id, {})
	var stock: Dictionary = state.get("stock", {})
	var goods: Array = stock.keys()
	goods.sort()
	for good: String in goods:
		lines.append(tr("UI_STOCK_LINE") % [tr(Goods.GOODS[good]["name_key"]), stock[good]])
	var want: int = data["workers"]
	var has: int = city.labor.assigned.get(building_id, 0)
	_workers.visible = want > 0
	_city_workers.visible = want > 0
	if want > 0:
		var speed := roundi(state.get("eff", 0.0) * 100)
		_workers.text = tr("UI_WORKERS_SPEED") % [has, want, speed]
		_workers.add_theme_color_override("font_color", ACCENT if has < want else INK)
		_city_workers.text = tr("UI_WORKERS_CITY") % [city.labor.workforce, city.labor.needed]
		if has < want:
			_city_workers.text += " " + tr("UI_WORKERS_MORE")
	_house.visible = data.has("tiers") and instance["tier"] > 0
	if _house.visible:
		_house.text = _house_text(instance)
	var keeps_goods: bool = data.has("storage") or data.has("produces") or data.has("market") or data.has("fermentation")
	_stock.visible = keeps_goods
	_stock.text = "\n".join(lines) if not lines.is_empty() else tr("UI_STOCK_EMPTY")

	_release.visible = data.has("fermentation")
	if _release.visible:
		_release.text = tr("UI_JANG_RELEASE_RIPE" if city.fermentation.ripe_only(building_id) else "UI_JANG_RELEASE_FRESH")

	var sends_walkers: bool = data.has("produces") or data.has("roamer") or data.has("workshop") \
		or data.has("fermentation")
	_walkers.visible = sends_walkers
	if sends_walkers:
		var walker_lines: Array[String] = []
		for w: Dictionary in city.walkers_of(building_id):
			walker_lines.append("• " + status_text(self, w))
		_walkers.text = "\n".join(walker_lines) if not walker_lines.is_empty() else tr("UI_WALKERS_NONE")
	_range.visible = selection != null and selection.has_range()
	if _range.visible:
		_range.text = tr("UI_HIDE_RANGE" if selection.show_range else "UI_SHOW_RANGE")

	var status: Dictionary = city.status(instance)
	_status.visible = status["key"] != ""
	if _status.visible:
		_status.text = status_text(self, status)
		var trouble: bool = status.get("stopped", false) or status["key"].begins_with("STATUS_NO_") \
			or status["key"] == "WARN_NO_ROAD_ACCESS" or status["key"] == "STATUS_STORAGE_FULL"
		_status.add_theme_color_override("font_color", ACCENT if trouble else INK)


## A status sentence from {"key", "args"}; text arguments (good names) are text keys too.
static func status_text(node: Node, status: Dictionary) -> String:
	var text := node.tr(status["key"])
	if status["args"].is_empty():
		return text
	var args := []
	for a in status["args"]:
		args.append(node.tr(a) if a is String else a)
	return text % args


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	return l


## Residents, the flavor line, and every need for the next tier with ✓ or ✗
## (CLAUDE.md: the house window says exactly what is missing).
func _house_text(instance: Dictionary) -> String:
	var tier: int = instance["tier"]
	var s: Dictionary = city.houses.state[instance["id"]]
	var lines: Array[String] = []
	lines.append(tr("UI_HOUSE_RESIDENTS") % [s["residents"], Houses.capacity(tier)])
	lines.append("[i]%s[/i]" % tr(Houses.tier_data(tier)["flavor_key"]))
	# Needs of its own tier that are missing: the house is about to drop.
	if tier > 1 and s["missing_days"] > 0:
		lines.append("")
		lines.append("[color=%s]%s[/color]" % [ACCENT.to_html(false), tr("UI_HOUSE_KEEP_TIER") % (Balance.HOUSE_DOWN_DAYS - s["missing_days"])])
		for need in Houses.needs_for(tier):
			if not city.houses.is_met(instance, need):
				lines.append(_need_line(instance, need))
	lines.append("")
	lines.append_array(_walker_lines(instance))
	lines.append("")
	if tier >= Houses.max_tier():
		lines.append(tr("UI_HOUSE_TOP_TIER"))
		return "\n".join(lines)
	lines.append(tr("UI_HOUSE_NEXT_TIER") % tr(Houses.tier_data(tier + 1)["name_key"]))
	for need in Houses.needs_for(tier + 1):
		lines.append(_need_line(instance, need))
	return "\n".join(lines)


## The pantry, and which walkers passed and when (red when one never came or long ago).
func _walker_lines(instance: Dictionary) -> Array[String]:
	var id: int = instance["id"]
	var houses = city.houses
	var lines: Array[String] = []
	if houses.state[id]["food"] > 0:
		lines.append(tr("UI_HOUSE_PANTRY") % houses.pantry_days(id))
	else:
		lines.append(_red(tr("UI_HOUSE_PANTRY_EMPTY")))
	if houses.wants_jang(id):
		if houses.state[id]["jang"] > 0:
			lines.append(tr("UI_HOUSE_JANG") % houses.jang_days(id))
		else:
			lines.append(_red(tr("UI_HOUSE_JANG_EMPTY")))
		var jars: int = houses.jars_days(id)
		lines.append(tr("UI_HOUSE_JARS") % jars if jars > 0 else _red(tr("UI_HOUSE_JARS_NONE")))
	lines.append(_passed_line(houses.days_since(id, "market"), "UI_HOUSE_VENDOR"))
	lines.append(_passed_line(houses.days_since(id, "seonangdang"), "UI_HOUSE_KEEPER"))
	return lines


func _passed_line(days: int, key: String) -> String:
	if days < 0:
		return _red(tr(key + "_NEVER"))
	var text := tr(key + "_PASSED") % days
	return _red(text) if days >= Balance.SERVICE_DAYS else text


func _red(text: String) -> String:
	return "[color=%s]%s[/color]" % [ACCENT.to_html(false), text]


func _need_line(instance: Dictionary, need: String) -> String:
	var text := tr("NEED_" + need.to_upper())
	if city.houses.is_met(instance, need):
		return "[color=#55703a]✓[/color] " + text
	return "[color=%s]✗ %s[/color]" % [ACCENT.to_html(false), text]
