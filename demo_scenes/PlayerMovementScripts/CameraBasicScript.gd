extends Node3D

class_name SimpleCameraObject

## --- Settings ---
@export_group("Sensitivity")
@export var mouse_sensitivity: float = 0.003
@export var controller_sensitivity: float = 1.5

@export_group("Limits")
@export var vertical_angle_limit: float = 60.0
@export var controller_deadzone: float = 0.15

## --- Nodes ---
@onready var camera: Camera3D = $Camera3D

# =====================================================================

func _ready():
	# Captures the mouse cursor to enable camera rotation.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent):
	# Handles camera rotation with mouse movement.
	if event is InputEventMouseMotion:
		# Horizontal rotation (yaw) is applied to the parent Node3D.
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Vertical rotation (pitch) is applied directly to the Camera3D node.
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp the vertical rotation to prevent the camera from flipping over.
		var angle_limit_rad = deg_to_rad(vertical_angle_limit)
		camera.rotation.x = clamp(camera.rotation.x, -angle_limit_rad, angle_limit_rad)

func _process(delta: float):
	# Handles camera rotation using a controller's right analog stick each frame.
	_handle_controller_look(delta)

func _handle_controller_look(delta: float):
	# Get input from the analog stick.
	# NOTE: Ensure you have actions named "look_left", "look_right", "look_up",
	# and "look_down" set up in Project > Project Settings > Input Map.
	var look_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Apply a deadzone to ignore minor stick drift.
	if look_vector.length() > controller_deadzone:
		# Horizontal rotation (yaw).
		rotate_y(-look_vector.x * controller_sensitivity * delta)
		
		# Vertical rotation (pitch).
		camera.rotate_x(-look_vector.y * controller_sensitivity * delta)
		
		# Clamp the vertical rotation, same as with the mouse.
		var angle_limit_rad = deg_to_rad(vertical_angle_limit)
		camera.rotation.x = clamp(camera.rotation.x, -angle_limit_rad, angle_limit_rad)
