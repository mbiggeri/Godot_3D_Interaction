# GlobalBooleans.gd
# This script should be set up as an Autoload (Singleton) in Project Settings.
# It provides a global, accessible way to manage boolean flags for game state.
extends Node

var booleans: Dictionary = {}

## Sets the value of a global boolean variable.
## Creates the variable if it does not exist.
func set_global_bool(variable_name: StringName, value: bool) -> void:
	booleans[variable_name] = value
	# You might want to emit a signal here if other nodes need to react dynamically to changes.
	# emit_signal("global_bool_changed", variable_name, value)

## Gets the value of a global boolean variable.
## Returns 'false' if the variable does not exist.
func get_global_bool(variable_name: StringName) -> bool:
	if not booleans.has(variable_name):
		# Returning a safe default value prevents errors if a key hasn't been set yet.
		return false
	return booleans[variable_name]

## (Optional) A function to register/initialize booleans at the start of the game.
# func register_boolean(variable_name: StringName, initial_value: bool = false):
# 	if not booleans.has(variable_name):
# 		  booleans[variable_name] = initial_value

# Example of how you might initialize some variables on startup:
# func _ready():
# 	  register_boolean("red_key_collected", false)
# 	  register_boolean("secret_door_unlocked", false)
