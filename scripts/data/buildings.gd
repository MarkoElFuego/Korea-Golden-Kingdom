extends RefCounted
## The 15 MVP buildings (docs/koncept.md, "Zgrade"). Other buildings come later.
##
## footprint: tiles, x = west->east width, y = north->south depth (1 tile = 4 m).
## height_class: see HEIGHT_CLASSES (docs/art-bible.md).
## cost: Silver. workers: from the city labour pool.
## roof: "giwa" (tile roof, prism), "thatch" (straw dome) or "none".
## terrain: allowed terrains for every footprint tile; empty = Terrain.DEFAULT_BUILDABLE.
## korean: Revised Romanization, "" when the concept has no term.

const Terrain = preload("res://scripts/data/terrain.gd")

## Total model height in meters, from ground (y = 0) to the highest point.
const HEIGHT_CLASSES := {
	"flat": {"min": 0.0, "max": 0.5},
	"low": {"min": 3.0, "max": 4.0},
	"medium": {"min": 6.0, "max": 8.0},
	"tall": {"min": 10.0, "max": 14.0},
}

const CATEGORIES: Array[String] = [
	"infrastructure", "housing", "food", "storage", "distribution",
	"religion", "materials", "crafts", "fermentation",
]

const MVP_BUILDINGS: Array[Dictionary] = [
	{"id": "road", "name_key": "BUILDING_ROAD", "korean": "gil", "category": "infrastructure",
		"footprint": Vector2i(1, 1), "height_class": "flat", "cost": 2, "workers": 0, "roof": "none", "terrain": []},
	{"id": "common_house", "name_key": "BUILDING_COMMON_HOUSE", "korean": "minga", "category": "housing",
		"footprint": Vector2i(2, 2), "height_class": "low", "cost": 10, "workers": 0, "roof": "thatch", "terrain": [],
		"tiers": [
			{"tier": 1, "name_key": "HOUSE_CHOGA_HUT", "height_class": "low", "roof": "thatch", "model": "common_tier1"},
			{"tier": 2, "name_key": "HOUSE_CHOGA_HOUSE", "height_class": "low", "roof": "thatch", "model": "common_tier2"},
			{"tier": 3, "name_key": "HOUSE_GIWA_HOUSE", "height_class": "medium", "roof": "giwa", "model": "common_tier3"},
		]},
	{"id": "well", "name_key": "BUILDING_WELL", "korean": "umul", "category": "infrastructure",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 15, "workers": 0, "roof": "giwa", "terrain": []},
	{"id": "rice_paddy", "name_key": "BUILDING_RICE_PADDY", "korean": "non", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.FERTILE_PLAIN]},
	{"id": "granary", "name_key": "BUILDING_GRANARY", "korean": "gogan", "category": "storage",
		"footprint": Vector2i(3, 3), "height_class": "medium", "cost": 60, "workers": 8, "roof": "giwa", "terrain": []},
	{"id": "storehouse", "name_key": "BUILDING_STOREHOUSE", "korean": "changgo", "category": "storage",
		"footprint": Vector2i(3, 3), "height_class": "medium", "cost": 50, "workers": 6, "roof": "giwa", "terrain": []},
	{"id": "market", "name_key": "BUILDING_MARKET", "korean": "sijang", "category": "distribution",
		"footprint": Vector2i(3, 3), "height_class": "low", "cost": 40, "workers": 6, "roof": "thatch", "terrain": []},
	{"id": "seonangdang", "name_key": "BUILDING_SEONANGDANG", "korean": "seonangdang", "category": "religion",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 25, "workers": 2, "roof": "none", "terrain": []},
	{"id": "jangseung", "name_key": "BUILDING_JANGSEUNG", "korean": "jangseung", "category": "infrastructure",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 10, "workers": 0, "roof": "none", "terrain": []},
	{"id": "woodcutter", "name_key": "BUILDING_WOODCUTTER", "korean": "", "category": "materials",
		"footprint": Vector2i(2, 2), "height_class": "low", "cost": 30, "workers": 4, "roof": "thatch", "terrain": []},
	{"id": "clay_pit", "name_key": "BUILDING_CLAY_PIT", "korean": "", "category": "materials",
		"footprint": Vector2i(2, 2), "height_class": "flat", "cost": 30, "workers": 4, "roof": "none",
		"terrain": [Terrain.ROCKY_HILL]},
	{"id": "onggi_kiln", "name_key": "BUILDING_ONGGI_KILN", "korean": "onggi-gama", "category": "crafts",
		"footprint": Vector2i(3, 2), "height_class": "medium", "cost": 50, "workers": 6, "roof": "giwa", "terrain": []},
	{"id": "soybean_field", "name_key": "BUILDING_SOYBEAN_FIELD", "korean": "", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.GRASS, Terrain.FERTILE_PLAIN]},
	{"id": "salt_pans", "name_key": "BUILDING_SALT_PANS", "korean": "yeomjeon", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.SHORE]},
	{"id": "jangdokdae", "name_key": "BUILDING_JANGDOKDAE", "korean": "jangdokdae", "category": "fermentation",
		"footprint": Vector2i(2, 2), "height_class": "low", "cost": 50, "workers": 4, "roof": "none", "terrain": []},
]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for b in MVP_BUILDINGS:
		result.append(b["id"])
	return result


static func get_building(id: String) -> Dictionary:
	for b in MVP_BUILDINGS:
		if b["id"] == id:
			return b
	return {}


## Terrains allowed under this building.
static func allowed_terrain(id: String) -> Array[int]:
	var result: Array[int] = []
	var b := get_building(id)
	if b.is_empty():
		return result
	if b["terrain"].is_empty():
		result.assign(Terrain.DEFAULT_BUILDABLE)
	else:
		result.assign(b["terrain"])
	return result
