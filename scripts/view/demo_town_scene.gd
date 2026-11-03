extends Node
## Demo town: open scenes/demo_town.tscn and press F6. It builds a small working town
## (scripts/sim/demo_town.gd) and plays it in the normal game scene, ready to try out.

const DemoTown = preload("res://scripts/sim/demo_town.gd")
const Main = preload("res://scripts/view/main.gd")


func _ready() -> void:
	Main.pending_city = DemoTown.build()
	Main.show_fps = false
	for problem in DemoTown.failures:
		push_warning("Demo town: " + problem)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
