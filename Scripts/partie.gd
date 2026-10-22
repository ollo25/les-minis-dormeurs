extends Node
## Autoload "Partie" : l'état global de la partie, partagé entre les scènes.

## Émis quand le joueur ramasse un objet (le son d'indice se branchera ici).
signal objet_ramasse_signal(objet)
## Émis quand un objet est rangé au bon endroit.
signal objet_range_signal(objet)
## Émis quand tous les objets sont rangés.
signal victoire
## Émis quand la partie est perdue. raison = "reveil" (bébé trop secoué) ou "temps" (3 min écoulées).
signal defaite(raison)

## true = mode debug : pas de casque, pas de poupée, on joue au clavier/souris.
var mode_debug: bool = false

## Le point qui sert de "main" au joueur (main droite en VR, devant la caméra en debug).
## Sert par exemple à ouvrir les tiroirs quand on s'en approche.
var noeud_main: Node3D = null

var objets_ranges: int = 0

## true quand la partie est terminée (victoire ou défaite) : on ne peut plus jouer.
var partie_finie: bool = false

const DUREE_PARTIE := 180.0          # 3 minutes
var temps_restant: float = DUREE_PARTIE

## Dernier niveau de mouvement envoyé par l'Arduino du bébé :
## 0 = immobile … 5 = très secoué. (Ligne "NIVEAU:x" reçue sur le port série.)
var niveau_mouvement: int = 0

## Jauge d'agitation du bébé, de 0 (il dort bien) à 5 (il va se réveiller).
## Invisible pour le joueur dans le jeu : affichée seulement dans la console.
const JAUGE_MAX := 5.0
## Combien la jauge monte (+) ou descend (-) par seconde, selon le niveau de mouvement 0 à 5.
## Bébé calme (0 ou 1) → elle redescend doucement. Secoué → elle monte, de plus en plus vite.
const VITESSE_JAUGE := [-0.5, -0.2, 0.1, 0.3, 0.7, 1.5]
var jauge: float = 0.0
var partie_lancee: bool = false     # true seulement pendant une partie (pas dans le menu)
## Vibrations de la poupée : elle vibre quand le bébé est très agité (jauge à 75 % ou plus),
## et 2 secondes quand il se réveille.
const SEUIL_VIBRATION := 3.75
const DUREE_VIBRATION_REVEIL := 2.0
var _vibre := false
var _temps_vibration_reveil := 0.0

const INTERVALLE_AFFICHAGE := 0.25  # la console affiche la jauge 4 fois par seconde
var _temps_affichage := 0.0

## Noms lisibles des destinations (uniquement pour la console de debug :
## le joueur, lui, n'a AUCUNE info écrite, tout passe par le son).
const NOMS_DESTINATIONS := {
	"BacAJouets": "le bac à jouets",
	"TableDeNuit": "la table de nuit",
	"Tiroir_Haut": "le tiroir du haut de la commode",
	"Tiroir_Milieu": "le tiroir du milieu de la commode",
	"Tiroir_Bas": "le tiroir du bas de la commode",
}


func _ready() -> void:
	# L'autoload ArduinoManager (des profs) trouve la carte tout seul (COM3)
	# et nous prévient à chaque ligne "clé:valeur" reçue.
	ArduinoManager.message_received.connect(_on_message_arduino)


## Appelé à chaque ligne reçue de l'Arduino. Ex. "NIVEAU:3" → cle = "niveau", valeur = "3".
func _on_message_arduino(cle: String, valeur: String) -> void:
	if cle == "niveau":
		niveau_mouvement = clampi(valeur.to_int(), 0, 5)


## Chaque image : la jauge monte ou descend selon le dernier niveau reçu.
## Jauge pleine = le bébé se réveille = défaite.
func _process(delta: float) -> void:
	_gerer_vibration(delta)
	if not partie_lancee or partie_finie:
		return
	jauge += VITESSE_JAUGE[niveau_mouvement] * delta
	jauge = clampf(jauge, 0.0, JAUGE_MAX)
	# Affichage console à intervalle régulier
	_temps_affichage += delta
	if _temps_affichage >= INTERVALLE_AFFICHAGE:
		_temps_affichage = 0.0
		_afficher_jauge()
	if jauge >= JAUGE_MAX:
		declencher_defaite("reveil")


## La poupée vibre quand le bébé est très agité, et pendant 2 s quand il se réveille.
func _gerer_vibration(delta: float) -> void:
	if _temps_vibration_reveil > 0.0:
		_temps_vibration_reveil -= delta
		_vibrer(_temps_vibration_reveil > 0.0)
	elif partie_lancee and not partie_finie:
		_vibrer(jauge >= SEUIL_VIBRATION)
	else:
		_vibrer(false)


## Envoie "vibe:1" ou "vibe:0" à l'Arduino, seulement quand ça change.
func _vibrer(allume: bool) -> void:
	if allume != _vibre:
		_vibre = allume
		ArduinoManager.send_vibe(allume)


## Affiche la jauge dans la console, ex. : [Bébé] ███▌░ 3.5 / 5   (mouvement : 4)
func _afficher_jauge() -> void:
	var demi_cases := roundi(jauge * 2.0)     # 0 à 10
	var barre := ""
	for i in 5:
		var reste := demi_cases - i * 2
		if reste >= 2:
			barre += "█"
		elif reste == 1:
			barre += "▌"
		else:
			barre += "░"
	print("[Bébé] %s %.1f / 5   (mouvement : %d)" % [barre, jauge, niveau_mouvement])


## Appelé par un objet quand on le ramasse.
func objet_ramasse(objet) -> void:
	var ou: String = NOMS_DESTINATIONS.get(objet.destination, objet.destination)
	# Console seulement (panneau Sortie de Godot), invisible pour le joueur
	print("[Partie] Ramassé : %s → à ranger dans %s" % [objet.nom_affiche, ou])
	objet_ramasse_signal.emit(objet)   # la chambre joue le son de l'objet


## Appelé par un objet quand il est rangé au bon endroit.
func objet_range(objet) -> void:
	objets_ranges += 1
	var total := get_tree().get_nodes_in_group("objets_rangeables").size()
	print("[Partie] Rangé : %s (%d / %d)" % [objet.nom_affiche, objets_ranges, total])
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
	temps_restant = DUREE_PARTIE
	jauge = 0.0
	niveau_mouvement = 0
	_temps_affichage = 0.0
	partie_lancee = true


## Déclenche la défaite. raison = "reveil" (jauge pleine : le bébé s'est réveillé) ou "temps" (temps écoulé).
func declencher_defaite(raison: String) -> void:
	if partie_finie:
		return
	partie_finie = true
	print("[Partie] DÉFAITE : %s (%d objets rangés)" % [raison, objets_ranges])
	if raison == "reveil":
		_temps_vibration_reveil = DUREE_VIBRATION_REVEIL
	defaite.emit(raison)
