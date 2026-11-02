extends RefCounted
## Shared look for the interface: hanji paper, wood borders, ink text (CLAUDE.md, rule 9).
## Set once on the UI root; tooltips and labels inherit it.

const PAPER := Color("#ece6d8")
const WOOD := Color("#8a5c35")
const INK := Color("#3a2e22")


static func make() -> Theme:
	var theme := Theme.new()
	var tip := StyleBoxFlat.new()
	tip.bg_color = PAPER
	tip.border_color = WOOD
	tip.set_border_width_all(1)
	tip.set_content_margin_all(10)
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_font_size("font_size", "TooltipLabel", 17)
	theme.set_color("font_color", "Label", INK)
	return theme
