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

# --- Walkers (docs/koncept.md, "Šetači") ---
const CARRIER_SPEED := 1.5 # tiles per second at 1x (one load on the jige)
const CARRIER_RETRY_TICKS := 10 # a building with no storage in reach asks again after this long
const WALKER_MAX_ROAD_TILES := 30 # a roaming walker turns back after this many road tiles
const WALKER_SERVICE_RANGE := 2 # tiles from the road a walker serves

# --- People ---
const HUMAN_HEIGHT := 1.7 # meters
const WORKER_SHARE := 0.4 # share of residents who work (common labour pool)
const TAX_PER_RESIDENT := 2 # Silver per resident at the end of every season (MVP, no Tax Office)
const HOUSE_DOWN_DAYS := 10 # days a house may miss a need before it drops a tier
const SETTLER_GROUP := 6 # people one settler walker brings at most
const SETTLER_INTERVAL_TICKS := 20 # a new group leaves the entrance at most this often
const SETTLER_SPEED := 1.5 # tiles per second at 1x

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
