extends RefCounted
## Shortest paths along roads for destination walkers (carriers, later buyers and settlers).
## Built on AStarGrid2D; rebuilt only when roads are built or demolished.
## Jangseung tiles stay roads here: destination walkers pass them.

const Grid = preload("res://scripts/sim/grid.gd")

var astar := AStarGrid2D.new()
var rebuild_count := 0 # for tests: how often the network was rebuilt


func rebuild(grid: Grid) -> void:
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	astar.fill_solid_region(astar.region, true)
	for y in grid.height:
		for x in grid.width:
			if grid.is_road(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), false)
	rebuild_count += 1


## Road tiles from `a` to `b`, both included. Empty when there is no road connection.
func path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return []
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return []
	return astar.get_id_path(a, b)
