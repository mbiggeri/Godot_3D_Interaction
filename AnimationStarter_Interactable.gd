# AnimatedInteractable.gd
extends Interactable
class_name AnimatedInteractable

## L'AnimationPlayer che controllerà le animazioni.
## Assegna questo dall'Inspector.
@export var animation_player: AnimationPlayer

## Il nome dell'animazione da riprodurre (o l'animazione "in avanti" per il toggle).
## Specifica questo nome nell'Inspector. Usa StringName per performance migliori.
@export var animation_name: StringName = ""

## Se true, l'interazione alternerà l'animazione (avanti/indietro).
@export var can_toggle: bool = false

## Nome dell'animazione "inversa" per il toggle.
## Se vuoto e can_toggle è true, l'animazione principale ('animation_name') verrà riprodotta al contrario.
@export var animation_name_reverse: StringName = ""

## Se true, l'oggetto potrà essere interagito solo una volta (per avviare un'animazione).
@export var one_time_interaction: bool = false

## Se true, e l'AnimationPlayer è già occupato a riprodurre QUALSIASI animazione,
## l'interazione (inclusa questa animazione) verrà ignorata per permettere il completamento dell'animazione corrente.
## Se false, questa animazione cercherà di partire, potenzialmente interrompendo quella in corso (comportamento standard di AnimationPlayer).
@export var prevent_retrigger_if_playing: bool = true

## [NUOVO] Nome della variabile booleana globale che deve essere true per permettere l'interazione.
## Lascia vuoto per non richiedere alcuna variabile globale.
@export var require_global_bool_name: StringName = ""

## [NUOVO] Nome della variabile booleana globale da impostare a true dopo un'interazione riuscita.
## Lascia vuoto per non impostare alcuna variabile globale.
@export var set_global_bool_on_interact_name: StringName = ""


# Traccia l'animazione specifica che questo script ha avviato e sta attendendo che finisca.
var _current_animation_playing_by_this: StringName = ""
# Stato per la logica di toggle (es. true se l'oggetto è "acceso" o nello stato post-animazione-normale)
var _is_toggled_on: bool = false


func _ready() -> void:
	# Validazione della configurazione critica
	if not animation_player:
		printerr("ERRORE (", name, "): AnimatedInteractable - 'Animation Player' non assegnato nell'Inspector!")
		can_interact = false # Disabilita l'interazione se la configurazione critica manca
		printerr("ERRORE (", name, "): AnimatedInteractable - Interazione disabilitata a causa di Animation Player mancante.")
		return

	# Connessione al segnale animation_finished per tracciare il completamento delle "nostre" animazioni.
	if not animation_player.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animation_player.animation_finished.connect(self._on_animation_finished) # [MODIFICATO] Rimosso Callable() ridondante per Godot 4+

	# Avviso se il nome dell'animazione principale non è specificato, poiché è spesso necessario.
	if animation_name == "":
		printerr("AVVISO (", name, "): AnimatedInteractable - 'Animation Name' principale non specificato. L'oggetto potrebbe non animarsi come previsto, specialmente se 'can_toggle' è attivo e 'animation_name_reverse' non è usato o se 'can_toggle' è false.")

	# [NUOVO] Avviso se l'Autoload GlobalBooleans non è disponibile e si tenta di usarlo
	if (require_global_bool_name != "" or set_global_bool_on_interact_name != "") and not Engine.has_singleton("GlobalBooleans"):
		printerr("ERRORE (", name, "): AnimatedInteractable - L'Autoload 'GlobalBooleans' non è configurato nel progetto, ma richiesto da questo nodo.")
		printerr("INFO (", name, "): AnimatedInteractable - Le funzionalità legate ai booleani globali saranno disabilitate.")
		# Potresti voler disabilitare l'interazione qui o gestire l'errore in modo più specifico
		# can_interact = false


func _exit_tree() -> void:
	# Disconnetti il segnale quando il nodo esce dall'albero per evitare potenziali errori.
	if animation_player and animation_player.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		animation_player.animation_finished.disconnect(self._on_animation_finished) # [MODIFICATO] Rimosso Callable() ridondante


func _on_animation_finished(anim_name: StringName) -> void:
	# Se l'animazione completata è quella che stavamo tracciando specificamente:
	if anim_name == _current_animation_playing_by_this:
		_current_animation_playing_by_this = "" # Resetta, permettendo una nuova interazione animata da questo script.
		print("INFO (", name, "): AnimatedInteractable - Animazione '", anim_name, "' (avviata da questo script) completata.")


# Sovrascrivi la funzione interact per aggiungere la logica dell'animazione.
func interact(_interactor = null) -> void:
	# 1. Controlla se l'interazione è possibile secondo la logica della classe base.
	if not can_interact:
		super.interact(_interactor) # Lascia che la classe base stampi "non può essere interagito"
		return

	# [NUOVO] 1.5 Controlla il requisito della variabile globale booleana
	if require_global_bool_name != "":
		var required_value = GlobalBooleans.get_global_bool(require_global_bool_name)
		if not required_value:
			# Puoi decidere se chiamare super.interact() per emettere un segnale di "tentata interazione bloccata"
			# o semplicemente non fare nulla. Per ora, non facciamo nulla.
			return

	# 2. Controlli di configurazione e stato preliminari.
	if not animation_player:
		printerr("ERRORE (", name, "): AnimatedInteractable - AnimationPlayer non configurato (dovrebbe essere stato rilevato in _ready). Interazione annullata.")
		return

	# 3. Gestione del completamento delle animazioni:
	#    Parte A: Se QUESTO script ha già un'animazione specifica in corso, non interferire.
	if _current_animation_playing_by_this != "":
		print("INFO (", name, "): AnimatedInteractable - Animazione '", _current_animation_playing_by_this, "' avviata da questo script è ancora in corso. Interazione ignorata.")
		return

	#    Parte B: Se `prevent_retrigger_if_playing` è true e l'AnimationPlayer
	#    è occupato da QUALSIASI animazione, non fare nulla per rispettare l'animazione corrente.
	if prevent_retrigger_if_playing and animation_player.is_playing():
		print("INFO (", name, "): AnimatedInteractable - AnimationPlayer è attualmente occupato con '", animation_player.current_animation, "' e 'prevent_retrigger_if_playing' è attivo. Interazione ignorata.")
		return

	# 4. Determina quale animazione riprodurre e come, in base alla logica di toggle.
	var anim_to_play_effective: StringName = ""
	var anim_custom_speed: float = 1.0
	var anim_from_end_flag: bool = false
	var needs_valid_animation_name: bool = true # Flag per tracciare se ci aspettiamo un nome di animazione valido

	if can_toggle:
		if not _is_toggled_on: # Stato attuale: "spento" (es. porta chiusa), azione: "accendi" (apri)
			anim_to_play_effective = animation_name
		else: # Stato attuale: "acceso" (es. porta aperta), azione: "spegni" (chiudi)
			if animation_name_reverse != "": # Se è specificata un'animazione inversa, usa quella.
				anim_to_play_effective = animation_name_reverse
			elif animation_name != "": # Altrimenti, prova a usare l'animazione principale al contrario.
				anim_to_play_effective = animation_name
				anim_custom_speed = -1.0
				anim_from_end_flag = true
			else: # animation_name è vuoto, non c'è nulla da riprodurre al contrario.
				needs_valid_animation_name = false
	else: # Logica non-toggle (originale)
		anim_to_play_effective = animation_name

	# Se, dopo la logica sopra, non abbiamo un nome di animazione effettivo,
	# significa che non c'è animazione da riprodurre per questa interazione.
	if anim_to_play_effective == "": # [MODIFICATO] Controllo più diretto
		needs_valid_animation_name = false

	# 5. Se tutti i controlli preliminari sono superati, esegui l'interazione base.
	#    Questo emetterà il segnale "interacted" e stamperà il messaggio base.
	super.interact(_interactor)

	# 6. Esegui la logica dell'animazione.
	if not needs_valid_animation_name:
		# Se non serve un nome di animazione valido (perché era vuoto),
		# ma l'animation_player è assegnato, stampa un avviso.
		if animation_player: # [MODIFICATO] Tolto 'and animation_player' perché già controllato sopra (ma è innocuo)
			printerr("AVVISO (", name, "): AnimatedInteractable - Nessun 'Nome Animazione' valido specificato per l'azione corrente (controlla 'animation_name' e 'animation_name_reverse' se 'can_toggle' è attivo). L'interazione è avvenuta (segnale emesso), ma nessuna animazione verrà riprodotta da questo script.")
	elif not animation_player.has_animation(anim_to_play_effective):
		printerr("ERRORE (", name, "): AnimatedInteractable - Animazione '", anim_to_play_effective, "' NON trovata nell'AnimationPlayer.")
	else:
		# Tutto pronto per riprodurre l'animazione
		animation_player.play(anim_to_play_effective, -1, anim_custom_speed, anim_from_end_flag)
		_current_animation_playing_by_this = anim_to_play_effective # Traccia l'animazione avviata da questo script
		
		# Se il toggle è attivo, inverti lo stato del toggle dopo aver avviato l'animazione.
		if can_toggle:
			_is_toggled_on = not _is_toggled_on

		# print("INFO (", name, "): AnimatedInteractable - Avviata animazione '", anim_to_play_effective, "'.") # Opzionale

	# [NUOVO] 6.5 Imposta la variabile globale booleana, se specificata
	# Questo avviene dopo super.interact() e dopo il tentativo di avviare l'animazione
	# (indipendentemente dal fatto che l'animazione sia partita o meno, l'interazione è "avvenuta")
	if set_global_bool_on_interact_name != "":
		GlobalBooleans.set_global_bool(set_global_bool_on_interact_name, true)


	# 7. Gestisci l'interazione una tantum, se abilitata.
	#    Questo disabiliterà `can_interact` dopo la prima interazione animata riuscita (o tentata).
	if one_time_interaction:
		can_interact = false
		# print("INFO (", name, "): AnimatedInteractable - Interazione 'one_time' attivata. Oggetto non più interagibile dopo questa azione.") # Opzionale
