extends CharacterBody3D

const SPEED = 10.0
const ALTITUDE_SMOOTHING_FACTOR = 0.1  # Adjust this value to control the altitude smoothing amount
const ROTATION_SMOOTHING_FACTOR = 0.1  # Adjust this value to control the rotation smoothing amount
const GROUND_LEVEL = 0.0  # Define the ground level height
# 18/10/2026 — vibration de la manette (mode Arduino seulement) : réglable dans l'inspecteur de JoueurDemo.
## Distance (en unités de la scène, ~mètres) en dessous de laquelle la manette vibre près d'un palet au sol visible.
@export_range(0.5, 30.0, 0.5) var distance_vibration: float = 5.0
## Marge d'hystérésis : la vibration s'arrête seulement au-delà de distance_vibration + cette marge (évite le clignotement à la frontière).
@export_range(0.0, 5.0, 0.1) var marge_vibration: float = 0.5
## Toutes les N secondes, l'état courant est renvoyé à la carte même sans changement (0 = jamais) : rattrape une commande perdue pendant un delay() du sketch.
@export_range(0.0, 10.0, 0.5) var rappel_vibration: float = 1.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target_altitude = 0.0
var target_rotation = 0.0

var Is_Arduino_Mode_On = true # Variable to switch between arduino control and Mouse/Keyboard controls
const SENSIBILITE = 0.002
const ALTITUDE_CHANGE_SPEED = 0.12

@onready var BackgroundSoundPlayer: AudioStreamPlayer = $BackgroundSoundPlayer

@onready var AudioPlayer1: AudioStreamPlayer = $AudioStreamPlayer1
@onready var AudioPlayer2: AudioStreamPlayer = $AudioStreamPlayer2
@onready var AudioPlayer3: AudioStreamPlayer = $AudioStreamPlayer3

var AudioPlayers = []

var compteur_object_collecte = 0
var ground_collectibles = [] # Array to store ground collectibles
var vibration_active = false # état voulu de la vibration (vrai = proche d'un palet)
var _vibration_envoyee: int = -1 # dernier état réellement envoyé à la carte (-1 = inconnu → renvoyer)
var _vibration_envoyee_a: float = 0.0 # horodatage (s) du dernier envoi, pour le rappel périodique
var partie_terminee = false # vrai après la dernière bougie : plus de déplacement ni de vibration
var is_playing_footstep = false # Track if footstep sound is currently playing

func _ready():
	randomize()
	ArduinoManager.ultrason_updated.connect(_on_arduino_manager_ultrason_updated)
	ArduinoManager.potentiometre_updated.connect(_on_arduino_manager_potentiometre_updated)
	# À chaque (ré)appairage, renvoyer l'état de vibration : la carte peut démarrer avec le vibreur allumé,
	# ou avoir raté la commande envoyée quand elle n'était pas encore appairée.
	ArduinoManager.arduino_connected.connect(func(): _vibration_envoyee = -1)
	AudioPlayers = [AudioPlayer1, AudioPlayer2, AudioPlayer3]
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	%ArduinoModeTimer.timeout.connect(_on_ArduinoModeTimer_timeout)
	%ArduinoModeTimer.start(2.0)

	$FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat1")
	$FmodEventEmitter2D_music.play()

	# Footsteps event is always playing; the "CharacterWalk" parameter toggles
	# between labels "CharacterFly" (airborne, silent) and "CharacterWalk" (on ground, audible steps).
	# 18/10/2026 : l'émetteur est un FmodEventEmitter3D (l'événement Footsteps est spatialisé dans la banque) ;
	# en 2D il était placé à l'origine du monde, loin du FmodListener3D du joueur, donc atténué jusqu'au silence.
	$FmodEventEmitter3D_footsteps.set_parameter("CharacterWalk", "CharacterFly")
	$FmodEventEmitter3D_footsteps.play()

	# Find all ground collectibles in the scene
	find_ground_collectibles()
	if g_vars.no_arduino == true :
		Is_Arduino_Mode_On = false

func find_ground_collectibles():
	# This function will be called to populate the ground_collectibles array
	# Find all nodes that match our ground collectible group
	ground_collectibles = get_tree().get_nodes_in_group("ground_collectibles")
	#print("Debug: Found ", ground_collectibles.size(), " ground collectibles")

	# If we didn't find any, try a more direct approach by looking for nodes with the right name.
	# 18/10/2026 : le joueur est prêt AVANT les palets (il les précède dans l'arbre), donc le groupe est encore
	# vide ici ; le repli cherche le nœud frère « GroundCollectibles » (chemin relatif : marche aussi quand la
	# scène est instanciée sous un autre parent, par exemple dans tests/). Nouvelle tentative au 1er besoin.
	if ground_collectibles.size() == 0:
		#print("Debug: No ground collectibles found in group. Searching scene...")
		var collectibles_node = get_parent().get_node_or_null("GroundCollectibles") if get_parent() else null
		if collectibles_node:
			for child in collectibles_node.get_children():
				if child.name.begins_with("GroundCollectible"):
					ground_collectibles.append(child)
					#print("Debug: Added collectible: ", child.name)

	#print("Debug: Total ground collectibles: ", ground_collectibles.size())

func Play_Feedback_Sound():
	# ancienne méthode :
	#var random_index = randi() % AudioPlayers.size()
	#AudioPlayers[random_index].play()
	# nouvelle méthode :
	$FmodEventEmitter3D_reward.play()
	compteur_object_collecte = compteur_object_collecte + 1
	if (compteur_object_collecte == 1):
		#$FmodEventEmitter3D_ambiance.set_parameter("AmbianceChange", "State1")
		$FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat2")
	elif (compteur_object_collecte == 2):
		#$FmodEventEmitter3D_ambiance.set_parameter("AmbianceChange", "State2")
		$FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat3")
	elif (compteur_object_collecte == 3):
		#$FmodEventEmitter3D_ambiance.set_parameter("AmbianceChange", "State3")
		$FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat4")

func play_footstep_sound():
	# Placeholder for FMOD footstep sound
	# This will be implemented later when FMOD banks are imported
	if !is_playing_footstep:
		is_playing_footstep = true
		# Placeholder: will use FMOD when available
		# $FmodEventEmitter3D_footstep.play()
		await get_tree().create_timer(0.3).timeout
		is_playing_footstep = false

func find_nearest_collectible_distance():
	# Distance au palet au sol visible le plus proche (INF s'il n'en reste aucun).
	# 18/10/2026 : plus de plafond à 15 (avec un seuil réglable au-dessus du plafond, on vibrait toujours) ;
	# les anciens groupes « collectibles » / « Object_To_Catch_1 » n'ont jamais existé dans la scène, retirés.
	if ground_collectibles.is_empty():
		find_ground_collectibles()
	var min_distance = INF
	for collectible in ground_collectibles:
		if is_instance_valid(collectible) and collectible.visible and not collectible.is_collected: # visible et pas déjà ramassé (il reste affiché 0,5 s pendant son effet de capture)
			var distance = global_position.distance_to(collectible.global_position)
			if distance < min_distance:
				min_distance = distance
	return min_distance

func is_near_collectible():
	# Hystérésis : on entre en vibration sous distance_vibration, on en sort au-delà de distance_vibration + marge.
	var min_distance = find_nearest_collectible_distance()
	if vibration_active:
		return min_distance < distance_vibration + marge_vibration
	return min_distance < distance_vibration

# 18/10/2026 : la commande vibe n'est envoyée qu'au CHANGEMENT d'état (avant : vibe:1 ou vibe:0 à chaque image
# physique, 60 fois par seconde, ce qui saturait la carte et laissait le vibreur allumé).
func _mettre_a_jour_vibration(voulue: bool) -> void:
	vibration_active = voulue
	var etat := 1 if voulue else 0
	var maintenant := Time.get_ticks_msec() / 1000.0
	var rappel := rappel_vibration > 0.0 and maintenant - _vibration_envoyee_a >= rappel_vibration
	if etat != _vibration_envoyee or rappel:
		ArduinoManager.send_vibe(voulue)
		_vibration_envoyee = etat
		_vibration_envoyee_a = maintenant

func arreter_vibration() -> void:
	_mettre_a_jour_vibration(false)

# Appelé par la dernière bougie : le joueur s'arrête, la vibration est coupée, la souris est rendue à l'écran de fin.
func terminer_partie() -> void:
	partie_terminee = true
	arreter_vibration()
	velocity = Vector3.ZERO
	$MeshInstance3D.hide()  # on cache la capsule (vue par la caméra finale) mais pas le nœud : écouteur et émetteurs FMOD restent actifs
	# _physics_process ne tourne plus : sans ça les pas resteraient sur « CharacterWalk » (au sol) et boucleraient sous l'écran de fin.
	$FmodEventEmitter3D_footsteps.set_parameter("CharacterWalk", "CharacterFly")
	for palet in ground_collectibles:  # les boucles VibrObj des palets restants n'ont plus rien à guider
		if is_instance_valid(palet) and palet.has_method("arreter_boucle"):
			palet.arreter_boucle()  # arrêt immédiat + émetteur libéré (18/10 soir ; avant : stop() en fondu)
		elif is_instance_valid(palet) and palet.has_node("FmodEventEmitter3D"):
			palet.get_node("FmodEventEmitter3D").stop()  # repli pour un palet d'équipe avec un autre script
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	# Changement de scène (Rejouer, retour au Start) : ne pas laisser le vibreur allumé.
	if _vibration_envoyee == 1:
		ArduinoManager.send_vibe(false)

func is_near_ground():
	# Either use the built-in is_on_floor() or check the y position
	return is_on_floor() or global_position.y < 2.1 # Assuming ground level is around 2.0

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Plein-Ecran"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _physics_process(delta):
	if partie_terminee:
		return  # écran de fin affiché : plus de déplacement, plus de vibration

	# Toggle on and off the "ArduinoMode", indicate-it by text on screen
	if Input.is_action_just_pressed("ArduinoToggle"):
		Is_Arduino_Mode_On = !Is_Arduino_Mode_On
		if Is_Arduino_Mode_On:
			%Menus/Arduino_indicator.text = "Arduino mode on"
			%ArduinoModeTimer.start(2.0) # start a timer to erase the text after 2 seconds
		elif !Is_Arduino_Mode_On:
			%Menus/Arduino_indicator.text = "Arduino mode off"
			%ArduinoModeTimer.start(2.0) # start a timer to erase the text after 2 seconds
			arreter_vibration()

	# Handles Arduino controlled altitude changes and camera rotation
	if Is_Arduino_Mode_On:
		# Smooth the altitude changes
		var current_altitude = global_position.y
		var smoothed_altitude = lerp(current_altitude, target_altitude, ALTITUDE_SMOOTHING_FACTOR)
		global_position.y = smoothed_altitude
		
		# Smooth the rotation changes
		var current_rotation = rotation.y
		var rotation_difference = fmod(target_rotation - current_rotation, TAU)
		if rotation_difference > PI:
			rotation_difference -= TAU
		elif rotation_difference < -PI:
			# 18/10/2026 soir (relecture) : fmod garde le signe ; sans ce repli, quand l'encodeur de Tom repasse de
			# 1023 à 0 (un tour), le personnage refaisait presque un tour complet à l'envers au lieu d'un petit pas.
			rotation_difference += TAU
		var smoothed_rotation = current_rotation + rotation_difference * ROTATION_SMOOTHING_FACTOR
		rotation.y = smoothed_rotation
		_mettre_a_jour_vibration(is_near_collectible())

	# Handles non-arduino altitude change
	elif !Is_Arduino_Mode_On:
		if Input.is_action_pressed("Sauter"):
			global_position.y += ALTITUDE_CHANGE_SPEED
		elif Input.is_action_pressed("Courir") and !is_on_floor():
			global_position.y -= ALTITUDE_CHANGE_SPEED
	
	# Auto forward movement in the direction the character is facing
	var forward_direction = -transform.basis.z.normalized()
	velocity.x = forward_direction.x * SPEED
	velocity.z = forward_direction.z * SPEED
	
	move_and_slide()
	
	var temp_hauteur_fmod = clampf(position.y*7, 0.0, 100.0)
	FmodServer.set_global_parameter_by_name("Hauteur", temp_hauteur_fmod)
	#$FmodEventEmitter2D_music.set_parameter("Hauteur", temp_hauteur_fmod)
	#print("HAUTEUR: ", $FmodEventEmitter2D_music.get_parameter("Hauteur") )
	#print("hauteur type", str(temp_hauteur_fmod))

	# Debug floor detection
	if is_near_ground():
		#print("Debug: Player is near ground at y=", global_position.y)
		pass
	
	# Footsteps: toggle the "CharacterWalk" parameter each frame between
	# "CharacterWalk" (on ground, audible steps) and "CharacterFly" (airborne, silent).
	var near = is_near_ground()
	#print("player y=", global_position.y, " is_on_floor=", is_on_floor(), " near=", near)
	if near:
		$FmodEventEmitter3D_footsteps.set_parameter("CharacterWalk", "CharacterWalk")
	else:
		$FmodEventEmitter3D_footsteps.set_parameter("CharacterWalk", "CharacterFly")
	
	# NOTE: Vibration is now handled directly in Arduino_Manager.cs
	# We no longer need to update vibration from here

# Handles non-Arduino camera rotation (with the mouse)
func _input(event):
	if event is InputEventMouseMotion and !Is_Arduino_Mode_On:
		rotate_y(-event.relative.x * SENSIBILITE)

# A function called to erase the text "Arduino mode on/off" on the screen when the timer expire
func _on_ArduinoModeTimer_timeout():
	%Menus/Arduino_indicator.text = ""

# Called to loop the background sound when it's finish to be played
func _on_background_sound_player_finished():
	$BackgroundSoundPlayer.play()

func Play_Ground_Collectible_Sound():
	# 18/10/2026 : un palet ramassé joue le même son de capture FMOD « ObjectCatch » que les bougies
	# (avant : simple print, aucun retour sonore). La musique (MusiqueEtat) n'avance qu'avec les bougies.
	print("Ground collectible collected!")
	$FmodEventEmitter3D_reward.play()


func _on_arduino_manager_potentiometre_updated(value: float) -> void:
	target_rotation = deg_to_rad(value / 3)


func _on_arduino_manager_ultrason_updated(value: float) -> void:
	if value >= 50 or value < 0:  #We are not putting our hand on over the sensor
		target_altitude = GROUND_LEVEL # Default to ground level
	else:
		target_altitude = float(value-6) #need to check what is the max altitude, sensor provides distance in cmm
