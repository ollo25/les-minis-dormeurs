# tests/test_footsteps_headless.gd — vérifie SANS écouter que l'événement FMOD « Footsteps » de Demo_Prof
# démarre et que son paramètre CharacterWalk bascule entre CharacterFly (en l'air) et CharacterWalk (au sol).
# Lancer, son coupé (FMOD joue sur les enceintes même en headless), depuis le dossier du projet :
#   ARDUINO_PORT=/dev/cu.inexistant "<Godot>" --headless --path . res://tests/test_footsteps_headless.tscn
# Attendu : "[PAS] signal started reçu", "en l'air → CharacterFly", "au sol → CharacterWalk", code de sortie 0.
extends Node

var _t := 0
var _jeu: Node
var _joueur: CharacterBody3D
var _emetteur
var _demarre := false
var _ok := true

func _ready() -> void:
	g_vars.no_arduino = true  # pas de scan des ports : mode clavier/souris
	_jeu = load("res://Scènes/Demo_Prof/Demo_Prof.tscn").instantiate()
	add_child(_jeu)
	_joueur = _jeu.get_node("JoueurDemo")
	_emetteur = _joueur.get_node("FmodEventEmitter3D_footsteps")
	_emetteur.started.connect(func(): _demarre = true; print("[PAS] signal started reçu"))

func _physics_process(_delta: float) -> void:
	_t += 1
	if _t == 10:
		_joueur.global_position.y = 10.0  # en l'air
	if _t == 20:
		print("[PAS] événement démarré = ", _demarre, " ; en l'air → ", _emetteur.get_parameter("CharacterWalk"))
		_ok = _ok and _demarre and str(_emetteur.get_parameter("CharacterWalk")) == "CharacterFly"
		_joueur.global_position.y = 1.0  # au sol (seuil is_near_ground : y < 2.1)
	if _t == 30:
		print("[PAS] au sol → ", _emetteur.get_parameter("CharacterWalk"), " (y=", _joueur.global_position.y, ")")
		_ok = _ok and str(_emetteur.get_parameter("CharacterWalk")) == "CharacterWalk"
		print("[PAS] BILAN ok=", _ok)
		get_tree().quit(0 if _ok else 1)
