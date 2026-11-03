extends Node
## Test scene "big city" (CLAUDE.md: 60 FPS with 3,000 residents and 400 walkers).
## Open scenes/big_city.tscn and press F6: it builds the big city (scripts/sim/big_city.gd)
## and plays it in the normal game scene, with frames per second shown top left.

const BigCity = preload("res://scripts/sim/big_city.gd")
const Main = preload("res://scripts/view/main.gd")


func _ready() -> void:
	Main.pending_city = BigCity.build()
	Main.show_fps = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
