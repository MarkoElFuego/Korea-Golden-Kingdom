extends PanelContainer
## Goods window (F4 or the top bar button): for every good, how much the storages hold,
## how much is on the way, how much was made this year, how many buildings make it and
## how many of them stand still, with one line on why (city.supply.report()).
## Only reads the city.

const Goods = preload("res://scripts/data/goods.gd")
const InfoPanel = preload("res://scripts/view/info_panel.gd")

const PAPER := Color("#ece6d8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")
const ACCENT := Color("#b8473a")
const REFRESH := 1.0 # seconds
const COLUMNS := [190, 80, 80, 100, 80, 150] # good, stored, carried, this year, stolen, makers

var city # scripts/sim/city.gd
var _rows: VBoxContainer
var _wait := 0.0


func _ready() -> void:
	visible = false
	# Top left corner, under the top bar (the building window is on the right).
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 20
	offset_top = 72
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
	var title := _label(tr("UI_GOODS_TITLE"), 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = tr("UI_PANEL_CLOSE_TIP")
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", INK)
	close.pressed.connect(toggle)
	header.add_child(close)
	var names := ["UI_GOODS_COL_GOOD", "UI_GOODS_COL_STORED", "UI_GOODS_COL_CARRIED", "UI_GOODS_COL_YEAR", "UI_GOODS_COL_STOLEN", "UI_GOODS_COL_MAKERS"]
	var heads := HBoxContainer.new()
	for i in names.size():
		var l := _label(tr(names[i]), 16)
		l.custom_minimum_size.x = COLUMNS[i]
		l.modulate = Color(1, 1, 1, 0.75)
		heads.add_child(l)
	box.add_child(heads)
	box.add_child(HSeparator.new())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait <= 0.0:
		refresh()


func refresh() -> void:
	_wait = REFRESH
	for child in _rows.get_children():
		child.queue_free()
	for row: Dictionary in city.supply.report():
		var line := HBoxContainer.new()
		var good: String = row["good"]
		var name_box := HBoxContainer.new()
		name_box.custom_minimum_size.x = COLUMNS[0]
		var swatch := ColorRect.new()
		swatch.color = Color(Goods.GOODS[good]["color"])
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_box.add_child(swatch)
		name_box.add_child(_label(" " + tr(Goods.GOODS[good]["name_key"]), 18))
		line.add_child(name_box)
		var cells := [str(row["stored"]), str(row["moving"]), str(row["year"]), str(row["stolen"]) if row["stolen"] > 0 else "—", _makers(row)]
		for i in cells.size():
			var cell := _label(cells[i], 18)
			cell.custom_minimum_size.x = COLUMNS[i + 1]
			if (i == 4 and row["idle"] > 0) or (i == 3 and row["stolen"] > 0):
				cell.add_theme_color_override("font_color", ACCENT)
			line.add_child(cell)
		_rows.add_child(line)
		if not row["note"].is_empty():
			var note := _label("    " + InfoPanel.status_text(self, row["note"]), 15)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 600
			note.add_theme_color_override("font_color", ACCENT if row["idle"] > 0 else INK)
			_rows.add_child(note)


func _makers(row: Dictionary) -> String:
	if row["makers"] == 0:
		return "—"
	if row["idle"] > 0:
		return tr("UI_GOODS_MAKERS_IDLE") % [row["idle"], row["makers"]]
	return tr("UI_GOODS_MAKERS") % row["makers"]


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", font_size)
	return l
