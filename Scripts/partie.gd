extends Node
## Autoload "Partie" : l'état global de la partie, partagé entre les scènes.

## Émis quand le joueur ramasse un objet (le son d'indice se branchera ici).
signal objet_ramasse_signal(objet)
## Émis quand un objet est rangé au bon endroit.
signal objet_range_signal(objet)
## Émis quand tous les objets sont rangés.
signal victoire
## Émis quand la partie est perdue. raison = "reveil" (bébé trop secoué) ou "temps" (5 min écoulées).
signal defaite(raison)

## true = mode debug : pas de casque, pas de poupée, on joue au clavier/souris.
var mode_debug: bool = false

## Le point qui sert de "main" au joueur (main droite en VR, devant la caméra en debug).
## Sert par exemple à ouvrir les tiroirs quand on s'en approche.
var noeud_main: Node3D = null

var objets_ranges: int = 0

## true quand la partie est terminée (victoire ou défaite) : on ne peut plus jouer.
var partie_finie: bool = false

const DUREE_PARTIE := 300.0          # 5 minutes
var temps_restant: float = DUREE_PARTIE

## Dernier niveau de mouvement envoyé par l'Arduino du bébé :
## 0 = immobile … 5 = très secoué. (Ligne "NIVEAU:x" reçue sur le port série.)
var niveau_mouvement: int = 0
## Mesure brute du gyroscope (pour régler les seuils de l'Arduino, affichée dans la console)
var intensite_brute: int = 0

## ---------- Jauge INVISIBLE d'agitation du bébé ----------
## De 0 (il dort bien) à 100 (il se réveille = défaite). Le joueur ne la voit pas :
## il la devine grâce aux sons du bébé et aux vibrations de la poupée.
const JAUGE_MAX := 100.0
## Combien la jauge monte (+) ou descend (-) par SECONDE, selon le mouvement 0 à 5 :
##   0, 1, 2 = doux → elle redescend (vite quand on ne bouge pas du tout)
##   3 = un peu brusque → elle monte doucement   (≈ 12 s pour la remplir)
##   4 = brusque        → elle monte plus vite   (≈ 5 s)
##   5 = brutal         → elle monte très vite   (≈ 2,5 s)
## (Version d'avant : 4 / 8 / 17, il fallait secouer fort trop longtemps.)
const VITESSE_JAUGE := [-40.0, -25.0, -10.0, 8.0, 20.0, 40.0]
var jauge: float = 0.0
var partie_lancee: bool = false     # true seulement pendant une partie (pas dans le menu)

## true pendant l'écran de tuto du début : le chrono et la jauge attendent.
var tuto_en_cours: bool = false
signal tuto_ferme

## Les états du bébé, selon la jauge (servent pour les sons ET les vibrations)
const CALME := 0              # 0 à 24 %
const AGITE := 1              # 25 à 49 %
const TRES_AGITE := 2         # 50 à 74 %
const PRESQUE_REVEILLE := 3   # 75 à 99 %
const REVEILLE := 4           # 100 % : défaite

## Vibrations de la poupée selon l'état : petits coups, comme un bébé qui gigote.
## [durée d'un coup en s, temps entre deux coups en s, force de 0 à 255]
## (en dessous de ~80, un petit moteur vibrant peut ne pas démarrer : à tester sur la poupée)
const VIBRATIONS := {
	AGITE: [0.3, 1.2, 140],             # de temps en temps, moyen
	TRES_AGITE: [0.35, 0.7, 180],       # plus souvent, plus fort
	PRESQUE_REVEILLE: [0.4, 0.35, 230], # presque sans arrêt, très fort
}
const DUREE_VIBRATION_REVEIL := 2.0              # au réveil : 2 s sans arrêt...
const FORCE_VIBRATION_REVEIL := 255              # ...à fond
var _force_actuelle := 0
var _chrono_vibration := 0.0
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
	# Ligne de debug de l'Arduino : "PIEZO:12 GYRO_INT:345 NIVEAU:2" → on garde le 345
	elif cle == "piezo" and " GYRO_INT:" in valeur:
		intensite_brute = valeur.split(" GYRO_INT:")[1].split(" ")[0].to_int()


## Chaque image : la jauge monte ou descend selon le dernier mouvement reçu.
## Jauge pleine = le bébé se réveille = défaite.
func _process(delta: float) -> void:
	_gerer_vibration(delta)
	if not partie_lancee or partie_finie or tuto_en_cours:
		return
	jauge += VITESSE_JAUGE[niveau_mouvement] * delta
	jauge = clampf(jauge, 0.0, JAUGE_MAX)
	# Affichage console à intervalle régulier (pour régler le jeu)
	_temps_affichage += delta
	if _temps_affichage >= INTERVALLE_AFFICHAGE:
		_temps_affichage = 0.0
		_afficher_jauge()
	if jauge >= JAUGE_MAX:
		declencher_defaite("reveil")


## L'état du bébé (CALME, AGITE, TRES_AGITE, PRESQUE_REVEILLE ou REVEILLE) selon la jauge.
func etat_bebe() -> int:
	if jauge >= JAUGE_MAX:
		return REVEILLE
	if jauge >= 75.0:
		return PRESQUE_REVEILLE
	if jauge >= 50.0:
		return TRES_AGITE
	if jauge >= 25.0:
		return AGITE
	return CALME


## La poupée vibre par petits coups selon l'état du bébé, et 2 s sans arrêt au réveil.
func _gerer_vibration(delta: float) -> void:
	if _temps_vibration_reveil > 0.0:
		_temps_vibration_reveil -= delta
		_vibrer(FORCE_VIBRATION_REVEIL if _temps_vibration_reveil > 0.0 else 0)
		return
	if not partie_lancee or partie_finie:
		_vibrer(0)
		return
	var rythme: Array = VIBRATIONS.get(etat_bebe(), [])
	if rythme.is_empty():          # bébé calme : pas de vibration
		_chrono_vibration = 0.0
		_vibrer(0)
		return
	# Un "coup" = vibrer pendant rythme[0] secondes (force rythme[2]),
	# puis pause jusqu'à rythme[0] + rythme[1]
	_chrono_vibration += delta
	if _chrono_vibration >= rythme[0] + rythme[1]:
		_chrono_vibration = 0.0
	_vibrer(rythme[2] if _chrono_vibration < rythme[0] else 0)


## Envoie la force du vibreur à l'Arduino (0 = arrêt), seulement quand elle change.
func _vibrer(force: int) -> void:
	if force != _force_actuelle:
		_force_actuelle = force
		ArduinoManager.send_vibe_force(force)


## Affiche la jauge dans la console, ex. : [Bébé] ███░░░░░░░  30 %  agité   (mouvement : 4)
func _afficher_jauge() -> void:
	var pleines := roundi(jauge / 10.0)
	var barre := "█".repeat(pleines) + "░".repeat(10 - pleines)
	var noms := ["calme", "agité", "très agité", "presque réveillé", "réveillé"]
	print("[Bébé] %s %3d %%  %s   (mouvement : %d, gyro : %d)" % [barre, roundi(jauge), noms[etat_bebe()], niveau_mouvement, intensite_brute])


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
	tuto_en_cours = true


## Le joueur a lu le tuto : la partie commence vraiment (chrono + jauge).
func fermer_tuto() -> void:
	if tuto_en_cours:
		tuto_en_cours = false
		tuto_ferme.emit()


## Déclenche la défaite. raison = "reveil" (jauge pleine : le bébé s'est réveillé) ou "temps" (temps écoulé).
func declencher_defaite(raison: String) -> void:
	if partie_finie:
		return
	partie_finie = true
	print("[Partie] DÉFAITE : %s (%d objets rangés)" % [raison, objets_ranges])
	if raison == "reveil":
		_temps_vibration_reveil = DUREE_VIBRATION_REVEIL
	defaite.emit(raison)
