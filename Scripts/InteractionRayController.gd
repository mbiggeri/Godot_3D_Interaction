# InteractionRayController.gd
# Attach this script to your RayCast3D node, which should be a child of the Player/Interactor.
extends RayCast3D

## Emitted when the focused interactable object changes.
signal focused_interactable_changed(new_interactable: Interactable)

var current_interactable_in_focus: Interactable = null
var active: bool = true:
	set(value):
		active = value
		enabled = value # Ensure the RayCast3D is enabled/disabled along with 'active'.
		# If deactivated, unfocus any currently focused object.
		if not active and current_interactable_in_focus:
			current_interactable_in_focus.on_unfocus()
			current_interactable_in_focus = null
			emit_signal("focused_interactable_changed", null)

## A reference to the node performing the interaction (usually the RayCast's parent).
## Can be set from the editor or inferred at runtime.
@export var interactor: Node = null


func _ready() -> void:
	enabled = active
	# If the interactor is not set explicitly, try to get it from the parent.
	if interactor == null:
		var parent_node = get_parent()
		if parent_node is Node: # Check if the parent is a valid Node
			interactor = parent_node


func _physics_process(_delta: float) -> void:
	if not active:
		return

	var new_focused_object: Interactable = null

	if is_colliding():
		var collider = get_collider()
		# Ensure the collider is an Interactable before casting.
		if collider is Interactable:
			var interactable_collider = collider as Interactable # Safe cast
			if interactable_collider.can_interact:
				new_focused_object = interactable_collider
	
	# If the focused object has changed, update the state.
	if new_focused_object != current_interactable_in_focus:
		# Unfocus the old object if it exists.
		if current_interactable_in_focus != null:
			current_interactable_in_focus.on_unfocus()
		
		current_interactable_in_focus = new_focused_object
		
		# Focus the new object if it exists.
		if current_interactable_in_focus != null:
			current_interactable_in_focus.on_focus()
			
		emit_signal("focused_interactable_changed", current_interactable_in_focus)


# Handles the input for interaction.
func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if current_interactable_in_focus != null and event.is_action_pressed("interact"):
		if interactor == null:
			printerr("InteractionRayController: Attempted to interact but 'interactor' is null.")
			return

		# --- KEY CHANGE ---
		# Consume the input BEFORE performing the action, as the action might
		# change the scene or invalidate this node.
		get_viewport().set_input_as_handled() 
		
		current_interactable_in_focus.interact(interactor)
		
		# NOTE: Do not place any code here that depends on the current scene's validity
		# if the interact() call above could have caused a scene change.


# Public method to get the currently focused object (if needed elsewhere).
func get_focused_interactable() -> Interactable:
	return current_interactable_in_focus
