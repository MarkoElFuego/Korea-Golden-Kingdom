extends SceneTree
## Opens a scene, waits a moment and saves a screenshot. Usage (not headless):
##   <Godot exe> -s res://tools/screenshot.gd -- res://scenes/main.tscn out.png

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/main.tscn"
	_out = args[1] if args.size() > 1 else "user://screenshot.png"
	root.add_child((load(scene_path) as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_texture().get_image().save_png(_out)
		print("Saved ", _out)
		return true
	return false
