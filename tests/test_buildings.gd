extends "res://tests/test_base.gd"

const Buildings = preload("res://scripts/data/buildings.gd")
const Terrain = preload("res://scripts/data/terrain.gd")
const TextLoader = preload("res://scripts/view/text_loader.gd")

const MVP_IDS: Array[String] = [
	"road", "common_house", "well", "rice_paddy", "granary", "storehouse", "market",
	"seonangdang", "jangseung", "woodcutter", "clay_pit", "onggi_kiln", "soybean_field",
	"salt_pans", "jangdokdae",
]


func _keys() -> Dictionary:
	return TextLoader.read_csv("res://data/text/en.csv")


func test_exactly_the_15_mvp_buildings() -> void:
	check_eq(Buildings.MVP_BUILDINGS.size(), 15, "15 buildings")
	for id in MVP_IDS:
		check(not Buildings.get_building(id).is_empty(), "%s exists" % id)


func test_every_building_has_all_data() -> void:
	var seen := {}
	for b in Buildings.MVP_BUILDINGS:
		var id: String = b.get("id", "")
		check(id != "" and id == id.to_snake_case(), "id '%s' is snake_case" % id)
		check(not seen.has(id), "%s is unique" % id)
		seen[id] = true
		check(b.get("name_key", "") != "", "%s: name key" % id)
		check(b.get("korean") is String, "%s: korean term field" % id)
		check(Buildings.CATEGORIES.has(b.get("category")), "%s: known category" % id)
		var fp: Vector2i = b.get("footprint", Vector2i.ZERO)
		check(fp.x >= 1 and fp.y >= 1 and fp.x <= 5 and fp.y <= 5, "%s: footprint %s" % [id, fp])
		check(Buildings.HEIGHT_CLASSES.has(b.get("height_class")), "%s: height class" % id)
		check(b.get("cost", -1) > 0, "%s: cost" % id)
		check(b.get("workers", -1) >= 0, "%s: workers" % id)
		check(["giwa", "thatch", "none"].has(b.get("roof")), "%s: roof" % id)
		for t in Buildings.allowed_terrain(id):
			check(t >= 0 and t < Terrain.COUNT, "%s: allowed terrain is valid" % id)


func test_concept_numbers() -> void:
	# Spot checks against the table in docs/koncept.md.
	check_eq(Buildings.get_building("granary")["cost"], 60, "Granary cost")
	check_eq(Buildings.get_building("granary")["workers"], 8, "Granary workers")
	check_eq(Buildings.get_building("onggi_kiln")["footprint"], Vector2i(3, 2), "Onggi Kiln footprint")
	check_eq(Buildings.get_building("road")["cost"], 2, "Road cost")
	check_eq(Buildings.allowed_terrain("rice_paddy"), [Terrain.FERTILE_PLAIN] as Array[int], "Rice Paddy on Fertile Plain")
	check_eq(Buildings.allowed_terrain("salt_pans"), [Terrain.SHORE] as Array[int], "Salt Pans on Shore")


func test_common_house_has_three_tiers() -> void:
	var tiers: Array = Buildings.get_building("common_house")["tiers"]
	check_eq(tiers.size(), 3, "three MVP tiers")
	for i in tiers.size():
		check_eq(tiers[i]["tier"], i + 1, "tier number")
		check_eq(tiers[i]["model"], "common_tier%d" % (i + 1), "model file name")
		check(Buildings.HEIGHT_CLASSES.has(tiers[i]["height_class"]), "tier %d height class" % (i + 1))


func test_every_text_key_has_english_text() -> void:
	var keys := _keys()
	check(keys.size() > 0, "en.csv loaded")
	for b in Buildings.MVP_BUILDINGS:
		check(keys.get(b["name_key"], "") != "", "%s has English text" % b["name_key"])
		for tier in b.get("tiers", []):
			check(keys.get(tier["name_key"], "") != "", "%s has English text" % tier["name_key"])
	for t in Terrain.INFO:
		var key: String = Terrain.INFO[t]["name_key"]
		check(keys.get(key, "") != "", "%s has English text" % key)
	for key in ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_AUTUMN", "SEASON_WINTER", "UI_DATE_FORMAT", "UI_TREASURY_FORMAT"]:
		check(keys.get(key, "") != "", "%s has English text" % key)
