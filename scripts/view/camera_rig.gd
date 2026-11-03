extends Node3D
## Orthographic isometric camera. The rig sits on the ground at the point the camera
## looks at; the camera itself is a child placed back along the view direction.
## Q / E rotate in 90-degree steps, mouse wheel zooms, WASD / arrows / screen edge
## and middle mouse drag move.

const Balance = preload("res://scripts/data/balance.gd")

var camera: Camera3D
var zoom := Balance.CAMERA_ZOOM_DEFAULT # visible height in meters
var bounds_min := Vector2.ZERO # x/z limits for the focus point, meters
var bounds_max := Vector2(Balance.MAP_WIDTH, Balance.MAP_HEIGHT) * Balance.TILE_SIZE

var _yaw_step := 0
var _yaw := deg_to_rad(Balance.CAMERA_YAW_DEG)
var _yaw_tween: Tween
var _dragging := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = Balance.CAMERA_DISTANCE * 2.0
	add_child(camera)
	camera.make_current()
	_update_camera()


func set_bounds(min_xz: Vector2, max_xz: Vector2) -> void:
	bounds_min = min_xz
	bounds_max = max_xz
	_clamp_position()


func focus_on(world_pos: Vector3) -> void:
	position = Vector3(world_pos.x, 0.0, world_pos.z)
	_clamp_position()


func rotate_step(direction: int) -> void:
	_yaw_step = posmod(_yaw_step + direction, 4)
	# Turn from the current angle (even mid-turn) the short way to the new step.
	var step_angle := deg_to_rad(Balance.CAMERA_YAW_DEG + 90.0 * _yaw_step)
	var target := _yaw + wrapf(step_angle - _yaw, -PI, PI)
	if _yaw_tween:
		_yaw_tween.kill()
	_yaw_tween = create_tween()
	_yaw_tween.tween_method(_set_yaw, _yaw, target, Balance.CAMERA_ROTATE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_yaw(value: float) -> void:
	_yaw = value
	_update_camera()


func _update_camera() -> void:
	var pitch := deg_to_rad(Balance.CAMERA_PITCH_DEG)
	var to_camera := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch))
	camera.transform = Transform3D(Basis.looking_at(-to_camera, Vector3.UP), to_camera * Balance.CAMERA_DISTANCE)
	camera.size = zoom


## Ground directions that match screen right and screen up.
func _ground_axes() -> Array[Vector3]:
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var up := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	return [right, up]


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if not Input.is_key_pressed(KEY_CTRL): # Ctrl+S saves, it should not also pan
		input = Vector2(
			Input.get_axis("camera_left", "camera_right"),
			Input.get_axis("camera_back", "camera_forward"))
	input += _edge_input()
	if input == Vector2.ZERO:
		return
	input = input.limit_length(1.0)
	var axes := _ground_axes()
	var pitch := deg_to_rad(Balance.CAMERA_PITCH_DEG)
	var speed := zoom * Balance.CAMERA_PAN_SPEED * delta
	# Screen-up covers more ground than screen-right because the view is tilted.
	position += axes[0] * input.x * speed + axes[1] * input.y * speed / sin(pitch)
	_clamp_position()


func _edge_input() -> Vector2:
	if _dragging or not DisplayServer.window_is_focused():
		return Vector2.ZERO
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var mouse := viewport.get_mouse_position()
	if not rect.has_point(mouse):
		return Vector2.ZERO
	var m := Balance.CAMERA_EDGE_MARGIN
	var result := Vector2.ZERO
	if mouse.x <= rect.position.x + m:
		result.x = -1.0
	elif mouse.x >= rect.end.x - m - 1:
		result.x = 1.0
	if mouse.y <= rect.position.y + m:
		result.y = 1.0
	elif mouse.y >= rect.end.y - m - 1:
		result.y = -1.0
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate_left", false, true):
		rotate_step(-1)
	elif event.is_action_pressed("camera_rotate_right", false, true):
		rotate_step(1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(zoom / Balance.CAMERA_ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(zoom * Balance.CAMERA_ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_drag((event as InputEventMouseMotion).relative)


func _set_zoom(value: float) -> void:
	zoom = clampf(value, Balance.CAMERA_ZOOM_MIN, Balance.CAMERA_ZOOM_MAX)
	camera.size = zoom


## Moves the view so the ground under the mouse follows the mouse.
func _drag(relative: Vector2) -> void:
	var meters_per_pixel := zoom / get_viewport().get_visible_rect().size.y
	var axes := _ground_axes()
	var pitch := deg_to_rad(Balance.CAMERA_PITCH_DEG)
	position += (-axes[0] * relative.x + axes[1] * relative.y / sin(pitch)) * meters_per_pixel
	_clamp_position()


func _clamp_position() -> void:
	position.x = clampf(position.x, bounds_min.x, bounds_max.x)
	position.z = clampf(position.z, bounds_min.y, bounds_max.y)
