# Interactable.gd
class_name Interactable
extends Node3D

## Emitted when the object has been successfully interacted with.
signal interacted

## If false, the object cannot be interacted with or highlighted.
@export var can_interact: bool = true

# --- Highlighting Properties ---
@export_group("Highlighting")
@export_subgroup("Setup")
## The MeshInstance3D node to highlight.
@export var mesh_to_highlight: MeshInstance3D = null
## The material surface index on the mesh to modify (usually 0).
@export var material_surface_index: int = 0

@export_subgroup("Appearance")
## The color to use for the highlight effect.
@export var highlight_color: Color = Color.WHITE_SMOKE
## If true, the highlight will also use emission for a glowing effect.
@export var use_emission_for_highlight: bool = true
## The strength of the emission if `use_emission_for_highlight` is enabled.
@export var highlight_emission_strength: float = 0.2

# --- Audio Properties ---
@export_group("Audio")
## A reference to the node that will play the interaction sound.
@export var audio_player_node: AudioStreamPlayer3D
## The sound to play upon successful interaction.
@export var interaction_sound: AudioStream

# Caches the original material to restore it later.
var _original_material_cache: Material = null
# Tracks if the object is currently being highlighted by this script.
var _is_currently_highlighted: bool = false


##
## The main interaction function, called by the interactor (e.g., the player).
## Classes that inherit from Interactable should override this method
## to define their specific behavior.
##
func interact(_interactor: Node = null) -> void:
	if not can_interact:
		print(name + " cannot be interacted with right now.")
		return

	print(name + " was interacted with.")

	# Play the interaction sound if configured.
	if audio_player_node and interaction_sound:
		audio_player_node.stream = interaction_sound
		audio_player_node.play()

	emit_signal("interacted")


##
## Provides feedback (highlighting) when the interactor focuses on the object.
##
func on_focus() -> void:
	# --- Pre-check for highlighting ---
	if not can_interact:
		return
	if not mesh_to_highlight or not mesh_to_highlight.mesh:
		printerr(name + ": Cannot highlight because 'mesh_to_highlight' or its mesh resource is not assigned.")
		return
	if _is_currently_highlighted:
		return
	if material_surface_index < 0 or material_surface_index >= mesh_to_highlight.mesh.get_surface_count():
		printerr(name + ": Invalid 'material_surface_index' (" + str(material_surface_index) + ") for the mesh.")
		return

	# --- Apply Highlight ---
	# Cache the original material so we can restore it later.
	_original_material_cache = mesh_to_highlight.get_active_material(material_surface_index)

	var material_for_highlight: StandardMaterial3D

	# If the original material is a StandardMaterial3D, duplicate it to preserve its properties (like textures).
	# Otherwise, create a new blank StandardMaterial3D for the highlight.
	if _original_material_cache is StandardMaterial3D:
		material_for_highlight = (_original_material_cache as StandardMaterial3D).duplicate(true) as StandardMaterial3D
	else:
		material_for_highlight = StandardMaterial3D.new()
		
	# Configure the highlight material's appearance.
	material_for_highlight.albedo_color = highlight_color
	
	if use_emission_for_highlight:
		material_for_highlight.emission_enabled = true
		material_for_highlight.emission = highlight_color * highlight_emission_strength
	else:
		# Ensure emission is disabled if not used, especially when duplicating a material that had it enabled.
		material_for_highlight.emission_enabled = false
		material_for_highlight.emission = Color.BLACK

	# Apply the new/modified material and update the state.
	mesh_to_highlight.set_surface_override_material(material_surface_index, material_for_highlight)
	_is_currently_highlighted = true


##
## Removes the feedback (highlighting) when the interactor stops focusing on the object.
##
func on_unfocus() -> void:
	if not _is_currently_highlighted:
		return

	# --- Safety checks before attempting to restore ---
	# These checks are defensive, in case the node was modified while highlighted.
	if not mesh_to_highlight or not mesh_to_highlight.mesh:
		printerr(name + ": Cannot remove highlight, 'mesh_to_highlight' became null.")
		_cleanup_highlight_state()
		return
	if material_surface_index < 0 or material_surface_index >= mesh_to_highlight.mesh.get_surface_count():
		printerr(name + ": 'material_surface_index' became invalid while highlighted.")
		_cleanup_highlight_state()
		return

	# Restore the original material. This works even if _original_material_cache is null.
	mesh_to_highlight.set_surface_override_material(material_surface_index, _original_material_cache)
	
	_cleanup_highlight_state()


## Resets the highlighting state variables.
func _cleanup_highlight_state() -> void:
	_original_material_cache = null
	_is_currently_highlighted = false
