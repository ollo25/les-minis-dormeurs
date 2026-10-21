extends Node3D
## Scène de jeu : la chambre du bébé.
## - Mode normal : active la VR (OpenXR) si le casque est détecté.
## - Mode debug (ou pas de casque) : on se déplace au clavier/souris.
##   ZQSD / flèches = se déplacer, souris = regarder, Échap = libérer la souris,
##   clic = reprendre la souris, F1 = retour à l'écran d'accueil.

const VITESSE := 1.6            # m/s, vitesse de marche
const SENSIBILITE := 0.0025     # rotation souris
const HAUTEUR_YEUX := 1.6       # hauteur de la caméra en mode debug
const LIMITE_X := 2.8           # on reste dans la pièce (6 x 5 m, moins une marge)
const LIMITE_Z := 2.3

@onready var origine: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D

var mode_clavier := false


func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR")
	var casque_ok := xr != null and xr.is_initialized()

	if not Partie.mode_debug and casque_ok:
		print("[Chambre] Mode VR")
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		if not Partie.mode_debug:
			push_warning("[Chambre] Casque non détecté : passage en mode clavier")
		print("[Chambre] Mode debug clavier/souris")
		_activer_mode_clavier()


func _activer_mode_clavier() -> void:
	mode_clavier = true
	camera.position = Vector3(0, HAUTEUR_YEUX, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Bandeau "MODE DEBUG" en haut à gauche
	var calque := CanvasLayer.new()
	var label := Label.new()
	label.text = "MODE DEBUG — ZQSD : bouger · Souris : regarder · Échap : souris · F1 : menu"
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.85))
	calque.add_child(label)
	add_child(calque)


func _unhandled_input(event: InputEvent) -> void:
	if not mode_clavier:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		origine.rotate_y(-event.relative.x * SENSIBILITE)
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * SENSIBILITE, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_F1:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://Scènes/Accueil/Accueil.tscn")


func _physics_process(delta: float) -> void:
	if not mode_clavier:
		return
	# Actions déjà définies dans le projet : Avancer / Reculer / Gauche / Droite (ZQSD + flèches)
	var entree := Input.get_vector("Gauche", "Droite", "Avancer", "Reculer")
	var direction := (origine.global_basis * Vector3(entree.x, 0, entree.y))
	direction.y = 0
	if direction.length() > 0.01:
		origine.global_position += direction.normalized() * VITESSE * delta
	origine.global_position.x = clamp(origine.global_position.x, -LIMITE_X, LIMITE_X)
	origine.global_position.z = clamp(origine.global_position.z, -LIMITE_Z, LIMITE_Z)
