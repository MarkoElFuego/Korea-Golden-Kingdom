extends RefCounted
## All balance numbers in one place. Values marked "proposal" in docs/koncept.md
## are starting points and change with playtesting.

# --- Map ---
const TILE_SIZE := 4.0 # meters per tile side
const MAP_WIDTH := 64 # tiles, west -> east (+X)
const MAP_HEIGHT := 64 # tiles, north -> south (+Z)
const DEFAULT_MAP_SEED := 20261101

# --- Time ---
const TICKS_PER_SECOND := 10 # at 1x speed
const TICKS_PER_DAY := 10 # 1 day = 1 second at 1x
const DAYS_PER_SEASON := 30
const SEASONS_PER_YEAR := 4
const START_YEAR := 1
const SPEEDS: Array[int] = [1, 2, 3]
const MAX_TICKS_PER_FRAME := 30 # safety cap after a long frame (window drag, load)

# --- Economy ---
const START_TREASURY := 1500 # Silver
const DEMOLISH_REFUND := 0.0 # share of the cost returned on demolish (none, as in Zeus)

# --- Goods ---
const PRODUCER_STORE := 2 # loads a producing building keeps before production stops
const WORKSHOP_INPUT_STORE := 2 # loads of each input a workshop (Onggi Kiln) keeps

# --- Walkers (docs/koncept.md, "Šetači") ---
const CARRIER_SPEED := 1.5 # tiles per second at 1x (one load on the jige)
const CARRIER_RETRY_TICKS := 10 # a building with no storage in reach asks again after this long
const WALKER_AREA_ROAD_TILES := 15 # a Market's or shrine's area: streets this many road tiles from it
const WALKER_ROUND_TILES := 30 # one walker's round covers about this many road tiles of the area
const WALKER_SERVICE_RANGE := 2 # tiles from the road a walker serves
const ROAMER_SPEED := 1.5 # tiles per second at 1x (Market vendor, shrine keeper)
const ROAMER_INTERVAL_DAYS := 5 # a service building sends a roaming walker this often (full staff)
const ROAMER_MAX_OUT := 4 # roaming walkers one building may have out at once
const BUYER_SPEED := 1.5 # tiles per second at 1x
const BUYER_RETRY_TICKS := 10 # a Market that found no rice asks again after this long
const SERVICE_DAYS := 30 # a walker's visit counts this many days (Seonangdang)

# --- People ---
const HUMAN_HEIGHT := 1.7 # meters
const WORKER_SHARE := 0.4 # share of residents who work (common labour pool)
const TAX_PER_RESIDENT := 2 # Silver per resident at the end of every season (MVP, no Tax Office)
const HOUSE_DOWN_DAYS := 10 # days a house may miss a need before it drops a tier
const HOUSE_DOWN_DAYS_HIGH_GI := 20 # ... and in a place of high Gi (good fortune holds)

# Gi, the life force of the land (docs/koncept.md, "Pungsu i Gi"): 0..100 per tile.
const GI_BASE := 40 # every tile
const GI_MOUNTAIN_BONUS := 30 # right below the mountain (baesan), fading over GI_MOUNTAIN_REACH tiles
const GI_MOUNTAIN_REACH := 20
const GI_WATER_BONUS := 15 # next to the river or sea in front (imsu), fading over GI_WATER_REACH tiles
const GI_WATER_REACH := 6
const GI_ENCLOSED_BONUS := 15 # forest ridges both east and west within GI_RIDGE_REACH tiles
const GI_RIDGE_REACH := 30 # the ridges stand at the valley's edges, half a map apart
const GI_RIDGE_ROWS := 8 # a ridge this many rows north or south still counts
const GI_HIGH := 70 # and above: good fortune (a house holds its tier longer)
const GI_LOW := 30 # below: too low for a Tiled House
const GI_MYEONGDANG := 80 # and above: the best places (the protected foot of the mountain), in gold

# --- Dokkaebi (phase 9): night thieves of low-Gi quarters ---
const DOKKAEBI_SAFE_GI := 50 # a storage on Gi this high or higher is never visited
const DOKKAEBI_CHANCE_PER_GI := 0.025 # chance per season for each point of Gi below DOKKAEBI_SAFE_GI
const DOKKAEBI_MAX_CHANCE := 0.75
const DOKKAEBI_POST_TILES := 4 # each Guardian Post this close to a storage halves the chance
const DOKKAEBI_MIN_POPULATION := 50 # a small village is left alone
const DOKKAEBI_FIRST_YEAR := 2 # no dokkaebi in the first year
const DOKKAEBI_WARNING_DAYS := 5 # dokkaebi fires show in the hills this long before they come
const DOKKAEBI_COUNT_MIN := 2
const DOKKAEBI_COUNT_MAX := 3
const DOKKAEBI_LOADS := 2 # loads each dokkaebi carries away
const DOKKAEBI_SPEED := 2.0 # tiles per second at 1x
const DOKKAEBI_SPACING_TICKS := 6 # the second one sets off this much later, and so on
const DOKKAEBI_HILL_REACH := 40 # tiles to look for the hill or forest they come from
const DOKKAEBI_NOTE_DAYS := 30 # the storage window tells of the night this long
const OFFERING_COST := 50 # Silver for buckwheat jelly (memilmuk) at a Village Shrine
const OFFERING_DAYS := 120 # an offering lasts a year
const OFFERING_GIFT := 30 # Silver appeased dokkaebi may leave
const OFFERING_GIFT_CHANCE := 0.5
const SETTLER_GROUP := 6 # people one settler walker brings at most
const SETTLER_INTERVAL_TICKS := 20 # a new group leaves the entrance at most this often
const SETTLER_SPEED := 1.5 # tiles per second at 1x
const FOOD_PORTIONS_PER_LOAD := 320 # one resident eats one portion a day: a load feeds 40 for 8 days
const PANTRY_DAYS := 30 # a full house pantry feeds the house this many days
const JANG_PORTIONS_FRESH := 320 # one resident uses one portion of Jang a day, as with rice
const JANG_PORTIONS_RIPE := 640 # Ripe Jang lasts twice as long: the reward for waiting
const JAR_SETS_PER_LOAD := 4 # a load of Onggi Jars furnishes four houses
const JARS_LAST_DAYS := 360 # a house's set of jars lasts a year
const JARS_RENEW_DAYS := 30 # a vendor brings new jars when the old ones have this little left

# --- Models (docs/art-bible.md) ---
const MAX_EAVE_OVERHANG := 0.6 # meters past the footprint edge

# --- Camera ---
const CAMERA_PITCH_DEG := 35.264 # true isometric
const CAMERA_YAW_DEG := 45.0 # first of four 90-degree steps
const CAMERA_DISTANCE := 400.0 # meters from the focus point (orthographic, so only clipping)
const CAMERA_ZOOM_DEFAULT := 160.0 # visible height in meters
const CAMERA_ZOOM_MIN := 20.0
const CAMERA_ZOOM_MAX := 300.0
const CAMERA_ZOOM_STEP := 1.12 # factor per mouse wheel notch
const CAMERA_PAN_SPEED := 0.9 # screen heights per second
const CAMERA_EDGE_MARGIN := 8 # pixels
const CAMERA_ROTATE_TIME := 0.25 # seconds
