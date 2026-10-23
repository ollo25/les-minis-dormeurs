extends Node3D
## Scène de jeu : la chambre du bébé.
## - Mode normal : active la VR (OpenXR) si le casque est détecté.
##   Joystick de la manette droite = se déplacer (dans la direction où on regarde).
##   En "debug VR" (sans Arduino), boutons de test sur la manette droite :
##   A = victoire (tout ranger), B = défaite "bébé réveillé", clic du joystick = défaite "temps écoulé".
## - Mode debug (ou pas de casque) : on se déplace au clavier/souris.
##   ZQSD / flèches = se déplacer, souris = regarder, Échap = libérer la souris,
##   clic gauche maintenu = attraper l'objet visé, C = s'accroupir, F1 = retour à l'écran d'accueil.
##   V = (triche de test) tout ranger d'un coup pour voir la victoire.
##   R = (test) défaite "bébé réveillé" ; T = (test) défaite "temps écoulé".

const VITESSE := 1.6            # m/s, vitesse de marche
const SENSIBILITE := 0.0025     # rotation souris
const HAUTEUR_YEUX := 1.6       # hauteur de la caméra en mode debug
const HAUTEUR_ACCROUPI := 0.6   # hauteur quand on est accroupi (touche C)
const VITESSE_VR := 1.0         # m/s, déplacement au joystick en VR
const ZONE_MORTE := 0.2         # on ignore les toutes petites poussées du joystick
const TAILLE_BEBE := 0.6        # le modèle est grand : on le réduit à la taille d'un nouveau-né (~55 cm)
const ROTATION_BEBE := Vector3(15, 90, 45)  # en degrés (mode debug) : tête vers la gauche, couché au creux du bras
# En VR : le bébé est contre ta poitrine et suit ton CORPS (la hauteur du casque, pas la manette).
# Il est couché en travers, tête à gauche (au creux du bras gauche), tourné vers toi.
const ROTATION_BEBE_VR := Vector3(0, 90, 35)        # 90 = en travers ; 35 = blotti, visage tourné vers toi
const DECALAGE_BEBE_VR := Vector3(-0.24, -0.45, -0.05)   # depuis tes yeux : x = gauche/droite, y = sous les yeux, z = devant toi
const CENTRE_BEBE := Vector3(0, 0.02, -0.33)      # milieu du corps du bébé dans sa scène (ses pieds sont à 0)

@onready var origine: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var main_droite: XRController3D = $XROrigin3D/MainDroite
@onready var main_gauche: XRController3D = $XROrigin3D/MainGauche   # elle tient le bébé

var mode_clavier := false
var camera_debug: Camera3D   # caméra normale utilisée seulement en mode debug
var corps_debug: CharacterBody3D   # "corps" du joueur en debug, pour cogner les meubles
var rayon_debug: RayCast3D          # "laser" qui part du centre de l'écran pour viser un objet
var objet_tenu_debug: ObjetRangeable = null
var point_main_debug: Marker3D      # la "main" en debug : là où on vise (sert à ouvrir les tiroirs)
var corps_vr: CharacterBody3D       # "corps" du joueur en VR, pour ne pas traverser les meubles au joystick
var bebe: Node3D                    # le bébé (porté dans les bras, puis couché dans le berceau à la fin)
# États du bébé dans l'event FMOD "Etat" (valeurs du paramètre "Etat")
const BEBE_CALME := 0               # agitation 0-24 %
const BEBE_AGITE := 1               # agitation 25-49 %
const BEBE_TRES_AGITE := 2          # agitation 50-74 %
const BEBE_PRESQUE_REVEILLE := 3    # agitation 75-99 %
var etat_bebe := -1
# Volume de l'ambiance du bébé pour chaque état (1 = volume d'origine de la banque).
# Les deux premiers états sont faibles dans les fichiers : on les monte un peu ici.
const VOLUME_ETAT := [1.5, 1.0, 0.5, 0.5]   # (avant : 3 / 2 / 1 / 1, le fond couvrait les voix)

var bras_vr: Node3D                 # point qui suit ton corps en VR (sous le casque, tourné comme toi)
var ecran_noir: MeshInstance3D      # carré noir collé devant les yeux, pour les fondus (marche aussi en VR)


func _ready() -> void:
	Partie.nouvelle_partie()
	Partie.victoire.connect(_lancer_victoire)
	Partie.defaite.connect(_lancer_defaite)
	Partie.objet_ramasse_signal.connect(_jouer_voix_objet)
	Partie.objet_range_signal.connect(_jouer_son_rangement)
	_changer_etat_bebe(BEBE_CALME)
	$AmbianceBebe.play()
	bebe = get_node_or_null("Bebe")
	_mettre_bebe_en_pose()
	var xr := XRServer.find_interface("OpenXR")
	var casque_ok := xr != null and xr.is_initialized()

	if not Partie.mode_debug and casque_ok:
		print("[Chambre] Mode VR")
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		corps_vr = _creer_corps()
		Partie.noeud_main = main_droite
		main_droite.button_pressed.connect(_on_bouton_vr)
		# Le bébé est porté par la main gauche (là où sera la poupée Arduino)
		# Le bébé suit le casque (si tu te baisses, il descend avec toi), pas la manette
		bras_vr = Node3D.new()
		origine.add_child(bras_vr)
		_attacher_bebe(bras_vr, DECALAGE_BEBE_VR, ROTATION_BEBE_VR, true)
	else:
		if not Partie.mode_debug:
			push_warning("[Chambre] Casque non détecté : passage en mode clavier")
		print("[Chambre] Mode debug clavier/souris")
		_activer_mode_clavier()
	_afficher_tuto()


func _activer_mode_clavier() -> void:
	mode_clavier = true
	# En mode clavier, on cache la petite sphère de la main (elle flotte sinon)
	$XROrigin3D/MainDroite/Visuel.visible = false
	# La caméra VR est pilotée par le casque : en debug on utilise une caméra normale
	camera_debug = Camera3D.new()
	camera_debug.position = Vector3(0, HAUTEUR_YEUX, 0)
	origine.add_child(camera_debug)
	camera_debug.make_current()
	# La jauge du bébé suit la caméra de debug (en VR, elle est sur la caméra du casque)
	$XROrigin3D/XRCamera3D/JaugeBebe.reparent(camera_debug, false)
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
	# En debug, le bébé est porté en bas à gauche de l'écran (au creux du bras)
	_attacher_bebe(camera_debug, Vector3(0.1, -0.33, -0.5), ROTATION_BEBE, false)
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
	# Tuto du début : une touche ou un clic pour commencer
	if Partie.tuto_en_cours:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			Partie.fermer_tuto()
			get_viewport().set_input_as_handled()
		return
	# Partie finie : un clic ou une touche ramène au menu
	if Partie.partie_finie:
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed and _fin_affichee:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://Scènes/Accueil/Accueil.tscn")
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
		elif event.keycode == KEY_V:
			_tout_ranger_triche()
		elif event.keycode == KEY_R:
			Partie.declencher_defaite("reveil")
		elif event.keycode == KEY_T:
			Partie.declencher_defaite("temps")
		elif event.keycode == KEY_F1:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://Scènes/Accueil/Accueil.tscn")


## Quand on quitte la chambre (retour au menu), la jauge s'arrête.
func _exit_tree() -> void:
	Partie.partie_lancee = false


func _process(delta: float) -> void:
	# Compte à rebours de la partie (affiché sur le réveil de la table de nuit)
	# (il attend que le joueur ait fermé le tuto)
	if not Partie.partie_finie and not Partie.tuto_en_cours:
		Partie.temps_restant = maxf(Partie.temps_restant - delta, 0.0)
		if Partie.temps_restant <= 0.0:
			Partie.declencher_defaite("temps")
		else:
			_son_selon_jauge()
	# En VR, le "bras" qui porte le bébé suit la position de la tête,
	# mais seulement sa rotation gauche/droite (regarder en bas ne fait pas bouger le bébé)
	if bras_vr != null and bebe != null and bebe.get_parent() == bras_vr:
		bras_vr.position = camera.position
		bras_vr.rotation = Vector3(0, camera.rotation.y, 0)


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
	corps_vr.global_position = Vector3(tete.x, 0, tete.z)   # toujours posé sur le sol du jeu
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
	var trajet := corps_vr.global_position - avant
	origine.global_position += Vector3(trajet.x, 0, trajet.z)   # jamais en hauteur


func _physics_process(_delta: float) -> void:
	if Partie.partie_finie:
		return   # plus de déplacement pendant l'écran de fin
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


## Le bébé (scène Bebe/BebePorte : modèle + couverture + bonnet) a une pose enregistrée
## dans l'animation "Game_engineAction".
## On la joue une fois au démarrage : le bébé garde la position de la dernière image.
func _mettre_bebe_en_pose() -> void:
	if bebe == null:
		return
	var anim_bebe := bebe.find_child("AnimationPlayer") as AnimationPlayer
	if anim_bebe != null and anim_bebe.has_animation("Game_engineAction"):
		anim_bebe.play("Game_engineAction")
		await anim_bebe.animation_finished
	# Les jambes sont sous la couverture : on les "replie" à zéro pour qu'elles ne dépassent jamais
	var squelette := bebe.find_child("Skeleton3D", true, false) as Skeleton3D
	if squelette != null:
		for os in ["thigh_l", "thigh_r"]:
			var i := squelette.find_bone(os)
			if i >= 0:
				squelette.set_bone_pose_scale(i, Vector3.ZERO)


## Accroche le bébé à une main (ou à la caméra en debug) : il suit tous ses mouvements.
## centrer = true : c'est le MILIEU du bébé qui est placé sur la main (et pas ses pieds).
func _attacher_bebe(support: Node3D, decalage: Vector3, rotation_deg: Vector3, centrer: bool) -> void:
	if bebe == null:
		return
	bebe.reparent(support, false)   # false = on oublie sa position dans la pièce
	bebe.rotation_degrees = rotation_deg
	bebe.scale = Vector3.ONE * TAILLE_BEBE
	bebe.position = decalage
	if centrer:
		bebe.position -= bebe.basis * CENTRE_BEBE


# ---------- Fin de partie : victoire ----------

var _fin_affichee := false   # true quand le texte de fin est affiché (on peut revenir au menu)


## Victoire : fondu au noir → le bébé dort dans son berceau, dans la nuit → dézoom → "Victoire !".
func _lancer_victoire() -> void:
	_musique_de_fin($SonVictoire)
	_sequence_fin("Victoire !", "Le bébé dort paisiblement", Color(1.0, 0.894, 0.478), true)


## Défaite : même mise en scène, mais la lumière est allumée en grand (le bébé est réveillé).
func _lancer_defaite(raison: String) -> void:
	_musique_de_fin($SonDefaite)
	var total := get_tree().get_nodes_in_group("objets_rangeables").size()
	var detail := "%d / %d objets rangés" % [Partie.objets_ranges, total]
	if raison == "temps":
		_sequence_fin("Le temps est écoulé…", "Le bébé s'est réveillé · " + detail, Color(1.0, 0.56, 0.69), false)
	else:
		_sequence_fin("Le bébé s'est réveillé !", "Tu l'as trop secoué · " + detail, Color(1.0, 0.56, 0.69), false)


## Mise en scène de fin, commune à la victoire et à la défaite.
## nuit = true : chambre plongée dans le noir ; false : la lumière du plafond s'allume en grand.
func _sequence_fin(texte_titre: String, texte_sous_titre: String, couleur: Color, nuit: bool) -> void:
	if mode_clavier:
		lacher_debug()
	else:
		main_droite.lacher()
	await _fondu(1.0, 1.2)   # l'écran devient noir
	for enfant in get_children():
		if enfant is CanvasLayer:
			enfant.visible = false   # on cache le bandeau debug et le viseur

	# Le bébé est posé dans son berceau, couché sur le dos
	var berceau := $Meubles/Berceau as Node3D
	bebe.reparent(berceau, false)
	bebe.position = Vector3(0.27, 0.53, 0.0)
	bebe.rotation_degrees = Vector3(0, 90, 0)
	bebe.scale = Vector3.ONE * TAILLE_BEBE
	var centre := berceau.global_position + Vector3(0, 0.55, 0)
	if nuit:
		_ambiance_nuit_profonde(centre)
	else:
		_allumer_la_lumiere()

	# Les textes flottent au-dessus du berceau
	var titre := _creer_texte(texte_titre, 200, centre + Vector3(0, 0.75, 0))
	titre.modulate = couleur
	var sous_titre := _creer_texte(texte_sous_titre, 70, centre + Vector3(0, 0.55, 0))
	titre.modulate.a = 0.0
	sous_titre.modulate.a = 0.0

	# On se place tout près du bébé, puis on recule (le "dézoom")
	var depart := centre + Vector3(0, 0.6, 0.25)
	var arrivee := centre + Vector3(0, 1.1, 2.4)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mode_clavier:
		var cam := Camera3D.new()
		add_child(cam)
		cam.look_at_from_position(depart, centre)
		cam.make_current()
		ecran_noir.reparent(cam, false)
		t.tween_method(func(p: Vector3): cam.look_at_from_position(p, centre), depart, arrivee, 6.0)
	else:
		# En VR on ne peut pas bouger la tête du joueur : on déplace "sa pièce" doucement
		origine.global_position = Vector3(centre.x, 0, centre.z + 0.9)
		origine.rotation = Vector3.ZERO
		t.tween_property(origine, "global_position:z", centre.z + 2.4, 6.0)
	_fondu(0.0, 1.5)   # l'écran s'éclaircit pendant qu'on recule
	t.tween_property(titre, "modulate:a", 1.0, 1.5).set_delay(2.0)
	t.tween_property(sous_titre, "modulate:a", 1.0, 1.5).set_delay(3.0)
	await t.finished
	var aide := "Appuie sur une touche pour revenir au menu" if mode_clavier else "Gâchette pour revenir au menu"
	_creer_texte(aide, 40, centre + Vector3(0, 0.4, 0))
	_fin_affichee = true


## Défaite : quelqu'un allume le plafonnier, la chambre est éclairée en grand, lumière crue.
func _allumer_la_lumiere() -> void:
	var env: Environment = $WorldEnvironment.environment
	env.ambient_light_energy = 1.0
	env.ambient_light_color = Color(1.0, 0.98, 0.92)
	var plafonnier := OmniLight3D.new()
	plafonnier.light_color = Color(1.0, 0.96, 0.88)
	plafonnier.light_energy = 2.5
	plafonnier.omni_range = 6.0
	plafonnier.shadow_enabled = true
	add_child(plafonnier)
	plafonnier.global_position = Vector3(0, 2.2, 0)


## Fin : on plonge la chambre dans la nuit (lumière ambiante très basse, bleutée)
## et une petite lumière douce, comme une veilleuse, éclaire le bébé qui dort.
func _ambiance_nuit_profonde(centre: Vector3) -> void:
	var env: Environment = $WorldEnvironment.environment
	env.ambient_light_energy = 0.06
	env.ambient_light_color = Color(0.45, 0.5, 0.85)
	var douce := SpotLight3D.new()
	douce.light_color = Color(1.0, 0.75, 0.5)
	douce.light_energy = 1.2
	douce.spot_range = 3.0
	douce.spot_angle = 28.0
	add_child(douce)
	douce.look_at_from_position(centre + Vector3(0.3, 1.6, 0.4), centre)


## Fondu : le carré noir devant les yeux passe à l'opacité voulue (0 = transparent, 1 = noir).
func _fondu(opacite: float, duree: float) -> void:
	if ecran_noir == null:
		ecran_noir = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(4, 4)
		ecran_noir.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true          # toujours dessiné par-dessus tout
		mat.render_priority = 100
		mat.albedo_color = Color(0, 0, 0, 0)
		ecran_noir.material_override = mat
		var tete: Node3D = camera_debug if mode_clavier else camera
		tete.add_child(ecran_noir)
		ecran_noir.position = Vector3(0, 0, -0.2)
	var mat := ecran_noir.material_override as StandardMaterial3D
	var t := create_tween()
	t.tween_property(mat, "albedo_color:a", opacite, duree)
	await t.finished


## Texte 3D qui flotte dans la pièce et se tourne toujours vers le joueur.
func _creer_texte(texte: String, taille: int, ou: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = texte
	label.font_size = taille
	label.pixel_size = 0.001
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.894, 0.478)       # jaune de la palette
	label.outline_modulate = Color(0.16, 0.13, 0.24)
	label.outline_size = 18
	add_child(label)
	label.global_position = ou
	return label


## En "debug VR" (lancé sans Arduino), boutons de test de la manette droite :
## A = tout ranger (victoire), B = défaite "bébé réveillé", clic du joystick = défaite "temps écoulé".
func _on_bouton_vr(nom: String) -> void:
	if not g_vars.no_arduino or Partie.partie_finie or Partie.tuto_en_cours:
		return
	if nom == "ax_button":
		print("[Chambre] Triche VR : tout est rangé")
		_tout_ranger_triche()
	elif nom == "by_button":
		Partie.declencher_defaite("reveil")
	elif nom == "primary_click":
		Partie.declencher_defaite("temps")


## Triche de test (touche V en debug clavier, bouton A en debug VR) : range tout d'un coup.
func _tout_ranger_triche() -> void:
	var zones := {}
	for zone in find_children("Zone_*", "Area3D", true, false):
		zones[zone.destination] = zone
	for objet in get_tree().get_nodes_in_group("objets_rangeables"):
		if not objet.est_range and zones.has(objet.destination):
			objet.global_position = zones[objet.destination].global_position
			objet.ranger(zones[objet.destination])


# ---------- Sons ----------

## Change l'état du bébé dans FMOD (FMOD fait la transition tout seul).
func _changer_etat_bebe(etat: int) -> void:
	if etat == etat_bebe:
		return
	etat_bebe = etat
	$AmbianceBebe.set_parameter("Etat", etat)
	$AmbianceBebe.volume = VOLUME_ETAT[etat]


## Le son du bébé suit l'état de la jauge invisible (4 états, du plus calme au plus agité).
func _son_selon_jauge() -> void:
	match Partie.etat_bebe():
		Partie.CALME:
			_changer_etat_bebe(BEBE_CALME)
		Partie.AGITE:
			_changer_etat_bebe(BEBE_AGITE)
		Partie.TRES_AGITE:
			_changer_etat_bebe(BEBE_TRES_AGITE)
		Partie.PRESQUE_REVEILLE:
			_changer_etat_bebe(BEBE_PRESQUE_REVEILLE)


## Fin de partie : on coupe l'ambiance du bébé et on lance la musique de victoire ou de défaite.
func _musique_de_fin(son: Node) -> void:
	$AmbianceBebe.stop()
	son.play()


## Quand on ramasse un objet : la voix chuchote où le ranger (nœud du même nom dans VoixObjets).
## C'est la SEULE façon pour le joueur de savoir où va l'objet.
func _jouer_voix_objet(objet: Node) -> void:
	var voix := get_node_or_null("VoixObjets/" + objet.name)
	if voix != null:
		voix.play()


## Quand un objet est bien rangé : on entend le bruit de l'objet (nœud du même nom dans SonsObjets).
func _jouer_son_rangement(objet: Node) -> void:
	var son := get_node_or_null("SonsObjets/" + objet.name)
	if son != null:
		son.play()


# ---------- Tuto du début ----------

var panneau_tuto: Node3D

## Panneau d'explications collé devant les yeux au lancement. Le chrono et la jauge
## attendent que le joueur appuie sur la gâchette (ou une touche en mode clavier).
func _afficher_tuto() -> void:
	var cam: Node3D = camera_debug if mode_clavier else camera
	panneau_tuto = Node3D.new()
	cam.add_child(panneau_tuto)
	panneau_tuto.position = Vector3(0, 0, -1.2)
	# Fond sombre
	var fond := MeshInstance3D.new()
	var forme := QuadMesh.new()
	forme.size = Vector2(1.55, 0.72)
	fond.mesh = forme
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 20
	mat.albedo_color = Color(0.12, 0.1, 0.25, 0.85)
	fond.material_override = mat
	panneau_tuto.add_child(fond)
	# Texte
	var texte := Label3D.new()
	if mode_clavier:
		texte.text = "Ne réveille pas le bébé !\n\nZQSD : se déplacer   ·   Souris : regarder\nClic gauche maintenu : prendre un objet, relâcher pour le poser\n\nQuand tu prends un objet, écoute bien :\nune voix te chuchote où le ranger.\nRange les 10 objets avant la fin du temps.\n\nBouge doucement : si tu secoues le bébé, il se réveille.\n\nAppuie sur une touche pour commencer"
	else:
		texte.text = "Ne réveille pas le bébé !\n\nJoystick droit : se déplacer dans la pièce\nGâchette : prendre un objet (garde-la appuyée), relâche pour le poser\n\nQuand tu prends un objet, écoute bien :\nune voix te chuchote où le ranger.\nRange les 10 objets avant la fin du temps.\n\nBouge doucement : si tu secoues le bébé, il se réveille.\n\nAppuie sur la gâchette pour commencer"
	texte.font_size = 64
	texte.pixel_size = 0.0007
	texte.no_depth_test = true
	texte.render_priority = 21
	texte.outline_size = 0
	texte.modulate = Color(1.0, 0.894, 0.478)       # jaune de la palette
	texte.position = Vector3(0, 0, 0.01)
	panneau_tuto.add_child(texte)
	Partie.tuto_ferme.connect(_fermer_tuto)


func _fermer_tuto() -> void:
	if panneau_tuto != null:
		panneau_tuto.queue_free()
		panneau_tuto = null
