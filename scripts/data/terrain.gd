extends RefCounted
## Terrain types (docs/koncept.md, "Mapa i teren") and where building is allowed.

enum { GRASS, FERTILE_PLAIN, RIVER, SEA, SHORE, FOREST, MOUNTAIN, ROCKY_HILL }

const COUNT := 8

## buildable: ordinary buildings may stand here. Special buildings list their own
## terrains in buildings.gd (Rice Paddy on Fertile Plain, Salt Pans on Shore...).
## color: placeholder color from the Art Bible palette (hex).
const INFO := {
	GRASS: {"id": "grass", "name_key": "TERRAIN_GRASS", "buildable": true, "water": false, "color": "#93a866"},
	FERTILE_PLAIN: {"id": "fertile_plain", "name_key": "TERRAIN_FERTILE_PLAIN", "buildable": true, "water": false, "color": "#7f8a45"},
	RIVER: {"id": "river", "name_key": "TERRAIN_RIVER", "buildable": false, "water": true, "color": "#4f8396"},
	SEA: {"id": "sea", "name_key": "TERRAIN_SEA", "buildable": false, "water": true, "color": "#3b6a82"},
	SHORE: {"id": "shore", "name_key": "TERRAIN_SHORE", "buildable": true, "water": false, "color": "#e2d6bf"},
	FOREST: {"id": "forest", "name_key": "TERRAIN_FOREST", "buildable": false, "water": false, "color": "#55703a"},
	MOUNTAIN: {"id": "mountain", "name_key": "TERRAIN_MOUNTAIN", "buildable": false, "water": false, "color": "#9e998f"},
	ROCKY_HILL: {"id": "rocky_hill", "name_key": "TERRAIN_ROCKY_HILL", "buildable": false, "water": false, "color": "#b5a58a"},
}

## Terrains where ordinary buildings may stand.
const DEFAULT_BUILDABLE: Array[int] = [GRASS, FERTILE_PLAIN, SHORE]


static func is_buildable(terrain: int) -> bool:
	return INFO[terrain]["buildable"]


static func is_water(terrain: int) -> bool:
	return INFO[terrain]["water"]
