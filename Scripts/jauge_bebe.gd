extends Node3D
## Petit indicateur accroché à la vue du joueur (en bas à droite) :
## il montre à quel point on bouge le bébé EN CE MOMENT (niveau 0 à 5 envoyé par l'Arduino),
## comme la jauge de bruit des jeux d'horreur quand le micro est branché.
## Immobile = 0 case, très secoué = 5 cases.
## (L'agitation du bébé, elle, est une autre valeur, cachée : Partie.jauge.)

# Couleurs des 5 cases pleines (palette du jeu) : du doux au brutal
const COULEURS := [
	Color("7FEAC6"),   # menthe
	Color("A7F089"),   # vert
	Color("FFE47A"),   # jaune
	Color("FFB88C"),   # pêche
	Color("FF8FB1"),   # rose
]
const COULEUR_VIDE := Color(1, 1, 1, 0.15)   # case vide : blanc presque transparent
const VITESSE := 25.0   # les cases suivent le niveau très vite (juste pour ne pas clignoter)

var affiche := 0.0      # niveau affiché (rejoint Partie.niveau_mouvement en une fraction de seconde)


func _process(delta: float) -> void:
	# On cache l'indicateur pendant l'écran de fin
	visible = not Partie.partie_finie
	affiche = move_toward(affiche, Partie.niveau_mouvement, VITESSE * delta)
	for i in 5:
		# 0 = case vide, 1 = case pleine
		var remplissage := clampf(affiche - i, 0.0, 1.0)
		var case: MeshInstance3D = get_node("Case%d" % (i + 1))
		case.material_override.albedo_color = COULEUR_VIDE.lerp(COULEURS[i], remplissage)
