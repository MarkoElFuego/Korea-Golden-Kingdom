extends RefCounted
## Goods (docs/koncept.md, "Roba i proizvodni lanci"). Phase 3 has the three raw goods;
## the rest arrive with production (phase 6) and fermentation (phase 7).
##
## kind: which storage takes it: "food" -> Granary, "material" -> Storehouse.
## color: cargo and pile color for placeholder models (Art Bible palette).

const GOODS := {
	"rice": {"name_key": "GOOD_RICE", "kind": "food", "color": "#d8c9a0"}, # hemp sack
	"wood": {"name_key": "GOOD_WOOD", "kind": "material", "color": "#b07a4a"},
	"clay": {"name_key": "GOOD_CLAY", "kind": "material", "color": "#a8643f"},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in GOODS:
		result.append(id)
	return result


static func kind(good: String) -> String:
	return GOODS[good]["kind"]
