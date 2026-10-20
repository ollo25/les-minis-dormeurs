# tests/test_vibration_simu_headless.gd — AVEC le simulateur Arduino (profil prof, vrai appairage série simulé) :
# vérifie que Demo_Prof n'envoie la commande « vibe » qu'au CHANGEMENT d'état (près / loin d'un palet au sol),
# et plus 60 fois par seconde. Lancer, son coupé, depuis le dossier du projet :
#   python3 tests/simulateur_arduino.py --tcp 5555 --profil prof --muet > simu.log &
#   ARDUINO_PORT=tcp://127.0.0.1:5555 "<Godot>" --headless --path . res://tests/test_vibration_simu_headless.tscn
# Attendu : code de sortie 0, et dans simu.log la séquence « <- vibe:0 » (appairage), « <- vibe:1 » (joueur posé à 3 m
# du palet 2), « <- vibe:0 » (joueur éloigné) : exactement 3 lignes, le rappel périodique (rappel_vibration, 1 s par
# défaut, un renvoi du même état) étant désactivé par le test. Le joueur est maintenu en place à chaque image.
extends Node

var _t := 0
var _jeu: Node
var _joueur: CharacterBody3D
var _apparie := false
var _cible := Vector3.ZERO
var _forcer := false

func _ready() -> void:
	ArduinoManager.arduino_connected.connect(func(): _apparie = true; print("[VIBE] appairé à l'image ", _t))
	_jeu = load("res://Scènes/Demo_Prof/Demo_Prof.tscn").instantiate()
	add_child(_jeu)
	_joueur = _jeu.get_node("JoueurDemo")
	_joueur.rappel_vibration = 0.0  # pas de rappel périodique ici : on veut compter les seuls changements d'état (3)

func _physics_process(_delta: float) -> void:
	_t += 1
	if _forcer:
		_joueur.global_position = _cible  # le parent passe avant l'enfant : le joueur part de là à chaque image
	if _t == 120:  # 2 s : l'appairage simulateur prend ~0,6 s
		print("[VIBE] appairé=", _apparie, " mode Arduino=", _joueur.Is_Arduino_Mode_On, " seuil=", _joueur.distance_vibration, " état envoyé=", _joueur._vibration_envoyee)
		_cible = Vector3(25.0, 3.0, 20.0)  # loin de tout palet (le plus proche à ~16 m)
		_forcer = true
	if _t == 180:
		_cible = Vector3(25.0, 3.0, -5.0)  # à 3 m du palet 2 (25, 2, -8) : sous le seuil → vibe:1
	if _t == 240:
		_cible = Vector3(25.0, 3.0, 20.0)  # loin → vibe:0
	if _t == 300:
		print("[VIBE] FIN appairé=", _apparie, " état envoyé=", _joueur._vibration_envoyee, " (attendu 0) ; compter les lignes « <- vibe: » du simulateur : attendu 3")
		get_tree().quit(0 if _apparie and _joueur._vibration_envoyee == 0 else 1)
