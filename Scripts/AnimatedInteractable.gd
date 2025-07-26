# AnimatedInteractable.gd
# Extends Interactable to play animations. It can function as a one-time trigger,
# a toggle switch, and can interact with a global state system.
extends Interactable
class_name AnimatedInteractable

## The AnimationPlayer node that will control the animations.
@export var animation_player: AnimationPlayer

## The name of the animation to play (or the "forward" animation for toggles).
@export var animation_name: StringName = ""

## If true, interacting will toggle the animation (forward/backward).
@export var can_toggle: bool = false

## The name of the "reverse" animation for the toggle.
## If empty and can_toggle is true, 'animation_name' will be played backward.
@export var animation_name_reverse: StringName = ""

## If true, the object can only be interacted with once.
@export var one_time_interaction: bool = false

## If true, interaction will be ignored if the AnimationPlayer is currently busy
## playing ANY animation, allowing the current one to finish.
@export var prevent_retrigger_if_playing: bool = true

## The name of a global boolean variable that must be true for the interaction to be allowed.
## Leave empty to not require any global variable.
## Relies on an Autoload named "GlobalBooleans".
@export var require_global_bool_name: StringName = ""

## The name of a global boolean variable to set to true after a successful interaction.
## Leave empty to not set any global variable.
## Relies on an Autoload named "GlobalBooleans".
@export var set_global_bool_on_interact_name: StringName = ""


# Tracks the specific animation that this script has started and is waiting to finish.
var _current_animation_playing_by_this: StringName = ""
# State for the toggle logic (e.g., true if the object is "on").
var _is_toggled_on: bool = false


# --- NOTE on the "GlobalBooleans" Autoload ---
# This script can use an autoload singleton named "GlobalBooleans" to manage game-wide state.
# A simple implementation of "GlobalBooleans.gd" would look like this:
#
# extends Node
# var bools: Dictionary = {}
#
# func set_global_bool(key: StringName, value: bool) -> void:
#     bools[key] = value
#
# func get_global_bool(key: StringName) -> bool:
#     return bools.get(key, false)
#

func _ready() -> void:
	# Critical setup validation.
	if not animation_player:
		printerr("ERROR (%s): AnimatedInteractable - 'Animation Player' not assigned in the Inspector!" % name)
		can_interact = false # Disable interaction if critical setup is missing.
		return

	# Connect to the animation_finished signal to track completion.
	if not animation_player.is_connected("animation_finished", self._on_animation_finished):
		animation_player.animation_finished.connect(self._on_animation_finished)

	# Warn if the main animation name is not specified.
	if animation_name == "":
		print_rich("[color=orange]WARNING (%s): AnimatedInteractable - Main 'Animation Name' is not specified.[/color]" % name)

	# Warn if the GlobalBooleans Autoload is not available but is being used.
	if (require_global_bool_name != "" or set_global_bool_on_interact_name != "") and not Engine.has_singleton("GlobalBooleans"):
		printerr("ERROR (%s): AnimatedInteractable - The 'GlobalBooleans' Autoload is not configured in the project but is required by this node." % name)


func _exit_tree() -> void:
	# Disconnect the signal when the node exits the tree to prevent errors.
	if is_instance_valid(animation_player) and animation_player.is_connected("animation_finished", self._on_animation_finished):
		animation_player.animation_finished.disconnect(self._on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	# If the completed animation is the one we were specifically tracking, reset our state.
	if anim_name == _current_animation_playing_by_this:
		_current_animation_playing_by_this = ""


# Override the interact function to add animation logic.
func interact(_interactor = null) -> void:
	# 1. Check if interaction is possible according to the base class.
	if not can_interact:
		super.interact(_interactor) # Let the base class print its "cannot be interacted with" message.
		return

	# 2. [NEW] Check the global boolean requirement.
	if require_global_bool_name != "" and Engine.has_singleton("GlobalBooleans"):
		if not GlobalBooleans.get_global_bool(require_global_bool_name):
			# Interaction is blocked by a global flag. Do nothing.
			# You could optionally play a "locked" sound here.
			return

	# 3. Check configuration and state.
	if not animation_player:
		return

	if prevent_retrigger_if_playing and animation_player.is_playing():
		return

	# 4. Determine which animation to play based on toggle logic.
	var anim_to_play: StringName = ""
	var anim_speed: float = 1.0
	
	if can_toggle:
		if not _is_toggled_on: # Currently "off", action is to turn "on".
			anim_to_play = animation_name
		else: # Currently "on", action is to turn "off".
			if animation_name_reverse != "": # If a specific reverse animation is provided, use it.
				anim_to_play = animation_name_reverse
			else: # Otherwise, play the main animation in reverse.
				anim_to_play = animation_name
				anim_speed = -1.0
	else: # Not a toggle, just play the main animation.
		anim_to_play = animation_name

	# 5. If we have a valid animation to play, proceed.
	if anim_to_play == "" or not animation_player.has_animation(anim_to_play):
		printerr("ERROR (%s): AnimatedInteractable - Animation '%s' not found or not specified." % [name, anim_to_play])
		# Still call super.interact() so the interaction sound plays, etc.
		super.interact(_interactor)
		return

	# 6. All checks passed, execute the base interaction.
	# This will emit the "interacted" signal and play sounds.
	super.interact(_interactor)

	# 7. Play the animation.
	animation_player.play(anim_to_play, -1, anim_speed)
	_current_animation_playing_by_this = anim_to_play # Track the animation started by this script.
	
	if can_toggle:
		_is_toggled_on = not _is_toggled_on

	# 8. [NEW] Set the global boolean, if specified.
	if set_global_bool_on_interact_name != "" and Engine.has_singleton("GlobalBooleans"):
		GlobalBooleans.set_global_bool(set_global_bool_on_interact_name, true)

	# 9. Handle one-time interaction if enabled.
	if one_time_interaction:
		can_interact = false
