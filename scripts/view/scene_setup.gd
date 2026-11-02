extends RefCounted
## Shared light and sky for the game and the gallery: a warm, calm afternoon.

static func add_environment(parent: Node) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#9fb8c8")
	sky_material.sky_horizon_color = Color("#e8e0cc")
	sky_material.ground_horizon_color = Color("#e8e0cc")
	sky_material.ground_bottom_color = Color("#b9ad94")
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#fff3df")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	# From the south-west, high in the sky.
	sun.rotation_degrees = Vector3(-55.0, -140.0, 0.0)
	parent.add_child(sun)
