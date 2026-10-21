extends Node3D
## Scène de jeu : la chambre du bébé.
## - Mode normal : active la VR (OpenXR) si le casque est détecté.
##   Joystick de la manette droite = se déplacer (dans la direction où on regarde).
## - Mode debug (ou pas de casque) : on se déplace au clavier/souris.
##   ZQSD / flèches = se déplacer, souris = regarder, Échap = libérer la souris,
##   clic gauche maintenu = attraper l'objet visé, C = s'accroupir, F1 = retour à l'écran d'accueil.

const VITESSE := 1.6            # m/s, vitesse de marche
const SENSIBILITE := 0.0025     # rotation souris
const HAUTEUR_YEUX := 1.6       # hauteur de la caméra en mode debug
const HAUTEUR_ACCROUPI := 0.6   # hauteur quand on est accroupi (touche C)
const VITESSE_VR := 1.0         # m/s, déplacement au joystick en VR
const ZONE_MORTE := 0.2         # on ignore les toutes petites poussées du joystick

@onready var origine: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var main_droite: XRController3D = $XROrigin3D/MainDroite

var mode_clavier := false
var camera_debug: Camera3D   # caméra normale utilisée seulement en mode debug
var corps_debug: CharacterBody3D   # "corps" du joueur en debug, pour cogner les meubles
var rayon_debug: RayCast3D          # "laser" qui part du centre de l'écran pour viser un objet
var objet_tenu_debug: ObjetRangeable = null
var point_main_debug: Marker3D      # la "main" en debug : là où on vise (sert à ouvrir les tiroirs)
var corps_vr: CharacterBody3D       # "corps" du joueur en VR, pour ne pas traverser les meubles au joystick


func _ready() -> void:
	Partie.nouvelle_partie()
	var xr := XRServer.find_interface("OpenXR")
	var casque_ok := xr != null and xr.is_initialized()

	if not Partie.mode_debug and casque_ok:
		print("[Chambre] Mode VR")
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		corps_vr = _creer_corps()
		Partie.noeud_main = main_droite
	else:
		if not Partie.mode_debug:
			push_warning("[Chambre] Casque non détecté : passage en mode clavier")
		print("[Chambre] Mode debug clavier/souris")
		_activer_mode_clavier()


func _activer_mode_clavier() -> void:
	mode_clavier = true
	# En mode clavier, on cache la petite sphère de la main (elle flotte sinon)
	$XROrigin3D/MainDroite/Visuel.visible = false
	# La caméra VR est pilotée par le casque : en debug on utilise une caméra normale
	camera_debug = Camera3D.new()
	camera_debug.position = Vector3(0, HAUTEUR_YEUX, 0)
	origine.add_child(camera_debug)
	camera_debug.make_current()
	# Corps physique : une capsule de 1,6 m qui ne traverse plus les meubles ni les murs
	corps_debug = CharacterBody3D.new()
	corps_debug.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # pas de gravité, on glisse
	corps_debug.collision_mask = 1   # il cogne le décor, mais pas les objets à ranger
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	forme.shape = capsule
	forme.position.y = 0.9   # le bas de la capsule est à 10 cm du sol (on passe sur les tapis)
	corps_debug.add_child(forme)
	add_child(corps_debug)
	corps_debug.global_position = origine.global_position
	# Rayon pour viser les objets (2,5 m devant la caméra)
	rayon_debug = RayCast3D.new()
	rayon_debug.target_position = Vector3(0, 0, -2.5)
	rayon_debug.collision_mask = 1 | 2   # le décor bloque la vue, les objets sont détectés
	camera_debug.add_child(rayon_debug)
	# "Main" en debug : un point devant la caméra (ou là où on vise si c'est proche)
	point_main_debug = Marker3D.new()
	camera_debug.add_child(point_main_debug)
	Partie.noeud_main = point_main_debug
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Bandeau "MODE DEBUG" en haut à gauche
	var calque := CanvasLayer.new()
	var label := Label.new()
	label.text = "MODE DEBUG — ZQSD : bouger · Souris : regarder · Clic gauche : attraper · C : s'accroupir · Échap : souris · F1 : menu"
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.85))
	calque.add_child(label)
	# Viseur au centre de l'écran
	var viseur := Label.new()
	viseur.text = "+"
	viseur.add_theme_font_size_override("font_size", 32)
	viseur.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	viseur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	viseur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	calque.add_child(viseur)
	add_child(calque)


func _unhandled_input(event: InputEvent) -> void:
	if not mode_clavier:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		origine.rotate_y(-event.relative.x * SENSIBILITE)
		# Regarder en haut / en bas (on bloque à 85° pour ne pas se retourner)
		camera_debug.rotation.x = clamp(camera_debug.rotation.x - event.relative.y * SENSIBILITE, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # un clic reprend la souris
		elif event.pressed:
			prendre_debug()
		else:
			lacher_debug()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_C:
			# S'accroupir / se relever
			if camera_debug.position.y > HAUTEUR_ACCROUPI + 0.1:
				camera_debug.position.y = HAUTEUR_ACCROUPI
			else:
				camera_debug.position.y = HAUTEUR_YEUX
		elif event.keycode == KEY_F1:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://Scènes/Accueil/Accueil.tscn")


## Crée une capsule de 1,6 m qui bute contre les meubles et les murs.
func _creer_corps() -> CharacterBody3D:
	var corps := CharacterBody3D.new()
	corps.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # pas de gravité, on glisse
	corps.collision_mask = 1   # il cogne le décor, mais pas les objets à ranger
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	forme.shape = capsule
	forme.position.y = 0.9
	corps.add_child(forme)
	add_child(corps)
	corps.global_position = origine.global_position
	return corps


## Déplacement en VR avec le joystick de la manette droite.
func _deplacement_vr() -> void:
	var joystick: Vector2 = main_droite.get_vector2("primary")   # x = gauche/droite, y = avant/arrière
	# Le corps se place sous la tête du joueur (il peut aussi marcher en vrai dans sa pièce)
	var tete := camera.global_position
	corps_vr.global_position = Vector3(tete.x, origine.global_position.y, tete.z)
	if joystick.length() < ZONE_MORTE:
		return
	# Directions "devant" et "à droite" selon le regard, à plat (sans monter ni descendre)
	var devant := -camera.global_basis.z
	devant.y = 0
	devant = devant.normalized()
	var droite := camera.global_basis.x
	droite.y = 0
	droite = droite.normalized()
	corps_vr.velocity = (devant * joystick.y + droite * joystick.x) * VITESSE_VR
	var avant := corps_vr.global_position
	corps_vr.move_and_slide()   # s'arrête contre les meubles
	# On décale tout le "monde du joueur" du trajet réellement fait par le corps
	origine.global_position += corps_vr.global_position - avant


func _physics_process(_delta: float) -> void:
	if not mode_clavier:
		if corps_vr != null:
			_deplacement_vr()
		return
	# Debug : la "main" va là où on vise (si c'est à portée de bras), sinon devant soi
	if rayon_debug.is_colliding() and camera_debug.global_position.distance_to(rayon_debug.get_collision_point()) < 1.6:
		point_main_debug.global_position = rayon_debug.get_collision_point()
	else:
		point_main_debug.position = Vector3(0.15, -0.2, -0.5)
	# Actions déjà définies dans le projet : Avancer / Reculer / Gauche / Droite (ZQSD + flèches)
	var entree := Input.get_vector("Gauche", "Droite", "Avancer", "Reculer")
	var direction := (origine.global_basis * Vector3(entree.x, 0, entree.y))
	direction.y = 0
	# On fait bouger le corps (il s'arrête contre les meubles), puis le joueur le suit
	corps_debug.velocity = direction.normalized() * VITESSE if direction.length() > 0.01 else Vector3.ZERO
	corps_debug.move_and_slide()
	origine.global_position.x = corps_debug.global_position.x
	origine.global_position.z = corps_debug.global_position.z


# ---------- Attraper / lâcher en mode debug (clic gauche) ----------

func prendre_debug() -> void:
	if objet_tenu_debug != null or not rayon_debug.is_colliding():
		return
	var cible = rayon_debug.get_collider()
	if cible is ObjetRangeable and not cible.est_range:
		objet_tenu_debug = cible
		objet_tenu_debug.etre_pris(camera_debug)
		# On le tient devant soi, un peu en bas, comme dans la main
		objet_tenu_debug.position = Vector3(0.15, -0.2, -0.5)


func lacher_debug() -> void:
	if objet_tenu_debug != null:
		objet_tenu_debug.etre_lache()
		objet_tenu_debug = null
