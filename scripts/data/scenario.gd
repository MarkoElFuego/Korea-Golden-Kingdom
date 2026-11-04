extends RefCounted
## The MVP scenario, "The Valley of Seorabeol" (phase 10): goals one after another, each with
## the advisor's words, what it unlocks in the build menu, and what has to be true to finish
## it. Not a campaign mission: a test of whether it is fun to watch the city breathe.
##
## A goal's "unlocks" open when the goal begins. Conditions (all must hold, checked once a day):
##   {"type": "road_tiles", "count"}                 road tiles joined to the valley entrance
##   {"type": "population", "count"}                 residents
##   {"type": "buildings", "building", "count"}      buildings of a type (houses: settled ones)
##   {"type": "houses_tier", "tier", "count"}        houses at this tier or higher
##   {"type": "houses_with", "need", "count"}        houses that have this need met now
##   {"type": "produced", "good", "count"}           loads made since the start
##   {"type": "dokkaebi_night"}                      the goal's dokkaebi night has passed
## "event": "dokkaebi" sends the first dokkaebi EVENT_DELAY_DAYS after the goal begins, to the
## storage with the lowest Gi. Random dokkaebi stay away until that goal is done.
## "goods": what the advisor looks at in the Goods report when the player is stuck.
## "build": what the advisor shows how to build (menu buttons glow, an arrow on the map
## points to a good spot), in order, until the city has "count" of each ("road": road tiles
## joined to the entrance).

const START_UNLOCKED: Array[String] = ["road", "common_house", "well"]
const EVENT_DELAY_DAYS := 5 # then the warning comes, and the night DOKKAEBI_WARNING_DAYS later
const STUCK_DAYS := 20 # the advisor offers help after this many days on one goal

const GOALS: Array[Dictionary] = [
	{"id": "road", "unlocks": [], "goods": [], "build": [{"id": "road", "count": 10}],
		"conditions": [{"type": "road_tiles", "count": 10}]},
	{"id": "homes", "unlocks": [], "goods": [], "build": [{"id": "common_house", "count": 6}, {"id": "well", "count": 1}],
		"conditions": [{"type": "buildings", "building": "common_house", "count": 6},
			{"type": "buildings", "building": "well", "count": 1},
			{"type": "population", "count": 30}]},
	{"id": "rice", "unlocks": ["rice_paddy", "granary", "market"], "goods": ["rice"],
		"build": [{"id": "rice_paddy", "count": 2}, {"id": "granary", "count": 1}, {"id": "market", "count": 1}],
		"conditions": [{"type": "buildings", "building": "market", "count": 1},
			{"type": "houses_with", "need": "food", "count": 10}]},
	{"id": "shrine", "unlocks": ["seonangdang", "jangseung"], "goods": ["rice"], "build": [{"id": "seonangdang", "count": 1}],
		"conditions": [{"type": "houses_tier", "tier": 2, "count": 10}]},
	{"id": "clay", "unlocks": ["woodcutter", "clay_pit", "onggi_kiln", "storehouse"], "goods": ["clay", "wood", "onggi_jars"],
		"build": [{"id": "clay_pit", "count": 1}, {"id": "woodcutter", "count": 1}, {"id": "onggi_kiln", "count": 1}, {"id": "storehouse", "count": 1}],
		"conditions": [{"type": "produced", "good": "onggi_jars", "count": 1},
			{"type": "houses_with", "need": "onggi_jars", "count": 1}]},
	{"id": "jang", "unlocks": ["soybean_field", "salt_pans", "jangdokdae"], "goods": ["soybeans", "salt", "jang", "ripe_jang"],
		"build": [{"id": "soybean_field", "count": 1}, {"id": "salt_pans", "count": 1}, {"id": "jangdokdae", "count": 1}],
		"conditions": [{"type": "houses_with", "need": "jang", "count": 5}]},
	{"id": "gi", "unlocks": [], "goods": ["jang", "onggi_jars"], "build": [],
		"conditions": [{"type": "houses_tier", "tier": 3, "count": 5}]},
	{"id": "dokkaebi", "unlocks": [], "goods": [], "event": "dokkaebi", "build": [{"id": "jangseung", "count": 1}],
		"conditions": [{"type": "dokkaebi_night"}]},
	{"id": "breathes", "unlocks": [], "goods": ["rice", "jang", "onggi_jars"], "build": [],
		"conditions": [{"type": "population", "count": 300},
			{"type": "houses_tier", "tier": 3, "count": 10}]},
]
