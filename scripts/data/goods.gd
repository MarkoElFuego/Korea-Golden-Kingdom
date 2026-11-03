extends RefCounted
## Goods (docs/koncept.md, "Roba i proizvodni lanci"). Fermented goods arrive in phase 7.
##
## kind: which storage takes it: "food" -> Granary, "material" -> Storehouse,
##   "ingredient" -> only the Jangdokdae (as an input), "fermented" -> made and kept in the
##   Jangdokdae's jars (fermentation.gd), never in a Granary or Storehouse.
## color: cargo and pile color for placeholder models (Art Bible palette).

const GOODS := {
	"rice": {"name_key": "GOOD_RICE", "kind": "food", "color": "#d8c9a0"}, # hemp sack
	"wood": {"name_key": "GOOD_WOOD", "kind": "material", "color": "#b07a4a"},
	"clay": {"name_key": "GOOD_CLAY", "kind": "material", "color": "#a8643f"},
	"soybeans": {"name_key": "GOOD_SOYBEANS", "kind": "ingredient", "color": "#c9a94a"},
	"salt": {"name_key": "GOOD_SALT", "kind": "ingredient", "color": "#f2efe6"},
	"onggi_jars": {"name_key": "GOOD_ONGGI_JARS", "kind": "material", "color": "#6b4a32"}, # dark glazed clay
	"jang": {"name_key": "GOOD_JANG", "kind": "fermented", "color": "#5a3a22"}, # soybean paste
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in GOODS:
		result.append(id)
	return result


static func kind(good: String) -> String:
	return GOODS[good]["kind"]
