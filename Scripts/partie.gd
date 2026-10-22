extends Node
## Autoload "Partie" : l'état global de la partie, partagé entre les scènes.

## Émis quand le joueur ramasse un objet (le son d'indice se branchera ici).
signal objet_ramasse_signal(objet)
## Émis quand un objet est rangé au bon endroit.
signal objet_range_signal(objet)
## Émis quand tous les objets sont rangés.
signal victoire

## true = mode debug : pas de casque, pas de poupée, on joue au clavier/souris.
var mode_debug: bool = false

## Le point qui sert de "main" au joueur (main droite en VR, devant la caméra en debug).
## Sert par exemple à ouvrir les tiroirs quand on s'en approche.
var noeud_main: Node3D = null

var objets_ranges: int = 0

## true quand la partie est terminée (victoire ou défaite) : on ne peut plus jouer.
var partie_finie: bool = false

## Noms lisibles des destinations (uniquement pour la console de debug :
## le joueur, lui, n'a AUCUNE info écrite, tout passe par le son).
const NOMS_DESTINATIONS := {
	"BacAJouets": "le bac à jouets",
	"TableDeNuit": "la table de nuit",
	"Tiroir_Haut": "le tiroir du haut de la commode",
	"Tiroir_Milieu": "le tiroir du milieu de la commode",
	"Tiroir_Bas": "le tiroir du bas de la commode",
}


## Appelé par un objet quand on le ramasse.
func objet_ramasse(objet) -> void:
	var ou: String = NOMS_DESTINATIONS.get(objet.destination, objet.destination)
	# Console seulement (panneau Sortie de Godot), invisible pour le joueur
	print("[Partie] Ramassé : %s → à ranger dans %s" % [objet.nom_affiche, ou])
	# TODO son : jouer ici l'audio (chuchotement) qui indique la destination de cet objet.
	# C'est la SEULE façon pour le joueur de savoir où ranger l'objet.
	objet_ramasse_signal.emit(objet)


## Appelé par un objet quand il est rangé au bon endroit.
func objet_range(objet) -> void:
	objets_ranges += 1
	var total := get_tree().get_nodes_in_group("objets_rangeables").size()
	print("[Partie] Rangé : %s (%d / %d)" % [objet.nom_affiche, objets_ranges, total])
	# TODO son : petit son de dépôt réussi
	objet_range_signal.emit(objet)
	if objets_ranges >= total:
		print("[Partie] VICTOIRE : tout est rangé !")
		partie_finie = true
		victoire.emit()


## Position de la main du joueur (ou très loin s'il n'y en a pas encore).
func position_main() -> Vector3:
	if noeud_main == null or not is_instance_valid(noeud_main):
		return Vector3(9999, 9999, 9999)
	return noeud_main.global_position


## Remet le compteur à zéro au début d'une partie.
func nouvelle_partie() -> void:
	objets_ranges = 0
	partie_finie = false
