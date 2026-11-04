extends Node3D
## Signs over houses (CLAUDE.md, "Čitljiv interfejs"): a face for how the house feels and,
## beside it, an icon for every need it lacks (houses.gd mood()). All signs are one
## MultiMesh of camera-facing quads that pick their icon from the atlas (house_icons.gd).
## H switches what is shown: problems only (sad and neutral houses), every house, nothing.
## Only reads the city.

const Balance = preload("res://scripts/data/balance.gd")
const Grid = preload("res://scripts/sim/grid.gd")
const HouseIcons = preload("res://scripts/view/house_icons.gd")
const Factory = preload("res://scripts/view/placeholder_factory.gd")

const MODES: Array[String] = ["problems", "all", "off"]
const ICON_SIZE := 2.4 # meters
const GAP := 1.1 # icon widths between the centers of two icons
const ABOVE_ROOF := 1.8 # meters
const REFRESH := 0.5 # seconds

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float cells = 4.0;
varying vec2 cell_uv;

void vertex() {
	// Shift the icon sideways (in icon widths) in screen space, then face the camera.
	VERTEX.x += INSTANCE_CUSTOM.y;
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	float i = INSTANCE_CUSTOM.x;
	cell_uv = (vec2(mod(i, cells), floor(i / cells)) + UV) / cells;
}

void fragment() {
	vec4 c = texture(atlas, cell_uv);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

var city # scripts/sim/city.gd
var mode := "problems"
var _signs: MultiMeshInstance3D
var _wait := 0.0


func setup(city_ref) -> void:
	city = city_ref
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", HouseIcons.atlas())
	material.set_shader_parameter("cells", float(HouseIcons.CELLS))
	_signs = MultiMeshInstance3D.new()
	_signs.name = "HouseSigns"
	_signs.multimesh = mm
	_signs.material_override = material
	_signs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_signs)
	refresh()


## Problems only -> every house -> off -> problems only. Returns the new mode.
func next_mode() -> String:
	mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
	refresh()
	return mode


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		refresh()


func refresh() -> void:
	_wait = REFRESH
	var items := signs()
	var mm := _signs.multimesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i]["xform"])
		mm.set_instance_custom_data(i, Color(items[i]["icon"], items[i]["shift"], 0, 0))
	_signs.visible = not items.is_empty()


## Every icon to draw: [{"house", "icon" (atlas cell), "shift" (icon widths), "xform"}].
func signs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if mode == "off":
		return result
	var houses = city.houses
	for id: int in houses.state:
		var instance: Dictionary = city.buildings.get_instance(id)
		var feel: Dictionary = houses.mood(instance)
		if feel["mood"] == "" or (mode == "problems" and feel["mood"] == "happy"):
			continue
		var top: float = Factory.height_range(instance["type"], instance["tier"])["max"]
		var at := Grid.footprint_center(instance["origin"], instance["size"]) + Vector3(0, top + ABOVE_ROOF, 0)
		var xform := Transform3D(Basis.from_scale(Vector3.ONE * ICON_SIZE), at)
		var icons: Array[int] = [HouseIcons.INDEX[feel["mood"]]]
		for need: String in feel["missing"]:
			icons.append(HouseIcons.INDEX[need])
		var left := -(icons.size() - 1) * GAP * 0.5 # the row is centered over the house
		for k in icons.size():
			result.append({"house": id, "icon": float(icons[k]), "shift": left + k * GAP, "xform": xform})
	return result
