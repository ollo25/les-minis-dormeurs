# main.gd — scène d'exemple « Integration_Arduino » : montre comment écouter l'autoload ArduinoManager.
# L'Arduino est géré par l'autoload ArduinoManager (project.godot → Autoload) : il n'y a PAS d'instance
# du manager dans cette scène (hackathon oct. 2026 : l'ancienne scène en avait une deuxième, ce qui faisait
# deux scans des ports en parallèle et une erreur de type Node/Node2D).

extends Node2D

func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_ready)
	ArduinoManager.arduino_disconnected.connect(func(): $Label.text = "Arduino : déconnecté")
	ArduinoManager.sensor_changed.connect(_on_sensor)                 # sketch GODOTSERIAL : "sensor:0..1023"
	ArduinoManager.potentiometre_updated.connect(_on_potentiometre)   # sketch AdaptGodot : "potentiometre:<valeur>"
	ArduinoManager.button_changed.connect(_on_button)
	if ArduinoManager.paired_port != "":
		_on_arduino_ready()

func _on_arduino_ready() -> void:
	$Label.text = "Arduino : connecté sur " + ArduinoManager.paired_port
	print("Arduino en ligne, envoi d'un ping...")
	ArduinoManager.send_ping()

func _on_sensor(value: int) -> void:
	# value est entre 0 et 1023
	$Label.position.x = value / 1023.0 * 800.0

func _on_potentiometre(value: float) -> void:
	# AdaptGodot.ino envoie analogRead(A0), donc 0..1023
	$Label.position.x = clampf(value / 1023.0, 0.0, 1.0) * 800.0

func _on_button(pressed: bool) -> void:
	if pressed:
		$Label.add_theme_color_override("font_color", Color.RED)
	else:
		$Label.add_theme_color_override("font_color", Color.BLUE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		ArduinoManager.send_led(true)
	if event.is_action_released("ui_accept"):
		ArduinoManager.send_led(false)
