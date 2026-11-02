extends RefCounted
## The 15 MVP buildings (docs/koncept.md, "Zgrade"). Other buildings come later.
##
## footprint: tiles, x = west->east width, y = north->south depth (1 tile = 4 m).
## height_class: see HEIGHT_CLASSES (docs/art-bible.md).
## cost: Silver. workers: from the city labour pool.
## roof: "giwa" (tile roof, prism), "thatch" (straw dome) or "none".
## terrain: allowed terrains for every footprint tile; empty = Terrain.DEFAULT_BUILDABLE.
## korean: Revised Romanization, "" when the concept has no term.
## coverage (optional): {"type": "radius", "tiles": n} serves every tile within n tiles;
##   {"type": "walker"} serves along the roads its roaming walker can reach.
## near_terrain (optional): this terrain must lie within "tiles" of the footprint.
## on_road (optional): stands on an existing road tile, which stays a road
##   (Jangseung: turns back roaming walkers, lets destination walkers pass).
## hint_key (optional): one line for the build menu tooltip.
## tiers (houses): residents = people at that tier; needs = what that tier adds (each tier
##   keeps the needs below it, docs/koncept.md "Stanovanje", MVP simplification).
## produces (optional): {"good": id, "days": n} one load every n days into its small store.
##   Phase 3: fixed rate, no workers yet (proposal; phase 6 adds workers and chains).
## produces_later (optional): produces only once fermentation exists (phase 7).
## storage (optional): {"accepts": goods kind, "capacity": loads} or, Storehouse-style,
##   {"accepts": kind, "slots": n, "slot_size": loads}, one good per slot (as in Zeus).

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
			{"tier": 1, "name_key": "HOUSE_CHOGA_HUT", "height_class": "low", "roof": "thatch", "model": "common_tier1",
				"residents": 6, "needs": ["road", "water", "food"], "flavor_key": "FLAVOR_CHOGA_HUT"},
			{"tier": 2, "name_key": "HOUSE_CHOGA_HOUSE", "height_class": "low", "roof": "thatch", "model": "common_tier2",
				"residents": 12, "needs": ["seonangdang"], "flavor_key": "FLAVOR_CHOGA_HOUSE"},
			{"tier": 3, "name_key": "HOUSE_GIWA_HOUSE", "height_class": "medium", "roof": "giwa", "model": "common_tier3",
				"residents": 20, "needs": ["jang", "onggi_jars"], "flavor_key": "FLAVOR_GIWA_HOUSE"},
		]},
	{"id": "well", "name_key": "BUILDING_WELL", "korean": "umul", "category": "infrastructure",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 15, "workers": 0, "roof": "giwa", "terrain": [],
		"coverage": {"type": "radius", "tiles": 3}},
	{"id": "rice_paddy", "name_key": "BUILDING_RICE_PADDY", "korean": "non", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.FERTILE_PLAIN],
		"produces": {"good": "rice", "days": 8}},
	{"id": "granary", "name_key": "BUILDING_GRANARY", "korean": "gogan", "category": "storage",
		"footprint": Vector2i(3, 3), "height_class": "medium", "cost": 60, "workers": 8, "roof": "giwa", "terrain": [],
		"storage": {"accepts": "food", "capacity": 32}},
	{"id": "storehouse", "name_key": "BUILDING_STOREHOUSE", "korean": "changgo", "category": "storage",
		"footprint": Vector2i(3, 3), "height_class": "medium", "cost": 50, "workers": 6, "roof": "giwa", "terrain": [],
		"storage": {"accepts": "material", "slots": 8, "slot_size": 4}},
	{"id": "market", "name_key": "BUILDING_MARKET", "korean": "sijang", "category": "distribution",
		"footprint": Vector2i(3, 3), "height_class": "low", "cost": 40, "workers": 6, "roof": "thatch", "terrain": [],
		"coverage": {"type": "walker"}},
	{"id": "seonangdang", "name_key": "BUILDING_SEONANGDANG", "korean": "seonangdang", "category": "religion",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 25, "workers": 2, "roof": "none", "terrain": [],
		"coverage": {"type": "walker"}},
	{"id": "jangseung", "name_key": "BUILDING_JANGSEUNG", "korean": "jangseung", "category": "infrastructure",
		"footprint": Vector2i(1, 1), "height_class": "low", "cost": 10, "workers": 0, "roof": "none", "terrain": [],
		"on_road": true, "hint_key": "HINT_JANGSEUNG"},
	{"id": "woodcutter", "name_key": "BUILDING_WOODCUTTER", "korean": "", "category": "materials",
		"footprint": Vector2i(2, 2), "height_class": "low", "cost": 30, "workers": 4, "roof": "thatch", "terrain": [],
		"near_terrain": {"terrain": Terrain.FOREST, "tiles": 2, "reason_key": "REASON_NEEDS_FOREST_NEARBY"},
		"produces": {"good": "wood", "days": 5}},
	{"id": "clay_pit", "name_key": "BUILDING_CLAY_PIT", "korean": "", "category": "materials",
		"footprint": Vector2i(2, 2), "height_class": "flat", "cost": 30, "workers": 4, "roof": "none",
		"terrain": [Terrain.ROCKY_HILL],
		"produces": {"good": "clay", "days": 5}},
	{"id": "onggi_kiln", "name_key": "BUILDING_ONGGI_KILN", "korean": "onggi-gama", "category": "crafts",
		"footprint": Vector2i(3, 2), "height_class": "medium", "cost": 50, "workers": 6, "roof": "giwa", "terrain": []},
	{"id": "soybean_field", "name_key": "BUILDING_SOYBEAN_FIELD", "korean": "", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.GRASS, Terrain.FERTILE_PLAIN],
		"produces_later": true},
	{"id": "salt_pans", "name_key": "BUILDING_SALT_PANS", "korean": "yeomjeon", "category": "food",
		"footprint": Vector2i(3, 3), "height_class": "flat", "cost": 40, "workers": 6, "roof": "none",
		"terrain": [Terrain.SHORE],
		"produces_later": true},
	{"id": "jangdokdae", "name_key": "BUILDING_JANGDOKDAE", "korean": "jangdokdae", "category": "fermentation",
		"footprint": Vector2i(2, 2), "height_class": "low", "cost": 50, "workers": 4, "roof": "none", "terrain": []},
]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for b in MVP_BUILDINGS:
		result.append(b["id"])
	return result


static var _by_id := {}


static func get_building(id: String) -> Dictionary:
	if _by_id.is_empty():
		for b in MVP_BUILDINGS:
			_by_id[b["id"]] = b
	return _by_id.get(id, {})


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


## Text key explaining the terrain rule, for when a footprint lands on the wrong terrain.
static func terrain_reason(id: String) -> String:
	var allowed := allowed_terrain(id)
	if allowed.size() == 1:
		return "REASON_NEEDS_" + String(Terrain.INFO[allowed[0]]["id"]).to_upper()
	return "REASON_BAD_TERRAIN"
