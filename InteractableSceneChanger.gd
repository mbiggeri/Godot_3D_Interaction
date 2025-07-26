# ShaderTransitionSceneChanger.gd
# IMPORTANT: This script is designed for Godot 4.x and uses async/await features.
# It will not work correctly in Godot 3.x without modification.

# Extends the user-provided Interactable base class.
# This script handles transitioning to a new scene with a customizable shader effect
# applied to a ColorRect covering the screen.
extends Interactable

class_name ShaderTransitionSceneChanger

## GROUP: Scene Change & Shader Effect
## This group contains settings for the scene to load and the visual shader effect.
@export_group("Scene Change & Shader Effect")

## The path to the scene file (.tscn) to load after interaction.
@export_file("*.tscn") var next_scene_path: String = ""

## The ColorRect node that covers the screen and will have the transition shader applied.
## This ColorRect should typically be a child of a CanvasLayer set to layer 1 or higher
## to ensure it draws on top of other UI elements if necessary.
@export var transition_effect_rect: ColorRect = null

## The ShaderMaterial resource to use for the transition effect.
## This material should contain a shader with a float uniform that can be animated
## (e.g., for pixelation size, fade alpha, distortion amount).
@export var transition_shader_material: ShaderMaterial = null

## The name of the 'float' uniform parameter within the transition_shader_material
## that controls the intensity or progress of the shader effect.
## Example: "pixel_size", "fade_amount", "distortion_level".
@export var shader_float_param_name: String = "effect_amount"

## The starting value for the shader's float parameter at the beginning of the transition.
@export var shader_float_param_start_value: float = 0.0

## The end value for the shader's float parameter when the transition effect is at its peak.
@export var shader_float_param_end_value: float = 1.0

## The duration (in seconds) for the shader effect animation to complete.
@export_range(0.1, 10.0, 0.05) var shader_effect_duration: float = 1.0

## An optional delay (in seconds) after the shader effect completes before the scene changes.
@export_range(0.0, 5.0, 0.1) var delay_before_scene_change: float = 0.25


# Internal variable to store the preloaded scene resource.
var _preloaded_scene: PackedScene = null
# Flag to prevent multiple simultaneous interactions.
var _is_interacting: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	# super._ready() # Call the base class's _ready if it has one.
	
	# Attempt to start preloading the target scene.
	# This helps make the actual scene change faster when 'interact' is called.
	if not next_scene_path.is_empty():
		ResourceLoader.load_threaded_request(next_scene_path)
		print("%s: Preload request started for scene '%s'." % [name, next_scene_path])
	else:
		printerr("%s: 'Next Scene Path' is not set. Cannot preload scene." % name)

	# Configure the Transition Effect ColorRect.
	if transition_effect_rect:
		transition_effect_rect.visible = false # Ensure it's hidden initially.
		
		if transition_shader_material:
			# Apply the specified shader material if it's not already the correct one or if none is set.
			if transition_effect_rect.material != transition_shader_material:
				transition_effect_rect.material = transition_shader_material
			print("%s: Transition Effect Rect configured with the provided ShaderMaterial." % name)
		else:
			# If no specific shader material is provided via export,
			# check if the ColorRect already has a ShaderMaterial assigned.
			# If it does, assume it's the correct one.
			if transition_effect_rect.material is ShaderMaterial:
				print("%s: Transition Shader Material not specified, using existing material on ColorRect." % name)
			else:
				printerr("%s: Transition Shader Material not assigned, and the Transition Effect Rect does not have a ShaderMaterial. The shader effect might not work." % name)
	else:
		printerr("%s: Transition Effect Rect not assigned. The shader effect cannot be applied." % name)


# Overrides the 'interact' function from the base Interactable class.
# This function is called when the player interacts with this object.
func interact(_interactor = null) -> void:
	# Prevent interaction if 'can_interact' is false (from base class) or if an interaction is already in progress.
	if not can_interact or _is_interacting:
		if _is_interacting:
			print("%s: Interaction already in progress." % name)
		# The base Interactable class already prints a message if can_interact is false.
		super.interact(_interactor) # Call the base function for its logic (e.g., printing, emitting signal).
		return

	# Check if a scene path is provided.
	if next_scene_path.is_empty():
		printerr("%s: 'Next Scene Path' is not set. Cannot change scene." % name)
		super.interact(_interactor) # Call the base function.
		return

	_is_interacting = true
	can_interact = false # Prevent further interactions while this one is processing.

	# Call the base class's interact method to ensure its logic (like emitting 'interacted' signal) is executed.
	super.interact(_interactor) 
	
	print("%s: Interaction started. Preparing shader effect and scene change to: %s" % [name, next_scene_path])

	# Start the visual effect and scene change process asynchronously.
	# Using 'call_deferred' to start the async function to avoid potential issues if 'interact'
	# was called from a context where 'await' might not be immediately safe (e.g., certain signal callbacks).
	call_deferred("_start_shader_effect_and_scene_change")


# Asynchronous function to handle the shader effect animation and then the scene change.
func _start_shader_effect_and_scene_change():
	# --- 1. Apply Shader Effect ---
	var effect_applied_successfully: bool = false
	
	# Check if the Transition Effect Rect and its ShaderMaterial are properly set up.
	if transition_effect_rect and \
	   transition_effect_rect.material and \
	   transition_effect_rect.material is ShaderMaterial:
		
		var shader_mat := transition_effect_rect.material as ShaderMaterial
		
		# Verify that the shader has the specified float uniform parameter.
		var has_shader_param: bool = false
		
		# Access the Shader resource from the ShaderMaterial
		if shader_mat.shader: # Check if a Shader resource is assigned
			var shader_resource: Shader = shader_mat.shader
			# In Godot 4.x, get_shader_uniform_list() is a method of the Shader resource.
			# It returns an array of dictionaries, each describing a uniform.
			# Each dictionary should have a 'name' key for the uniform's name.
			var uniform_list: Array = shader_resource.get_shader_uniform_list(true) # true to include groups
			for param_info in uniform_list:
				if param_info.has("name") and param_info.name == shader_float_param_name:
					# Further check if it's a float type if necessary, though for setting it's often flexible.
					# For example, check param_info.type == Shader.UNIFORM_TYPE_FLOAT or similar if strict typing is needed.
					# For now, just matching the name.
					has_shader_param = true
					break
		else:
			printerr("%s: The ShaderMaterial does not have an actual Shader resource assigned to it." % name)

		if has_shader_param:
			transition_effect_rect.visible = true # Make the ColorRect visible.
			# Set the initial value for the shader parameter.
			shader_mat.set_shader_parameter(shader_float_param_name, shader_float_param_start_value)

			# Create a Tween to animate the shader parameter.
			var tween: Tween = get_tree().create_tween()
			# Animate the shader parameter from its start value to its end value over the specified duration.
			tween.tween_property(
				shader_mat, "shader_parameter/" + shader_float_param_name, 
				shader_float_param_end_value, 
				shader_effect_duration
			).from(shader_float_param_start_value) # Explicitly set the starting point for the tween.
			
			# Wait for the tween animation to complete.
			await tween.finished
			print("%s: Shader effect animation completed." % name)
			effect_applied_successfully = true
		else:
			if shader_mat.shader: # Only print this specific error if the shader resource existed
				printerr("%s: The Shader resource does not have a float uniform named '%s'. Cannot animate shader effect. The Transition Effect Rect will only be made visible." % [name, shader_float_param_name])
			transition_effect_rect.visible = true # Still make the rect visible if possible.
			effect_applied_successfully = true # Consider the effect "applied" (visible) even if not animated.
			
	else: # Handle errors or missing setup for the shader effect.
		if not transition_effect_rect:
			print("%s: Transition Effect Rect not set. Shader effect skipped." % name)
		elif not transition_effect_rect.material:
			print("%s: Transition Effect Rect has no material. Shader effect skipped." % name)
		elif not transition_effect_rect.material is ShaderMaterial:
			print("%s: Material on Transition Effect Rect is not a ShaderMaterial. Shader effect skipped." % name)

	# If the shader effect was applied (even if just made visible), wait for the specified delay.
	if effect_applied_successfully and delay_before_scene_change > 0.0:
		print("%s: Waiting for %.2f seconds before scene change." % [name, delay_before_scene_change])
		await get_tree().create_timer(delay_before_scene_change).timeout
	elif not effect_applied_successfully and delay_before_scene_change > 0.0:
		# If the effect wasn't applied but there's a delay, we might choose to skip it.
		print("%s: Shader effect not applied, skipping delay before scene change." % name)

	# --- 2. Load and Change Scene ---
	print("%s: Attempting to change scene to '%s'." % [name, next_scene_path])
	
	# Check the status of the threaded resource loading.
	var load_status = ResourceLoader.load_threaded_get_status(next_scene_path)
	
	if _preloaded_scene: # If the scene resource was already obtained (e.g., from a previous _process check or rapid re-interaction)
		print("%s: Using already obtained preloaded scene resource." % name)
		_perform_scene_change(_preloaded_scene)
	elif load_status == ResourceLoader.THREAD_LOAD_LOADED:
		# If loading is complete, get the resource.
		_preloaded_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
		if _preloaded_scene:
			print("%s: Scene successfully loaded in background. Changing now." % name)
			_perform_scene_change(_preloaded_scene)
		else:
			printerr("%s: Failed to retrieve preloaded scene resource even though status was LOADED. Attempting direct load." % name)
			_fallback_direct_scene_load()
	elif load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# If loading is still in progress, wait for it to complete.
		print("%s: Scene is still loading in the background. Waiting..." % name)
		while ResourceLoader.load_threaded_get_status(next_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame # Wait for one frame and re-check.
		
		# Re-check status after waiting.
		load_status = ResourceLoader.load_threaded_get_status(next_scene_path)
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			_preloaded_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
			if _preloaded_scene:
				print("%s: Scene finished loading in background after waiting. Changing now." % name)
				_perform_scene_change(_preloaded_scene)
			else:
				printerr("%s: Failed to retrieve preloaded scene resource after waiting. Attempting direct load." % name)
				_fallback_direct_scene_load()
		else:
			printerr("%s: Scene failed to load in background after waiting. Status: %s. Attempting direct load." % [name, load_status])
			_fallback_direct_scene_load()
	else: # Handle other statuses: THREAD_LOAD_INVALID_RESOURCE, THREAD_LOAD_FAILED, or request not started.
		printerr("%s: Preloaded scene not available or failed (Status: %s). Attempting direct load." % [name, load_status])
		_fallback_direct_scene_load()

# Helper function to perform the actual scene change using a PackedScene resource.
func _perform_scene_change(scene_resource: PackedScene):
	var error_code = get_tree().change_scene_to_packed(scene_resource)
	if error_code != OK:
		printerr("%s: Error changing to preloaded scene: %s." % [name, error_code])
		# Reset state to allow another interaction attempt if scene change fails.
		_is_interacting = false
		can_interact = true 

# Helper function for a fallback direct scene load if threaded loading fails or is not available.
func _fallback_direct_scene_load():
	print("%s: Using direct load for scene: '%s'." % [name, next_scene_path])
	var error_code = get_tree().change_scene_to_file(next_scene_path)
	if error_code != OK:
		printerr("%s: Error changing scene with change_scene_to_file: %s." % [name, error_code])
		# Reset state to allow another interaction attempt.
		_is_interacting = false
		can_interact = true
		
# Optional: Monitor preload progress in _process if detailed feedback is needed.
# This is commented out by default as it can be verbose.
# var _preload_progress_array = [] # Must be an array for load_threaded_get_status with progress.
# func _process(delta):
	# # Only run if the scene resource hasn't been fetched yet, path is valid, and it's not already cached by ResourceLoader.
	# if not _preloaded_scene and not next_scene_path.is_empty() and not ResourceLoader.has_cached(next_scene_path):
		# var status = ResourceLoader.load_threaded_get_status(next_scene_path, _preload_progress_array)
		# match status:
			# ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# if _preload_progress_array and _preload_progress_array.size() > 0:
					# # Print progress, perhaps only if it changes significantly to avoid spam.
					# var current_progress = int(_preload_progress_array[0] * 100)
					# # You might want to store previous_progress to compare.
					# print("%s: Preloading in progress: %s%%" % [name, current_progress])
			# ResourceLoader.THREAD_LOAD_LOADED:
				# _preloaded_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
				# if _preloaded_scene:
					# print("%s: Scene '%s' preloaded successfully and resource obtained." % [name, next_scene_path])
				# else:
					# printerr("%s: Failed to get PackedScene for '%s' after threaded loading." % [name, next_scene_path])
			# ResourceLoader.THREAD_LOAD_FAILED:
				# printerr("%s: Failed to preload scene '%s'." % [name, next_scene_path])
				# # It might be useful to stop checking here for this scene.
			# ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				# printerr("%s: Invalid resource path for preloading: '%s'." % [name, next_scene_path])
				# # Stop checking.
