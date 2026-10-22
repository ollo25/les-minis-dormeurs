extends XRController3D
## Main droite en VR : gâchette appuyée = attraper, gâchette relâchée = lâcher.
## Bouton B = recaler le sol : pose la manette par terre et appuie sur B.
## (La main gauche n'existe pas : le joueur tient le bébé.)

@onready var zone_saisie: Area3D = $ZoneSaisie

var objet_tenu: ObjetRangeable = null


func _ready() -> void:
	button_pressed.connect(_on_bouton_appuye)
	button_released.connect(_on_bouton_relache)


func _on_bouton_appuye(nom: String) -> void:
	if nom == "trigger_click":
		if Partie.partie_finie:
			get_tree().change_scene_to_file("res://Scènes/Accueil/Accueil.tscn")   # fin : gâchette = menu
		else:
			prendre()
	elif nom == "by_button":
		calibrer_sol()


func _on_bouton_relache(nom: String) -> void:
	if nom == "trigger_click":
		lacher()


func prendre() -> void:
	if objet_tenu != null or Partie.partie_finie:
		return
	# On prend le premier objet rangeable qui touche la sphère de la main
	for corps in zone_saisie.get_overlapping_bodies():
		if corps is ObjetRangeable and not corps.est_range:
			objet_tenu = corps
			objet_tenu.etre_pris(self)
			return


func lacher() -> void:
	if objet_tenu != null:
		objet_tenu.etre_lache()
		objet_tenu = null


## Le sol du jeu n'est pas toujours à la hauteur du vrai sol (réglage SteamVR / ALVR).
## Manette posée sur le vrai sol + bouton B : on décale le monde pour que les deux coïncident.
func calibrer_sol() -> void:
	var origine := get_parent() as Node3D
	var ecart := global_position.y - 0.03     # la manette posée a son centre ~3 cm au-dessus du sol
	origine.global_position.y -= ecart
	print("[Main] Sol recalé de %.2f m" % ecart)
