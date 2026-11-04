extends PanelContainer
## Top bar: date, advisor note, game speed, the Goods window button, population, workers
## and treasury.
## Reads the city; speed buttons call the clock.
## Calm hanji paper and wood look (no glossy buttons).

const Balance = preload("res://scripts/data/balance.gd")

const PAPER := Color("#ece6d8")
const PAPER_DARK := Color("#d3cbb8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a") # dancheong red, only for the active speed

signal goods_requested()

var city # scripts/sim/city.gd
var _date_label: Label
var _treasury_label: Label
var _advice_label: Label
var _population_label: Label
var _workers_label: Label
var _speed_buttons := {} # 0 = pause, 1..3 = speeds


func setup(city_ref) -> void:
	city = city_ref
	city.clock.day_changed.connect(func(_d: int) -> void: refresh())
	city.clock.ticked.connect(func(_t: int) -> void:
		if city.dokkaebi.is_night() or not city.dokkaebi.raids.is_empty():
			_refresh_advice())
	city.population_changed.connect(_refresh_people)
	city.clock.speed_changed.connect(func(_s: int, _p: bool) -> void: _refresh_speed())
	city.treasury_changed.connect(func(_v: int) -> void: _refresh_treasury())
	refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_theme_stylebox_override("panel", _panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	_date_label = _label(tr("UI_TIP_DATE"))
	_date_label.custom_minimum_size.x = 320
	row.add_child(_date_label)

	# Advisor note in the free space; empty when all is well.
	_advice_label = _label("")
	_advice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advice_label.add_theme_color_override("font_color", ACCENT)
	_advice_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_advice_label)

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	row.add_child(speeds)
	_speed_buttons[0] = _speed_button(tr("UI_SPEED_PAUSE"), tr("UI_TIP_PAUSE"), 0)
	speeds.add_child(_speed_buttons[0])
	for s in Balance.SPEEDS:
		_speed_buttons[s] = _speed_button(tr("UI_SPEED_FORMAT") % s, tr("UI_TIP_SPEED_FORMAT") % [s, s], s)
		speeds.add_child(_speed_buttons[s])

	var goods := _button(tr("UI_GOODS_TITLE"), tr("UI_GOODS_TIP"))
	goods.custom_minimum_size.x = 96
	goods.pressed.connect(func() -> void: goods_requested.emit())
	row.add_child(goods)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)

	_population_label = _label(tr("UI_TIP_POPULATION"))
	row.add_child(_population_label)
	_workers_label = _label(tr("UI_TIP_WORKFORCE"))
	row.add_child(_workers_label)
	_treasury_label = _label(tr("UI_TIP_TREASURY"))
	_treasury_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_treasury_label.custom_minimum_size.x = 240
	row.add_child(_treasury_label)


func refresh() -> void:
	_refresh_date()
	_refresh_speed()
	_refresh_treasury()
	_refresh_people()


func _refresh_date() -> void:
	var c = city.clock
	_date_label.text = tr("UI_DATE_FORMAT") % [c.get_day(), tr(c.get_season_key()), c.get_year()]


func _refresh_speed() -> void:
	var c = city.clock
	for key in _speed_buttons:
		var active: bool = c.paused if key == 0 else (not c.paused and c.speed == key)
		var button: Button = _speed_buttons[key]
		button.set_pressed_no_signal(active)


func _refresh_people() -> void:
	_population_label.text = tr("UI_POPULATION_FORMAT") % _thousands(city.population())
	_workers_label.text = tr("UI_WORKFORCE_FORMAT") % [city.labor.workforce, city.labor.needed]
	_refresh_advice()


## The advisor's line: the valley entrance first, then dokkaebi warnings and news.
func _refresh_advice() -> void:
	if not city.settlers.entrance_connected:
		_advice_label.text = tr("ADVICE_CONNECT_ENTRANCE")
		return
	var advice: Dictionary = city.dokkaebi.advice()
	if advice.is_empty():
		_advice_label.text = ""
		return
	var args := []
	for a in advice["args"]:
		args.append(tr(a) if a is String else a)
	_advice_label.text = tr(advice["key"]) % args if not args.is_empty() else tr(advice["key"])


func _refresh_treasury() -> void:
	_treasury_label.text = tr("UI_TREASURY_FORMAT") % _thousands(city.treasury)


func _on_speed_pressed(value: int) -> void:
	if value == 0:
		city.clock.toggle_pause()
	else:
		city.clock.set_speed(value)
	_refresh_speed()


# --- Look ---

func _label(tooltip: String) -> Label:
	var l := Label.new()
	l.tooltip_text = tooltip
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", 22)
	return l


func _speed_button(text: String, tooltip: String, value: int) -> Button:
	var b := _button(text, tooltip)
	b.toggle_mode = true
	b.pressed.connect(_on_speed_pressed.bind(value))
	return b


func _button(text: String, tooltip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 36)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_hover_pressed_color", PAPER)
	b.add_theme_stylebox_override("normal", _button_style(PAPER, WOOD))
	b.add_theme_stylebox_override("hover", _button_style(PAPER_DARK, WOOD))
	b.add_theme_stylebox_override("pressed", _button_style(ACCENT, WOOD))
	b.add_theme_stylebox_override("hover_pressed", _button_style(ACCENT, WOOD))
	return b


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.border_color = WOOD
	s.border_width_bottom = 3
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
