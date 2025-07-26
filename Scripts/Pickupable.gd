# pickupable.gd
# Extends the Interactable class to create objects that can be picked up and inspected.
# Features a temporary input lock during inspection before the item can be stored.
class_name Pickupable
extends Interactable

## Emitted when the item is "stored" after inspection.
## An inventory system can listen for this signal to add the item.
## Passes this node itself as an argument so the inventory can read its data.
signal stored(item: Node)

# Enum to manage the object's current state.
enum State {
	IN_WORLD,      # In the scene, can be picked up.
	BEING_VIEWED,  # Held in front of the camera for inspection.
	STORED         # Stored in the inventory (and removed from the scene).
}

@export_group("Pickupable Settings")
## Rotation speed when inspecting the object with the mouse.
@export var inspection_rotation_speed: float = 0.2
## The zoom factor (how close the object appears to the camera).
@export var inspection_zoom: float = 1.0
## Duration in seconds of the initial input lock, during which the item cannot be stored.
@export var inspection_lock_duration: float = 1.5

# --- Private Variables ---
var _dynamic_hold_point: Node3D
var _current_state: State = State.IN_WORLD
var _original_parent: Node
var _current_interactor: Node = null # Stores the interactor for later use.

# Variables for the input lock logic
var _inspection_timer: Timer
var _is_inspection_locked: bool = false


# Overrides the 'interact' function from the base class.
func interact(interactor: Node = null) -> void:
	if not can_interact:
		return

	# Interaction is only allowed when the item is in the world.
	# Storing the item is now handled by the general input handler.
	if _current_state == State.IN_WORLD:
		var camera := get_viewport().get_camera_3d()
		if camera:
			_pickup_item(interactor, camera)
		else:
			printerr("%s: Could not find an active 3D camera in the scene." % name)


# Handles input for rotating and storing the item.
func _unhandled_input(event: InputEvent) -> void:
	# Only process input if we are currently inspecting the item.
	if _current_state != State.BEING_VIEWED:
		return

	# CASE 1: The event is mouse motion. Use it for rotation.
	if event is InputEventMouseMotion:
		# Rotate the object based on the mouse's relative motion.
		self.rotate_y(deg_to_rad(-event.relative.x * inspection_rotation_speed))
		self.rotate_x(deg_to_rad(-event.relative.y * inspection_rotation_speed))
		
		# Consume the event to prevent the player camera from moving.
		get_viewport().set_input_as_handled()
		return

	# CASE 2: The inspection is currently locked by the timer.
	# Ignore and consume any other input during this time.
	if _is_inspection_locked:
		get_viewport().set_input_as_handled()
		return
		
	# CASE 3: Inspection is unlocked, and we receive an input press.
	# Use this input to store the item.
	if event.is_pressed():
		_store_item(_current_interactor)
		get_viewport().set_input_as_handled()


# --- PRIVATE HELPER FUNCTIONS ---

# Logic for picking up the item from the world.
func _pickup_item(interactor: Node, camera: Camera3D) -> void:
	_current_state = State.BEING_VIEWED
	_current_interactor = interactor
	
	# Remove the highlight if it's currently active.
	if _is_currently_highlighted:
		super.on_unfocus()
	
	# Disable physics and collisions.
	var collision_shape := find_child("CollisionShape3D", true, false) as CollisionShape3D
	if collision_shape:
		collision_shape.disabled = true
	
	# Create a dynamic hold point and attach the item to it.
	_dynamic_hold_point = Node3D.new()
	camera.add_child(_dynamic_hold_point)
	_original_parent = get_parent()
	if _original_parent:
		_original_parent.remove_child(self)
	_dynamic_hold_point.add_child(self)

	# Instantly position the item in front of the camera.
	self.position = Vector3(0, 0, -inspection_zoom)
	self.rotation = Vector3.ZERO
	
	# Start the input lock and its associated timer.
	_is_inspection_locked = true
	_inspection_timer = Timer.new()
	add_child(_inspection_timer)
	_inspection_timer.wait_time = inspection_lock_duration
	_inspection_timer.one_shot = true
	_inspection_timer.timeout.connect(_on_inspection_lock_timeout)
	_inspection_timer.start()

	# Notify the interactor (player) to disable its inputs (movement, etc.).
	if interactor and interactor.has_method("set_is_holding"):
		interactor.set_is_holding(true)

# Called when the inspection lock timer finishes.
func _on_inspection_lock_timeout() -> void:
	_is_inspection_locked = false
	print("Inspection unlocked. Press any key or click to store the item.")


# Logic for storing the item.
func _store_item(interactor: Node) -> void:
	# Ensure this logic doesn't run more than once.
	if _current_state == State.STORED:
		return
		
	_current_state = State.STORED
	can_interact = false
	
	# Emit the signal for the inventory system.
	emit_signal("stored", self)

	# Notify the player that they can regain control.
	if interactor and interactor.has_method("set_is_holding"):
		interactor.set_is_holding(false)
	
	# Clean up the dynamically created nodes.
	if is_instance_valid(_dynamic_hold_point):
		_dynamic_hold_point.queue_free()
	
	if is_instance_valid(_inspection_timer):
		_inspection_timer.queue_free()
		
	# Remove the item from the scene.
	self.queue_free()
