# ShaderTransitionSceneChanger.gd
# This script handles transitioning to a new scene with a customizable shader effect.
extends Interactable

class_name ShaderTransitionSceneChanger

# --- Scene Change & Shader Effect Properties ---
@export_group("Scene Change & Shader Effect")

## The path to the scene file (.tscn) to load after interaction.
@export_file("*.tscn") var next_scene_path: String = ""

## The ColorRect node that covers the screen for the transition effect.
## This should be a child of a CanvasLayer to ensure it draws on top of everything.
@export var transition_effect_rect: ColorRect = null

## The ShaderMaterial resource to use for the transition.
@export var transition_shader_material: ShaderMaterial = null

## The name of the 'float' uniform parameter inside the shader (e.g., "progress", "fade_amount").
@export var shader_float_param_name: String = "effect_amount"

## The starting value for the shader's float parameter.
@export var shader_float_param_start_value: float = 0.0

## The end value for the shader's float parameter at the effect's peak.
@export var shader_float_param_end_value: float = 1.0

## The duration (in seconds) for the shader effect animation.
@export_range(0.1, 10.0, 0.05) var shader_effect_duration: float = 1.0

## An optional delay (in seconds) after the shader effect completes before the scene changes.
@export_range(0.0, 5.0, 0.1) var delay_before_scene_change: float = 0.25


# Internal variable to store the preloaded scene resource.
var _preloaded_scene: PackedScene = null
# Flag to prevent multiple simultaneous interactions.
var _is_interacting: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Attempt to start preloading the target scene to make the actual scene change faster.
	if not next_scene_path.is_empty():
		ResourceLoader.load_threaded_request(next_scene_path)
	else:
		printerr("%s: 'Next Scene Path' is not set. Cannot preload scene." % name)

	# Configure the transition effect rectangle.
	if transition_effect_rect:
		transition_effect_rect.visible = false # Ensure it's hidden initially.
		if transition_shader_material:
			# Apply the specified shader material.
			transition_effect_rect.material = transition_shader_material
		elif not transition_effect_rect.material is ShaderMaterial:
			# Warn if no shader is provided and the rect doesn't already have one.
			printerr("%s: Transition Shader Material not assigned, and the ColorRect has no existing ShaderMaterial." % name)
	else:
		printerr("%s: 'Transition Effect Rect' is not assigned. The shader effect cannot be applied." % name)


# Overrides the 'interact' function from the base Interactable class.
func interact(_interactor = null) -> void:
	# Prevent interaction if disabled in the base class or if an interaction is already in progress.
	if not can_interact or _is_interacting:
		super.interact(_interactor) # Call base function for its logic (e.g., printing messages).
		return

	if next_scene_path.is_empty():
		printerr("%s: 'Next Scene Path' is not set. Cannot change scene." % name)
		super.interact(_interactor)
		return

	_is_interacting = true
	can_interact = false # Prevent further interactions while this one is processing.

	# Call the base class's interact method to play sounds and emit the signal.
	super.interact(_interactor) 
	
	# Start the visual effect and scene change process asynchronously.
	call_deferred("_start_shader_effect_and_scene_change")


# Asynchronous function to handle the shader effect animation and then the scene change.
func _start_shader_effect_and_scene_change() -> void:
	# --- 1. Apply Shader Effect ---
	var effect_applied_successfully: bool = false
	
	if transition_effect_rect and transition_effect_rect.material is ShaderMaterial:
		var shader_mat := transition_effect_rect.material as ShaderMaterial
		var has_shader_param := false
		
		# Verify that the shader has the specified float uniform parameter.
		if shader_mat.shader:
			var uniform_list: Array = shader_mat.shader.get_shader_uniform_list(true)
			for param_info in uniform_list:
				if param_info.has("name") and param_info.name == shader_float_param_name:
					has_shader_param = true
					break
		
		if has_shader_param:
			transition_effect_rect.visible = true
			shader_mat.set_shader_parameter(shader_float_param_name, shader_float_param_start_value)

			# Create a Tween to animate the shader parameter.
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(
				shader_mat, "shader_parameter/" + shader_float_param_name, 
				shader_float_param_end_value, 
				shader_effect_duration
			).from(shader_float_param_start_value)
			
			# Wait for the tween animation to complete.
			await tween.finished
			effect_applied_successfully = true
		else:
			printerr("%s: The Shader resource does not have a uniform named '%s'." % [name, shader_float_param_name])
			transition_effect_rect.visible = true # Still make the rect visible if possible.
			effect_applied_successfully = true # Consider the effect "applied" even if not animated.
	else:
		printerr("%s: Transition effect setup is invalid. Skipping visual effect." % name)

	# --- 2. Wait for optional delay ---
	if effect_applied_successfully and delay_before_scene_change > 0.0:
		await get_tree().create_timer(delay_before_scene_change).timeout

	# --- 3. Load and Change Scene ---
	# Check the status of the threaded resource loading.
	var load_status = ResourceLoader.load_threaded_get_status(next_scene_path)
	
	if _preloaded_scene:
		# Use the scene if it was already fetched.
		_perform_scene_change(_preloaded_scene)
	elif load_status == ResourceLoader.THREAD_LOAD_LOADED:
		# If loading is complete, get the resource.
		_preloaded_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
		_perform_scene_change(_preloaded_scene)
	elif load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# If loading is still in progress, wait for it to complete.
		while ResourceLoader.load_threaded_get_status(next_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame # Wait for one frame and re-check.
		
		_preloaded_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
		_perform_scene_change(_preloaded_scene)
	else:
		# Handle other statuses (e.g., failed, invalid) by falling back to a direct load.
		printerr("%s: Preloaded scene not available or failed. Attempting direct load." % name)
		_fallback_direct_scene_load()


# Helper function to perform the actual scene change using a PackedScene resource.
func _perform_scene_change(scene_resource: PackedScene) -> void:
	if not scene_resource:
		printerr("%s: Failed to get PackedScene resource. Aborting scene change." % name)
		_fallback_direct_scene_load() # Attempt a fallback
		return

	var error_code = get_tree().change_scene_to_packed(scene_resource)
	if error_code != OK:
		printerr("%s: Error changing to preloaded scene: %s." % [name, error_code])
		# Reset state to allow another interaction attempt if scene change fails.
		_is_interacting = false
		can_interact = true 

# Helper function for a fallback direct scene load if threaded loading fails.
func _fallback_direct_scene_load() -> void:
	print("%s: Using direct load for scene: '%s'." % [name, next_scene_path])
	var error_code = get_tree().change_scene_to_file(next_scene_path)
	if error_code != OK:
		printerr("%s: Error changing scene with change_scene_to_file: %s." % [name, error_code])
		# Reset state to allow another interaction attempt.
		_is_interacting = false
		can_interact = true
