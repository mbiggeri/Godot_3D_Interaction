# interactable.gd
class_name Interactable
extends Node3D # O Node2D se stai facendo un gioco 2D, o semplicemente Node per la massima flessibilità

# Segnale emesso quando l'oggetto viene interagito
signal interacted

# Variabile per indicare se l'oggetto può essere interagito al momento
@export var can_interact: bool = true

# --- Proprietà per l'Evidenziazione ---
@export_group("Evidenziazione") # "Highlighting" in originale, tradotto per coerenza
@export_subgroup("Impostazioni") # "Setup"
# La MeshInstance3D da evidenziare.
@export var mesh_to_highlight: MeshInstance3D = null
# L'indice della superficie del materiale da modificare sulla mesh (di solito 0).
@export var material_surface_index: int = 0

@export_subgroup("Aspetto") # "Appearance"
# Il colore da usare per l'evidenziazione.
@export var highlight_color: Color = Color.WHITE_SMOKE
# Se abilitato, l'evidenziazione userà anche l'emissione per un effetto più luminoso.
@export var use_emission_for_highlight: bool = true
# La forza dell'emissione se 'use_emission_for_highlight' è abilitato.
@export var highlight_emission_strength: float = 0.2
# --- Fine Proprietà Evidenziazione ---

# Cache per il materiale originale prima dell'evidenziazione
var _original_material_cache: Material = null
# Flag per tracciare se l'oggetto è attualmente evidenziato da questo script
var _is_currently_highlighted: bool = false


# Questa è la funzione principale che verrà chiamata dal giocatore.
# Le classi che ereditano da Interactable sovrascriveranno questo metodo
# per definire il loro comportamento specifico.
func interact(_interactor = null) -> void:
	if can_interact:
		print(name + " è stato interagito.")
		emit_signal("interacted")
	else:
		print(name + " non può essere interagito al momento.")

# Funzione per fornire un feedback (evidenziazione) quando il giocatore guarda l'oggetto
func on_focus() -> void:
	print(name + " è in focus.")

	if not can_interact:
		print(name + ": Non può essere evidenziato, interazione disabilitata.")
		return
	if not mesh_to_highlight:
		print(name + ": Non può essere evidenziato, 'mesh_to_highlight' non assegnato.")
		return
	if not mesh_to_highlight.mesh: # Controlla se la risorsa mesh stessa esiste
		print(name + ": Non può essere evidenziato, 'mesh_to_highlight' non ha una mesh assegnata.")
		return
	if _is_currently_highlighted:
		#print(name + ": Già evidenziato.") # Descommenta se vuoi questo log
		return
	if material_surface_index < 0 or material_surface_index >= mesh_to_highlight.mesh.get_surface_count():
		printerr(name + ": 'material_surface_index' (" + str(material_surface_index) + ") non valido per la mesh.")
		return

	# Conserva il materiale originale
	_original_material_cache = mesh_to_highlight.get_active_material(material_surface_index)

	var material_for_highlight: StandardMaterial3D

	# Se il materiale originale è uno StandardMaterial3D, duplicalo.
	# Altrimenti, o se non c'è materiale, crea un nuovo StandardMaterial3D.
	if _original_material_cache is StandardMaterial3D:
		# Duplica il materiale (true per duplicare anche le sub-risorse come le texture)
		material_for_highlight = (_original_material_cache as StandardMaterial3D).duplicate(true) as StandardMaterial3D
		if material_for_highlight == null: # Fallback nel caso raro la duplicazione fallisca
			printerr(name + ": Fallimento nella duplicazione di StandardMaterial3D esistente. Creazione di uno nuovo.")
			material_for_highlight = StandardMaterial3D.new()
	else:
		if _original_material_cache != null:
			print(name + ": Il materiale originale non è StandardMaterial3D. Creazione di un nuovo StandardMaterial3D per l'evidenziazione.")
		else:
			print(name + ": Nessun materiale originale. Creazione di un nuovo StandardMaterial3D per l'evidenziazione.")
		material_for_highlight = StandardMaterial3D.new()
			
	# Configura il materiale per l'evidenziazione
	material_for_highlight.albedo_color = highlight_color
	
	if use_emission_for_highlight:
		material_for_highlight.emission_enabled = true
		material_for_highlight.emission = highlight_color * highlight_emission_strength
	else:
		# Assicurati che l'emissione sia disabilitata se non usata per l'evidenziazione.
		# Importante se si duplica un materiale che aveva l'emissione abilitata.
		material_for_highlight.emission_enabled = false
		material_for_highlight.emission = Color.BLACK # Resetta il colore dell'emissione

	# Applica il materiale modificato/nuovo alla mesh
	mesh_to_highlight.set_surface_override_material(material_surface_index, material_for_highlight)
	_is_currently_highlighted = true
	print(name + " evidenziato applicando un materiale nuovo/duplicato.")


# Funzione per rimuovere il feedback (evidenziazione) quando il giocatore smette di guardare l'oggetto
func on_unfocus() -> void:
	print(name + " non è più in focus.")

	if not _is_currently_highlighted:
		# print(name + ": Non era evidenziato da questo script, nessuna azione per rimuovere l'evidenziazione.") # Descommenta se vuoi questo log
		return
		
	# Controlli di sicurezza aggiuntivi prima di tentare di ripristinare
	if not mesh_to_highlight:
		printerr(name + ": Impossibile rimuovere l'evidenziazione, 'mesh_to_highlight' è nullo nonostante fosse evidenziato.")
		_cleanup_highlight_state()
		return
	if not mesh_to_highlight.mesh:
		printerr(name + ": Impossibile rimuovere l'evidenziazione, 'mesh_to_highlight' non ha una mesh assegnata.")
		_cleanup_highlight_state()
		return
	# È possibile che la mesh sia cambiata o l'indice non sia più valido, anche se improbabile
	# Se la mesh ha 0 surface, get_surface_count() è 0. Se material_surface_index è 0, 0 >= 0 è true.
	# Quindi `mesh.get_surface_count() > 0` è una precondizione implicita se `material_surface_index` è valido.
	if material_surface_index < 0 or \
	   (mesh_to_highlight.mesh and material_surface_index >= mesh_to_highlight.mesh.get_surface_count()):
		printerr(name + ": 'material_surface_index' (" + str(material_surface_index) + ") non valido per la mesh durante la rimozione dell'evidenziazione.")
		_cleanup_highlight_state()
		return

	# Ripristina il materiale originale sulla mesh
	# Questo funziona anche se _original_material_cache è null (significa che non c'era materiale prima)
	mesh_to_highlight.set_surface_override_material(material_surface_index, _original_material_cache)
	
	print(name + ": Evidenziazione rimossa, materiale originale ripristinato.")
	_cleanup_highlight_state()


# Pulisce le variabili di stato dell'evidenziazione
func _cleanup_highlight_state() -> void:
	_original_material_cache = null
	_is_currently_highlighted = false

# func _ready():
#     pass
