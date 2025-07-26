# InteractionRayController.gd
# Attacca questo script al tuo nodo RayCast3D, che dovrebbe essere figlio del Giocatore/Interactor.
extends RayCast3D

signal focused_interactable_changed(new_interactable: Interactable)

var current_interactable_in_focus: Interactable = null
var active: bool = true:
	set(value):
		active = value
		enabled = value # Assicurati che il RayCast3D sia abilitato/disabilitato con 'active'
		if not active and current_interactable_in_focus:
			current_interactable_in_focus.on_unfocus()
			current_interactable_in_focus = null
			emit_signal("focused_interactable_changed", null)

# Riferimento a chi sta compiendo l'interazione (solitamente il genitore del RayCast).
# Può essere impostato dall'editor o dedotto.
@export var interactor: Node3D = null # O Node, a seconda del tipo di interactor

func _ready() -> void:
	enabled = active
	# Se l'interactor non è impostato esplicitamente, prova a prenderlo dal genitore.
	if interactor == null:
		var parent_node = get_parent()
		# Controlla se il genitore è un Node3D (o il tipo base del tuo giocatore)
		if parent_node is Node3D: 
			interactor = parent_node
			print_debug("InteractionRayController: Interactor impostato automaticamente su: ", interactor.name)
		# else: # Rimosso il printerr per evitare spam se l'interactor viene impostato più tardi o da un altro script
			# printerr("InteractionRayController: 'Interactor' non impostato e impossibile dedurlo dal genitore.")
			
	# Potresti voler verificare il tipo di interactor qui se necessario, ma non è strettamente obbligatorio
	# elif not interactor is Node3D:
	#     printerr("InteractionRayController: 'Interactor' assegnato non è del tipo atteso (es. Node3D).")


func _physics_process(_delta: float) -> void:
	if not active:
		return

	var new_focused_object: Interactable = null

	if is_colliding():
		var collider = get_collider()
		# Assicurati che il collider sia un Interactable prima di fare il cast
		if collider is Interactable:
			var interactable_collider = collider as Interactable # Cast sicuro
			if interactable_collider.can_interact:
				new_focused_object = interactable_collider
	 
	if new_focused_object != current_interactable_in_focus:
		if current_interactable_in_focus != null:
			current_interactable_in_focus.on_unfocus()
		 
		current_interactable_in_focus = new_focused_object
		 
		if current_interactable_in_focus != null:
			current_interactable_in_focus.on_focus()
			 
		emit_signal("focused_interactable_changed", current_interactable_in_focus)

# Gestisce l'input per l'interazione
func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	# Non è strettamente necessario controllare interactor == null qui se vuoi che
	# l'input sia comunque consumato, ma è buona pratica per l'azione di interazione.
	if interactor == null and current_interactable_in_focus != null :
		# Stampa un avviso se si tenta di interagire senza un interactor definito
		# (potrebbe accadere se l'interactor viene rimosso durante il gioco)
		if event.is_action_pressed("interact"):
			printerr("InteractionRayController: Tentativo di interazione ma 'interactor' è null.")
		return

	if current_interactable_in_focus != null and event.is_action_pressed("interact"):
		print_debug("InteractionRayController: 'interact' action pressed on ", current_interactable_in_focus.name)
		
		# --- MODIFICA CHIAVE ---
		# Consuma l'input PRIMA di eseguire l'azione che potrebbe cambiare la scena o invalidare il nodo.
		get_viewport().set_input_as_handled() 
		
		current_interactable_in_focus.interact(interactor) # Passa l'interactor
		
		# NOTA: Non mettere altro codice qui che dipenda dalla validità della scena corrente
		# se la chiamata a interact() qui sopra ha causato un cambio di scena.

# Metodo pubblico per ottenere l'oggetto attualmente in focus (se necessario altrove)
func get_focused_interactable() -> Interactable:
	return current_interactable_in_focus

# Setter esplicito per 'active' se preferisci chiamarlo come metodo
# La proprietà setter definita sopra con `active: bool = true:` gestisce già questo.
# Quindi questa funzione duplicata può essere rimossa se la proprietà setter è sufficiente.
# func set_active(is_active: bool) -> void:
#     active = is_active
