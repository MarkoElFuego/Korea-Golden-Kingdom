extends RefCounted
## Builds placeholder models from building data, following docs/art-bible.md:
## real scale in meters, pivot at the footprint center on the ground, entrance and
## `door` marker on the south (+Z) edge, eaves at most 0.6 m past the footprint,
## height inside the building's height class, color by category.
## If the owner's model exists (art/buildings/<id>.glb, art/houses/common_tierN.glb),
## it is loaded instead.

const Balance = preload("res://scripts/data/balance.gd")
const Buildings = preload("res://scripts/data/buildings.gd")

## Art Bible palette.
const C := {
	"giwa": "#5b6470", "giwa_dark": "#454c56",
	"thatch": "#c9a96b", "thatch_dark": "#a88a52",
	"plaster": "#ece6d8", "plaster_dark": "#d3cbb8",
	"wood": "#b07a4a", "wood_dark": "#8a5c35",
	"granite": "#bdb8ad", "granite_dark": "#9e998f",
	"onggi": "#6b3f2a", "onggi_light": "#8c5a40",
	"earth": "#a8643f", "earth_dark": "#7a4a30",
	"leaf": "#6f8f4e", "leaf_dark": "#55703a",
	"ground": "#e2d6bf", "packed_earth": "#cbb994",
	"red": "#b8473a", "turquoise": "#3f8f7a", "ochre": "#d1a24a",
	"water": "#4f8396", "salt": "#f4f1ea", "rice": "#8fb35a", "black": "#2b2420",
}

## Main color per category (Art Bible, "Privremeni modeli").
const CATEGORY_COLOR := {
	"housing": "plaster", "food": "rice", "storage": "wood", "fermentation": "onggi",
	"materials": "earth", "crafts": "earth", "religion": "red", "distribution": "ochre",
	"infrastructure": "granite",
}

static var _materials := {}


# --- Public ---

## A building model: the owner's .glb if it exists, otherwise a placeholder.
## `tier` is used by houses (1..3 in the MVP).
static func building(id: String, tier := 1) -> Node3D:
	var path := model_path(id, tier)
	var node: Node3D = null
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			node = scene.instantiate() as Node3D
	if node == null:
		node = _placeholder(id, tier)
	node.name = id if not Buildings.get_building(id).has("tiers") else "%s_tier%d" % [id, tier]
	return node


static func model_path(id: String, tier := 1) -> String:
	var data := Buildings.get_building(id)
	if data.has("tiers"):
		if tier == 0:
			return "res://art/houses/vacant_lot.glb"
		for t in data["tiers"]:
			if t["tier"] == tier:
				return "res://art/houses/%s.glb" % t["model"]
	return "res://art/buildings/%s.glb" % id


## A person, 1.7 m tall, pivot at the feet.
static func human() -> Node3D:
	var path := "res://art/walkers/citizen.glb"
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			return scene.instantiate() as Node3D
	var root := Node3D.new()
	root.name = "human"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = Balance.HUMAN_HEIGHT
	_mesh(root, capsule, Vector3(0, Balance.HUMAN_HEIGHT * 0.5, 0), "plaster")
	return root


## Height range in meters for a building (and house tier).
static func height_range(id: String, tier := 1) -> Dictionary:
	var data := Buildings.get_building(id)
	var height_class: String = data["height_class"]
	if data.has("tiers") and tier == 0:
		return Buildings.HEIGHT_CLASSES["flat"] # vacant lot
	if data.has("tiers"):
		for t in data["tiers"]:
			if t["tier"] == tier:
				height_class = t["height_class"]
	return Buildings.HEIGHT_CLASSES[height_class]


# --- Placeholder builders ---

static func _placeholder(id: String, tier: int) -> Node3D:
	var data := Buildings.get_building(id)
	var fp: Vector2i = data["footprint"]
	var w := fp.x * Balance.TILE_SIZE
	var d := fp.y * Balance.TILE_SIZE
	var root := Node3D.new()
	match id:
		"road": _road(root, w, d)
		"common_house":
			match tier:
				0: _vacant_lot(root)
				1: _choga_hut(root)
				2: _choga_house(root)
				_: _giwa_house(root)
		"well": _well(root)
		"rice_paddy": _rice_paddy(root, w, d)
		"granary": _granary(root)
		"storehouse": _storehouse(root)
		"market": _market(root)
		"seonangdang": _seonangdang(root)
		"jangseung": _jangseung(root)
		"woodcutter": _woodcutter(root)
		"clay_pit": _clay_pit(root, w, d)
		"onggi_kiln": _onggi_kiln(root)
		"soybean_field": _soybean_field(root, w, d)
		"salt_pans": _salt_pans(root, w, d)
		"jangdokdae": _jangdokdae(root)
		_: _box(root, Vector3(w - 1.0, 3.0, d - 1.0), Vector3(0, 1.5, 0), CATEGORY_COLOR.get(data.get("category", ""), "granite"))
	var door := Marker3D.new()
	door.name = "door"
	door.position = Vector3(0, 0, d * 0.5)
	root.add_child(door)
	return root


static func _road(root: Node3D, w: float, d: float) -> void:
	_box(root, Vector3(w, 0.12, d), Vector3(0, 0.06, 0), "packed_earth")


## Tier 0: a cleared plot with corner stakes and a boundary stone, waiting for settlers.
static func _vacant_lot(root: Node3D) -> void:
	_box(root, Vector3(7.6, 0.06, 7.6), Vector3(0, 0.03, 0), "packed_earth")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(root, Vector3(0.15, 0.4, 0.15), Vector3(sx * 3.6, 0.2, sz * 3.6), "wood_dark")
	_box(root, Vector3(0.5, 0.45, 0.3), Vector3(0, 0.225, 3.2), "granite")


## Tier 1: straw roof, mud walls, and a jar of rice by the door.
static func _choga_hut(root: Node3D) -> void:
	_box(root, Vector3(7.6, 0.05, 7.6), Vector3(0, 0.025, 0), "packed_earth")
	_house_body(root, Vector3(5.2, 1.7, 3.6), Vector3(0, 0, -1.0), 0.4, "plaster")
	_dome(root, Vector3(3.2, 1.4, 2.4), Vector3(0, 2.1, -1.0), "thatch")
	_door(root, Vector3(0, 0.4, -1.0 + 1.8))
	_jar(root, Vector3(1.9, 0, 1.6), 0.45)


## Tier 2: two rooms, one fire, and a little shrine for luck.
static func _choga_house(root: Node3D) -> void:
	_box(root, Vector3(7.6, 0.05, 7.6), Vector3(0, 0.025, 0), "packed_earth")
	_house_body(root, Vector3(6.4, 1.9, 3.4), Vector3(-0.4, 0, -1.6), 0.4, "plaster")
	_dome(root, Vector3(3.7, 1.4, 2.1), Vector3(-0.4, 2.3, -1.6), "thatch")
	_house_body(root, Vector3(2.8, 1.9, 3.0), Vector3(2.0, 0, 1.4), 0.4, "plaster")
	_dome(root, Vector3(1.7, 1.2, 1.8), Vector3(2.0, 2.3, 1.4), "thatch_dark")
	_door(root, Vector3(-1.2, 0.4, -1.6 + 1.7))
	_jar(root, Vector3(-2.8, 0, 1.6), 0.45)
	_jar(root, Vector3(-1.9, 0, 2.2), 0.4)
	# Little shrine: a stone with a red cloth.
	_box(root, Vector3(0.5, 0.6, 0.5), Vector3(-3.2, 0.3, -3.3), "granite_dark")
	_box(root, Vector3(0.52, 0.12, 0.52), Vector3(-3.2, 0.45, -3.3), "red")


## Tier 3: the first tiles on the street.
static func _giwa_house(root: Node3D) -> void:
	_box(root, Vector3(7.6, 0.05, 7.6), Vector3(0, 0.025, 0), "packed_earth")
	_house_body(root, Vector3(6.4, 2.6, 4.0), Vector3(0, 0, -1.2), 0.6, "plaster")
	_posts(root, Vector3(6.4, 2.6, 4.0), Vector3(0, 0.6, -1.2))
	_roof_giwa(root, Vector3(7.6, 2.9, 5.6), Vector3(0, 3.2, -1.2))
	_door(root, Vector3(0, 0.6, -1.2 + 2.0))
	# Low courtyard wall along the street side, open at the door.
	_box(root, Vector3(2.8, 1.1, 0.3), Vector3(-2.4, 0.55, 3.6), "plaster_dark")
	_box(root, Vector3(2.8, 1.1, 0.3), Vector3(2.4, 0.55, 3.6), "plaster_dark")
	for i in 3:
		_jar(root, Vector3(2.4 + i * 0.75, 0, 1.6), 0.4)


static func _well(root: Node3D) -> void:
	_cylinder(root, 1.0, 1.0, 0.8, Vector3(0, 0, 0), "granite", 12)
	_cylinder(root, 0.78, 0.78, 0.02, Vector3(0, 0.8, 0), "water", 12)
	for x in [-1.25, 1.25]:
		_cylinder(root, 0.12, 0.12, 2.7, Vector3(x, 0, 0), "wood_dark", 6)
	_box(root, Vector3(2.7, 0.15, 0.15), Vector3(0, 2.3, 0), "wood")
	_roof_giwa(root, Vector3(3.0, 0.8, 1.9), Vector3(0, 2.7, 0))


static func _rice_paddy(root: Node3D, w: float, d: float) -> void:
	_box(root, Vector3(w, 0.25, d), Vector3(0, 0.125, 0), "earth")
	var cell := (w - 1.0) / 2.0
	for ix in 2:
		for iz in 2:
			var cx := (ix - 0.5) * (cell + 0.4)
			var cz := (iz - 0.5) * (cell + 0.4)
			_box(root, Vector3(cell - 0.2, 0.05, cell - 0.2), Vector3(cx, 0.27, cz), "water")
			for r in 6:
				var rz := cz - cell * 0.5 + 0.6 + r * (cell - 1.0) / 5.0
				_box(root, Vector3(cell - 0.8, 0.2, 0.35), Vector3(cx, 0.35, rz), "rice")


static func _soybean_field(root: Node3D, w: float, d: float) -> void:
	_box(root, Vector3(w, 0.2, d), Vector3(0, 0.1, 0), "earth")
	for r in 8:
		var z := -d * 0.5 + 1.0 + r * (d - 2.0) / 7.0
		_box(root, Vector3(w - 1.2, 0.25, 0.7), Vector3(0, 0.325, z), "leaf")


static func _salt_pans(root: Node3D, w: float, d: float) -> void:
	_box(root, Vector3(w, 0.12, d), Vector3(0, 0.06, 0), "granite_dark")
	var cell := (w - 1.2) / 3.0
	for ix in 3:
		for iz in 3:
			var color := "salt" if (ix + iz) % 2 == 0 else "water"
			_box(root, Vector3(cell - 0.3, 0.08, cell - 0.3), Vector3((ix - 1) * (cell + 0.1), 0.16, (iz - 1) * (cell + 0.1)), color)


static func _clay_pit(root: Node3D, w: float, d: float) -> void:
	_box(root, Vector3(w, 0.12, d), Vector3(0, 0.06, 0), "earth")
	_box(root, Vector3(4.6, 0.04, 3.6), Vector3(-0.6, 0.14, -0.8), "earth_dark")
	for p in [Vector3(2.4, 0, 1.8), Vector3(1.2, 0, 2.6), Vector3(2.6, 0, -2.2)]:
		_dome(root, Vector3(0.8, 0.4, 0.8), p, "earth_dark")


static func _granary(root: Node3D) -> void:
	# Raised floor on posts keeps rice dry and away from rats.
	for ix in 3:
		for iz in 3:
			var p := Vector3((ix - 1) * 4.0, 0, (iz - 1) * 3.0)
			_cylinder(root, 0.35, 0.4, 0.3, p, "granite", 8)
			_cylinder(root, 0.2, 0.2, 1.3, p, "wood_dark", 6)
	_box(root, Vector3(9.2, 0.3, 7.2), Vector3(0, 1.45, 0), "wood_dark")
	_box(root, Vector3(8.6, 2.5, 6.6), Vector3(0, 1.6 + 1.25, 0), "wood")
	_roof_giwa(root, Vector3(10.4, 2.8, 8.4), Vector3(0, 4.1, 0))
	_box(root, Vector3(2.0, 0.6, 1.6), Vector3(0, 0.3, 4.2), "granite_dark") # steps
	_box(root, Vector3(1.4, 1.8, 0.1), Vector3(0, 1.6 + 0.9, 3.33), "wood_dark")


static func _storehouse(root: Node3D) -> void:
	_box(root, Vector3(10.0, 0.5, 7.6), Vector3(0, 0.25, -0.6), "granite")
	_box(root, Vector3(9.4, 3.0, 7.0), Vector3(0, 0.5 + 1.5, -0.6), "wood")
	_posts(root, Vector3(9.4, 3.0, 7.0), Vector3(0, 0.5, -0.6))
	_roof_giwa(root, Vector3(10.8, 2.8, 8.6), Vector3(0, 3.5, -0.6))
	for x in [-2.4, 2.4]:
		_box(root, Vector3(1.6, 2.2, 0.1), Vector3(x, 0.5 + 1.1, -0.6 + 3.53), "wood_dark")


static func _market(root: Node3D) -> void:
	_box(root, Vector3(11.6, 0.06, 11.6), Vector3(0, 0.03, 0), "packed_earth")
	for p in [Vector3(-3.4, 0, -3.4), Vector3(3.4, 0, -3.4), Vector3(-3.4, 0, 3.0), Vector3(3.4, 0, 3.0)]:
		_box(root, Vector3(2.8, 0.9, 1.2), p + Vector3(0, 0.45, 0), "wood")
		_box(root, Vector3(2.6, 0.12, 1.0), p + Vector3(0, 0.96, 0), "ochre")
		for sx in [-1.4, 1.4]:
			for sz in [-0.9, 0.9]:
				_cylinder(root, 0.08, 0.08, 2.4, p + Vector3(sx, 0, sz), "wood_dark", 6)
		_roof_thatch_ridge(root, Vector3(3.4, 0.9, 2.4), p + Vector3(0, 2.4, 0))
	for i in 4:
		_jar(root, Vector3(-0.9 + i * 0.6, 0, 0.0), 0.35)


static func _seonangdang(root: Node3D) -> void:
	# Stone cairn under a sacred tree, with cloth strips on a rope.
	_dome(root, Vector3(1.0, 0.8, 1.0), Vector3(0.2, 0, 0.4), "granite")
	_dome(root, Vector3(0.7, 0.6, 0.7), Vector3(0.2, 0.6, 0.4), "granite_dark")
	_dome(root, Vector3(0.4, 0.4, 0.4), Vector3(0.2, 1.1, 0.4), "granite")
	_cylinder(root, 0.18, 0.25, 1.9, Vector3(-0.8, 0, -0.9), "wood_dark", 6)
	_dome(root, Vector3(1.4, 1.6, 1.4), Vector3(-0.8, 1.9, -0.9), "leaf")
	_box(root, Vector3(2.4, 0.04, 0.04), Vector3(0.2, 1.6, -0.9), "plaster")
	for i in 5:
		_box(root, Vector3(0.12, 0.6, 0.03), Vector3(-0.8 + i * 0.45, 1.3, -0.9), "red" if i % 2 == 0 else "turquoise")


static func _jangseung(root: Node3D) -> void:
	# A pair of guardian posts: General of Heaven and General of Earth.
	for x in [-0.8, 0.8]:
		_cylinder(root, 0.35, 0.4, 0.25, Vector3(x, 0, 0), "granite", 8)
		_cylinder(root, 0.22, 0.24, 2.6, Vector3(x, 0, 0), "wood", 8)
		_cylinder(root, 0.26, 0.26, 0.6, Vector3(x, 1.9, 0), "red" if x < 0 else "plaster_dark", 8)
		_cylinder(root, 0.3, 0.3, 0.4, Vector3(x, 2.6, 0), "black", 8)


static func _woodcutter(root: Node3D) -> void:
	_box(root, Vector3(7.6, 0.05, 7.6), Vector3(0, 0.025, 0), "packed_earth")
	_house_body(root, Vector3(4.4, 1.9, 3.2), Vector3(-1.2, 0, -1.8), 0.3, "earth")
	_dome(root, Vector3(2.7, 1.2, 2.0), Vector3(-1.2, 2.2, -1.8), "thatch")
	# Log pile: three logs below, two on top.
	for i in 5:
		var row := 0 if i < 3 else 1
		var slot := i if row == 0 else i - 3
		var piece := _cylinder(root, 0.28, 0.28, 3.0, Vector3.ZERO, "wood", 8)
		piece.rotation = Vector3(0, 0, PI * 0.5)
		piece.position = Vector3(2.2, 0.28 + row * 0.5, 0.6 + slot * 0.6 + row * 0.3)
	_cylinder(root, 0.4, 0.4, 0.5, Vector3(0.0, 0, 2.2), "wood_dark", 8) # chopping block


static func _onggi_kiln(root: Node3D) -> void:
	_box(root, Vector3(11.6, 0.05, 7.6), Vector3(0, 0.025, 0), "packed_earth")
	# The long climbing kiln, half buried, with a chimney at the high end.
	var kiln := _cylinder(root, 1.4, 1.4, 8.0, Vector3.ZERO, "earth", 12)
	kiln.rotation = Vector3(0, 0, PI * 0.5)
	kiln.position = Vector3(-0.6, 0.6, -1.6)
	_box(root, Vector3(1.0, 6.4, 1.0), Vector3(4.2, 3.2, -1.6), "earth_dark")
	# Work shed.
	_house_body(root, Vector3(3.4, 2.4, 2.6), Vector3(-3.6, 0, 1.8), 0.3, "earth")
	_roof_giwa(root, Vector3(4.2, 1.6, 3.4), Vector3(-3.6, 2.7, 1.8))
	for i in 4:
		_jar(root, Vector3(0.0 + i * 0.9, 0, 2.4), 0.4)


static func _jangdokdae(root: Node3D) -> void:
	# A raised stone terrace for jars, with a persimmon tree for summer shade. The jars
	# themselves are drawn by city_view.gd as they arrive (one per load of Onggi Jars).
	_box(root, Vector3(7.0, 0.45, 6.0), Vector3(0, 0.225, 0.2), "granite")
	_cylinder(root, 0.2, 0.25, 1.8, Vector3(-3.0, 0, -3.2), "wood_dark", 6)
	_dome(root, Vector3(1.0, 1.6, 1.0), Vector3(-3.0, 1.9, -3.2), "leaf_dark")


# --- Shapes ---

## Stone plinth plus walls. `size` = wall size; walls start on top of the plinth.
static func _house_body(root: Node3D, size: Vector3, at: Vector3, plinth: float, wall_color: String) -> void:
	_box(root, Vector3(size.x + 0.4, plinth, size.z + 0.4), at + Vector3(0, plinth * 0.5, 0), "granite")
	_box(root, size, at + Vector3(0, plinth + size.y * 0.5, 0), wall_color)


## Wooden corner posts on a wall box (base at `at`).
static func _posts(root: Node3D, size: Vector3, at: Vector3) -> void:
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_box(root, Vector3(0.3, size.y, 0.3), at + Vector3(sx * size.x, size.y * 0.5, sz * size.z), "wood_dark")


static func _door(root: Node3D, at_wall_base: Vector3) -> void:
	_box(root, Vector3(0.9, 1.5, 0.12), at_wall_base + Vector3(0, 0.75, 0), "wood_dark")


## Giwa roof: prism with the ridge along the longer side, plus a dark ridge cap.
## `size` = (x, height, z), `base` = center of the roof's bottom.
static func _roof_giwa(root: Node3D, size: Vector3, base: Vector3) -> void:
	_prism(root, size, base, "giwa")
	var cap := Vector3(size.x + 0.1, 0.25, 0.35) if size.x >= size.z else Vector3(0.35, 0.25, size.z + 0.1)
	_box(root, cap, base + Vector3(0, size.y - 0.1, 0), "giwa_dark")


static func _roof_thatch_ridge(root: Node3D, size: Vector3, base: Vector3) -> void:
	_prism(root, size, base, "thatch")


static func _prism(root: Node3D, size: Vector3, base: Vector3, color: String) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	var along_x := size.x >= size.z
	# PrismMesh has its ridge along Z; turn it when the roof is wider than deep.
	mesh.size = Vector3(size.z, size.y, size.x) if along_x else size
	var mi := _mesh(root, mesh, base + Vector3(0, size.y * 0.5, 0), color)
	if along_x:
		mi.rotation = Vector3(0, PI * 0.5, 0)
	return mi


## Rounded dome (thatch roof, cairn, tree crown). `radii` = (x, height, z);
## `base` = center at the dome's widest ring.
static func _dome(root: Node3D, radii: Vector3, base: Vector3, color: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.0
	mesh.is_hemisphere = true
	mesh.radial_segments = 16
	mesh.rings = 6
	var mi := _mesh(root, mesh, base, color)
	mi.scale = radii
	return mi


static func _jar(root: Node3D, at: Vector3, radius: float) -> void:
	var height := radius * 2.0
	_cylinder(root, radius * 0.7, radius * 0.75, height, at, "onggi", 10)
	_cylinder(root, radius, radius, height * 0.5, at + Vector3(0, height * 0.25, 0), "onggi", 10)
	_cylinder(root, radius * 0.75, radius * 0.75, 0.08, at + Vector3(0, height, 0), "onggi_light", 10)


## Cylinder standing on `base` (bottom center).
static func _cylinder(root: Node3D, top_r: float, bottom_r: float, height: float, base: Vector3, color: String, segments := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(root, mesh, base + Vector3(0, height * 0.5, 0), color)


static func _box(root: Node3D, size: Vector3, center: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(root, mesh, center, color)


static func _mesh(root: Node3D, mesh: Mesh, position: Vector3, color: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = position
	mi.material_override = _material(color)
	root.add_child(mi)
	return mi


static func _material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(C.get(color, color))
		m.roughness = 0.9
		_materials[color] = m
	return _materials[color]
