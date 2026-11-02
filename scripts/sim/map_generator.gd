extends RefCounted
## Builds the MVP valley from a seed, following the pungsu ideal (baesan-imsu):
## mountains in the north, a river in the south flowing from the west into the sea
## in the south-east corner (Shore along the sea), forested ridges in the east
## (Blue Dragon) and west (White Tiger), a fertile plain in the middle, a little Rocky Hill.
## Same seed -> same map.

const Terrain = preload("res://scripts/data/terrain.gd")

const SHORE_WIDTH := 4 # tiles of Shore along the sea
const FLOODPLAIN_WIDTH := 2 # tiles of Fertile Plain along the river
const ROCKY_PATCHES := 4 # guaranteed Rocky Hill patches (3x3) at the foot of the mountains


static func generate(map_seed: int, w: int, h: int) -> PackedByteArray:
	return generate_with_entrance(map_seed, w, h)["terrain"]


## The map plus the valley entrance: {"terrain": PackedByteArray, "entrance": Vector2i}.
## Settlers arrive at the entrance, a tile on the west edge where an old road crosses
## the White Tiger ridge (a pass cut through the forest).
static func generate_with_entrance(map_seed: int, w: int, h: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var noise := _make_noise(rng.randi(), 0.09)
	var detail := _make_noise(rng.randi(), 0.2)

	var t := PackedByteArray()
	t.resize(w * h)
	t.fill(Terrain.GRASS)

	_add_fertile_plain(t, w, h, noise)
	_add_ridges(t, w, h, noise)
	var foot := _add_mountains(t, w, h, noise, detail)
	_add_rocky_hills(t, w, h, rng, foot, detail)
	_add_sea(t, w, h, noise)
	_add_river(t, w, h, rng)
	_add_shore(t, w, h)
	var entrance := _add_pass(t, w, h, rng)
	return {"terrain": t, "entrance": entrance}


## Cuts a two-tile-wide pass from the west edge through the forest ridge, north of the
## river and south of the mountains, and returns the entrance tile on the edge.
static func _add_pass(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator) -> Vector2i:
	var row := rng.randi_range(int(h * 0.36), int(h * 0.44))
	for dy in 2:
		for x in w:
			var v := _at(t, w, x, row + dy)
			if v != Terrain.FOREST and v != Terrain.ROCKY_HILL and v != Terrain.MOUNTAIN:
				break
			_put(t, w, x, row + dy, Terrain.GRASS)
	return Vector2i(0, row)


static func _make_noise(noise_seed: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed
	n.frequency = frequency
	return n


static func _put(t: PackedByteArray, w: int, x: int, y: int, value: int) -> void:
	t[y * w + x] = value


static func _at(t: PackedByteArray, w: int, x: int, y: int) -> int:
	return t[y * w + x]


## Myeongdang: an oval of good soil in the middle of the valley.
static func _add_fertile_plain(t: PackedByteArray, w: int, h: int, noise: FastNoiseLite) -> void:
	var cx := w * 0.5
	var cy := h * 0.47
	var rx := w * 0.25
	var ry := h * 0.17
	for y in h:
		for x in w:
			var d := pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) + noise.get_noise_2d(x, y) * 0.35
			if d < 1.0:
				_put(t, w, x, y, Terrain.FERTILE_PLAIN)


## White Tiger (west) and Blue Dragon (east): forest, wide in the north, thin in the south.
static func _add_ridges(t: PackedByteArray, w: int, h: int, noise: FastNoiseLite) -> void:
	for y in h:
		var f := float(y) / float(h - 1)
		var west := roundi(lerpf(8.0, 2.0, f) + noise.get_noise_1d(y * 1.0) * 2.5)
		var east := roundi(lerpf(8.0, 2.0, f) + noise.get_noise_1d(y * 1.0 + 500.0) * 2.5)
		for x in w:
			if x < west or x >= w - east:
				_put(t, w, x, y, Terrain.FOREST)


## Baesan: the guardian mountains along the north edge. Returns the first
## non-mountain row for every column (the foot of the mountains).
static func _add_mountains(t: PackedByteArray, w: int, h: int, noise: FastNoiseLite, detail: FastNoiseLite) -> PackedInt32Array:
	var foot := PackedInt32Array()
	foot.resize(w)
	for x in w:
		# Higher toward the corners, where the ridges meet the mountains.
		var edge := absf(x - w * 0.5) / (w * 0.5)
		var line := roundi(6.0 + edge * 4.0 + noise.get_noise_1d(x * 1.0 + 1000.0) * 2.5 + detail.get_noise_1d(x * 1.0) * 1.0)
		line = clampi(line, 3, floori(h * 0.25))
		foot[x] = line
		for y in line:
			_put(t, w, x, y, Terrain.MOUNTAIN)
	return foot


## A little Rocky Hill at the foot of the mountains: scattered tiles plus a few
## guaranteed 3x3 patches, so a Clay Pit always has room.
static func _add_rocky_hills(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator, foot: PackedInt32Array, detail: FastNoiseLite) -> void:
	for x in w:
		for y in range(foot[x], mini(foot[x] + 3, h)):
			if detail.get_noise_2d(x * 1.0, y * 1.0) > 0.35:
				_put(t, w, x, y, Terrain.ROCKY_HILL)
	for i in ROCKY_PATCHES:
		var px := rng.randi_range(10, w - 13)
		var py := foot[px]
		for dy in 3:
			for dx in 3:
				var x := px + dx
				var y := py + dy
				if x < w and y < h and _at(t, w, x, y) != Terrain.MOUNTAIN:
					_put(t, w, x, y, Terrain.ROCKY_HILL)


## The Eastern Sea fills the south-east corner.
static func _add_sea(t: PackedByteArray, w: int, h: int, noise: FastNoiseLite) -> void:
	var cx := w + 1.0
	var cy := h + 1.0
	var rx := w * 0.32
	var ry := h * 0.27
	for y in h:
		for x in w:
			var d := pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) + noise.get_noise_2d(x + 300.0, y) * 0.15
			if d < 1.0:
				_put(t, w, x, y, Terrain.SEA)


## Imsu: the river enters at the west edge in the south of the valley, meanders east
## and bends down into the sea. It is two tiles wide and always 4-connected.
static func _add_river(t: PackedByteArray, w: int, h: int, rng: RandomNumberGenerator) -> void:
	var start_y := float(rng.randi_range(int(h * 0.62), int(h * 0.70)))
	var end_y := float(h + 4)
	var phase := rng.randf_range(0.0, TAU)
	var river := {} # Vector2i -> true
	var prev_y := -1
	for x in w:
		var f := float(x) / float(w - 1)
		var yc := lerpf(start_y, end_y, pow(f, 1.8)) + sin(x * 0.22 + phase) * 2.0
		var yi := clampi(roundi(yc), 0, h - 2)
		if prev_y == -1:
			prev_y = yi
		var reached_sea := false
		for y in range(mini(prev_y, yi), maxi(prev_y, yi) + 1):
			for dy in 2:
				if _at(t, w, x, y + dy) == Terrain.SEA:
					reached_sea = true
				else:
					river[Vector2i(x, y + dy)] = true
		prev_y = yi
		if reached_sea:
			break
	# Floodplain first, then the water itself.
	for tile: Vector2i in river:
		for dy in range(-FLOODPLAIN_WIDTH, FLOODPLAIN_WIDTH + 1):
			for dx in range(-FLOODPLAIN_WIDTH, FLOODPLAIN_WIDTH + 1):
				var x := tile.x + dx
				var y := tile.y + dy
				if x >= 0 and y >= 0 and x < w and y < h and _at(t, w, x, y) == Terrain.GRASS:
					_put(t, w, x, y, Terrain.FERTILE_PLAIN)
	for tile: Vector2i in river:
		_put(t, w, tile.x, tile.y, Terrain.RIVER)


## Shore: land near the sea (place for Salt Pans).
static func _add_shore(t: PackedByteArray, w: int, h: int) -> void:
	var near_sea := PackedByteArray()
	near_sea.resize(w * h)
	for y in h:
		for x in w:
			if _at(t, w, x, y) != Terrain.SEA:
				continue
			for dy in range(-SHORE_WIDTH, SHORE_WIDTH + 1):
				for dx in range(-SHORE_WIDTH, SHORE_WIDTH + 1):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						near_sea[ny * w + nx] = 1
	for i in t.size():
		if near_sea[i] == 1 and t[i] != Terrain.SEA and t[i] != Terrain.RIVER and t[i] != Terrain.MOUNTAIN:
			t[i] = Terrain.SHORE
