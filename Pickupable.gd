# pickupable.gd
# Estende la classe Interactable per creare oggetti che possono essere raccolti e ispezionati.
# Modificato per bloccare l'input e attendere un input di chiusura dopo un timer.
class_name Pickupable
extends Interactable

# Segnale emesso quando l'oggetto viene "riposto".
# Il sistema di inventario può ascoltare questo segnale per aggiungere l'oggetto.
# Passa questo stesso nodo come argomento, così l'inventario può leggerne i dati.
signal stored(item)

# Enum per gestire lo stato corrente dell'oggetto.
enum State {
	IN_WORLD,      # Nello scenario, può essere raccolto.
	BEING_VIEWED,  # Tenuto di fronte alla telecamera per ispezione.
	STORED         # Riposto nell'inventario (e rimosso dalla scena).
}

# Variabili per l'ispezione dell'oggetto.
@export_group("Pickupable Settings")
# Velocità di rotazione quando si ispeziona l'oggetto con il mouse.
@export var inspection_rotation_speed: float = 0.2
# Il fattore di zoom (quanto vicino alla camera appare l'oggetto).
@export var inspection_zoom: float = 1.0
# Durata in secondi del blocco dell'input iniziale, durante il quale l'oggetto non può essere riposto.
@export var inspection_lock_duration: float = 3.0
# --- Variabili private ---
var _dynamic_hold_point: Node3D
var _current_state: State = State.IN_WORLD
var _original_parent: Node
var _current_interactor = null # Memorizza l'interactor per un uso successivo.

# Variabili per la logica di blocco input
var _inspection_timer: Timer
var _is_inspection_locked: bool = false


# Sovrascriviamo la funzione 'interact' della classe base.
func interact(interactor = null) -> void:
	if not can_interact:
		return

	# L'interazione è permessa solo quando l'oggetto è nel mondo.
	# Per riporlo si usa ora la gestione degli input generici.
	if _current_state == State.IN_WORLD:
		var camera = get_viewport().get_camera_3d()
		if camera:
			_pickup_item(interactor, camera)
		else:
			printerr(name + ": Impossibile trovare una camera 3D attiva nella scena.")


# Gestisce l'input per la rotazione e per riporre l'oggetto.
func _unhandled_input(event: InputEvent) -> void:
	# Elaboriamo l'input solo se stiamo ispezionando l'oggetto.
	if _current_state != State.BEING_VIEWED:
		return

	# CASO 1: L'evento è il movimento del mouse. Lo usiamo per la rotazione.
	if event is InputEventMouseMotion:
		# Ruota l'oggetto in base al movimento relativo del mouse.
		self.rotate_y(deg_to_rad(-event.relative.x * inspection_rotation_speed))
		self.rotate_x(deg_to_rad(-event.relative.y * inspection_rotation_speed))

		# Limitiamo la rotazione sull'asse X per evitare che si capovolga completamente.
		var clamped_rotation_x = clamp(self.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		self.rotation.x = clamped_rotation_x
		
		# Consumiamo l'evento per evitare che la camera si muova.
		get_viewport().set_input_as_handled()
		return

	# CASO 2: L'ispezione è bloccata dal timer.
	# Ignoriamo e consumiamo qualsiasi altro input.
	if _is_inspection_locked:
		get_viewport().set_input_as_handled()
		return
		
	# CASO 3: L'ispezione non è più bloccata e riceviamo un input.
	# Usiamo questo input per riporre l'oggetto.
	# Controlliamo 'is_pressed()' per attivarlo solo alla pressione, non al rilascio.
	if event.is_pressed():
		print("Input di chiusura ricevuto, oggetto riposto.")
		_store_item(_current_interactor)
		get_viewport().set_input_as_handled()


# --- FUNZIONI PRIVATE ---

# Logica per raccogliere l'oggetto.
func _pickup_item(interactor, camera: Camera3D) -> void:
	print(name + " è stato raccolto per l'ispezione.")
	_current_state = State.BEING_VIEWED
	_current_interactor = interactor
	
	# Rimuoviamo l'evidenziazione se presente.
	if _is_currently_highlighted:
		super.on_unfocus()
	
	# Disabilitiamo fisica e collisioni.
	# if self is RigidBody3D:
	# 	self.freeze = true
	var collision_shape = find_child("CollisionShape3D", true, false)
	if collision_shape:
		collision_shape.disabled = true
	
	# Creiamo il punto di ancoraggio e vi attacchiamo l'oggetto.
	_dynamic_hold_point = Node3D.new()
	camera.add_child(_dynamic_hold_point)
	_original_parent = get_parent()
	if _original_parent:
		_original_parent.remove_child(self)
	_dynamic_hold_point.add_child(self)

	# Posizioniamo l'oggetto istantaneamente di fronte alla camera.
	self.position = Vector3(0, 0, -inspection_zoom)
	self.rotation = Vector3.ZERO
	
	# Avviamo il blocco dell'input e il timer.
	_is_inspection_locked = true
	_inspection_timer = Timer.new()
	add_child(_inspection_timer)
	_inspection_timer.wait_time = inspection_lock_duration
	_inspection_timer.one_shot = true
	_inspection_timer.timeout.connect(_on_inspection_lock_timeout)
	_inspection_timer.start()
	print("Ispezione bloccata per " + str(inspection_lock_duration) + " secondi.")

	# Notifichiamo all'interactor (giocatore) di disabilitare i suoi input (movimento, etc).
	if interactor and interactor.has_method("set_is_holding"):
		interactor.set_is_holding(true)

# Chiamato quando il timer di blocco ispezione finisce.
func _on_inspection_lock_timeout() -> void:
	_is_inspection_locked = false
	print("Ispezione sbloccata. Premi un tasto o clicca per riporre l'oggetto.")


# Logica per riporre l'oggetto.
func _store_item(interactor) -> void:
	# Assicuriamoci che non venga eseguito più volte.
	if _current_state == State.STORED:
		return
		
	print(name + " è stato riposto.")
	_current_state = State.STORED
	can_interact = false
	
	# Emettiamo il segnale per l'inventario.
	emit_signal("stored", self)

	# Notifichiamo al giocatore che può riprendere il controllo.
	if interactor and interactor.has_method("set_is_holding"):
		interactor.set_is_holding(false)
	
	# Pulizia dei nodi creati dinamicamente.
	if _dynamic_hold_point:
		_dynamic_hold_point.queue_free()
	
	if _inspection_timer:
		_inspection_timer.queue_free()
		
	# Rimuoviamo l'oggetto dalla scena.
	self.queue_free()
