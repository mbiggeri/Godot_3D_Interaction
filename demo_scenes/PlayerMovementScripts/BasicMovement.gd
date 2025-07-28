extends CharacterBody3D

class_name BasicCharacter

#--------------------------------------------------------------------
# MOVEMENT VARIABLES
#--------------------------------------------------------------------
@export_group("Movement Settings")
@export var move_speed: float = 5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0

# Private movement variables
var move_direction: Vector3 = Vector3.ZERO
var current_input_direction: Vector2 = Vector2.ZERO

#--------------------------------------------------------------------
# NODES
#--------------------------------------------------------------------
@onready var camera_holder = $CameraHolder

# =====================================================================
# ENGINE FUNCTIONS
# =====================================================================

func _ready():
	# This function is called when the node enters the scene tree for the first time.
	# You can add any initialization logic here.
	pass

func _physics_process(delta):
	# Get player input (keyboard)
	current_input_direction = _get_player_input()

	# Calculate the movement direction based on camera orientation
	move_direction = (camera_holder.basis * Vector3(current_input_direction.x, 0, current_input_direction.y)).normalized()

	# Apply movement
	_apply_movement(delta)

	# Godot's built-in function to move the character
	move_and_slide()

# =====================================================================
# HELPER FUNCTIONS
# =====================================================================

func _get_player_input() -> Vector2:
	"""
	Gets the player's movement input from the Input Map.
	Returns a Vector2 representing the direction.
	"""
	return Input.get_vector("moveLeft", "moveRight", "moveForward", "moveBackward")

func _apply_movement(delta: float):
	"""
	Applies acceleration and deceleration to the character's velocity.
	Gravity has been removed, so the character will only move horizontally.
	"""
	if move_direction != Vector3.ZERO:
		# Accelerate in the direction of input
		velocity.x = lerp(velocity.x, move_direction.x * move_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, move_direction.z * move_speed, acceleration * delta)
	else:
		# Decelerate when there is no input
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)

	# The character's vertical velocity is not modified, so there is no jumping or gravity.
	# To keep the character on the ground, ensure the floor is flat.
