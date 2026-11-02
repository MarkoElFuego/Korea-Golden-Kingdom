extends SceneTree
## Prints the generated map as text (one letter per tile). Usage:
##   <Godot console exe> --headless -s res://tools/print_map.gd [-- seed]

const Balance = preload("res://scripts/data/balance.gd")
const MapGenerator = preload("res://scripts/sim/map_generator.gd")

const LETTERS := ".PrS~FMR" # grass, plain, river, sea, shore, forest, mountain, rocky hill


func _initialize() -> void:
	var map_seed := Balance.DEFAULT_MAP_SEED
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		map_seed = int(args[0])
	var t := MapGenerator.generate(map_seed, Balance.MAP_WIDTH, Balance.MAP_HEIGHT)
	for y in Balance.MAP_HEIGHT:
		var line := ""
		for x in Balance.MAP_WIDTH:
			line += LETTERS[t[y * Balance.MAP_WIDTH + x]]
		print(line)
	quit()
