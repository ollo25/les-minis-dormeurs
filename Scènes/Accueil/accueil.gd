extends Control
# Écran d'accueil : affiche si l'Arduino (le bébé) est connecté et lance le jeu.

@onready var status_dot = %StatusDot
@onready var status_label = %StatusLabel
@onready var bouton_jouer = %BoutonJouer

func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_connected)
	ArduinoManager.arduino_disconnected.connect(_on_arduino_disconnected)

	if ArduinoManager._paired:
		_on_arduino_connected()
	else:
		_on_arduino_disconnected()

func _on_arduino_connected():
	status_dot.color = Color.GREEN
	status_label.text = "Arduino connecté"
	bouton_jouer.disabled = false

func _on_arduino_disconnected():
	status_dot.color = Color.RED
	status_label.text = "Arduino pas connecté"
	bouton_jouer.disabled = true

func _on_bouton_jouer_pressed() -> void:
	Partie.mode_debug = false
	g_vars.no_arduino = false
	get_tree().change_scene_to_file("res://Scènes/Chambre/Chambre.tscn")

func _on_bouton_vr_sans_arduino_pressed() -> void:
	# VR avec le casque, mais sans la poupée Arduino (pour tester en attendant)
	Partie.mode_debug = false
	g_vars.no_arduino = true
	get_tree().change_scene_to_file("res://Scènes/Chambre/Chambre.tscn")

func _on_bouton_debug_pressed() -> void:
	Partie.mode_debug = true
	g_vars.no_arduino = true
	get_tree().change_scene_to_file("res://Scènes/Chambre/Chambre.tscn")

func _on_bouton_quitter_pressed() -> void:
	get_tree().quit()
