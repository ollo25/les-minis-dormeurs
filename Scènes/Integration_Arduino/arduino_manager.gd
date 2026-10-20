# arduino_manager.gd — autoload « ArduinoManager »
# Appairage automatique avec la carte Arduino (protocole DISCOVER / GDSERIAL_ACK, 115200 bauds),
# lecture des trames « clé:valeur » et envoi des commandes (led, blink, vibe, ping).
#
# Hackathon oct. 2026 : fusion de la version Godot_Blocks (avril 2026) et des correctifs de la nuit du 15/10
# (HACKATHON-NUIT/T4-arduino). Tout ce qui existait reste disponible (signaux, g_vars.no_arduino, send_vibe).
# Nouveautés :
#   - trames « sensor:<0..1023> » et « enc:<position> » traitées (avant, elles étaient ignorées) ;
#   - signal générique message_received(clé, valeur) pour vos propres capteurs ;
#   - clés acceptées en minuscules ou majuscules ("ENC:3" = "enc:3") ;
#   - le tampon est vidé à chaque appairage et les trames arrivées avec l'ACK ne sont plus perdues ;
#   - ARDUINO_PORT=<port> force un port (ex. ARDUINO_PORT=COM7 ou /dev/cu.usbmodem1101) ;
#     ARDUINO_PORT=tcp://127.0.0.1:5555 branche le simulateur Python (tests sans carte) ;
#   - ARDUINO_DEBUG=1 affiche le détail de l'appairage.
extends Node2D

# ── Signaux ────────────────────────────────────────────
signal arduino_disconnected()
signal arduino_connected()
signal pairing_success(port: String)
signal pairing_failed()
signal potentiometre_updated(value: float)                 # trame "potentiometre:<valeur>" (sketch AdaptGodot)
signal ultrason_updated(value: float)                      # trame "ultrason:<cm>" (sketch AdaptGodot)
signal button_changed(pressed: bool)                       # trame "button:0|1"
signal sensor_changed(value: int)                          # trame "sensor:<0..1023>" (sketch GODOTSERIAL, capteur A0)
signal encoder_changed(position: int, delta: int)          # trame "enc:<position>" (encodeur rotatif)
signal message_received(key: String, value: String)        # TOUTE trame "clé:valeur" reçue

# ── Constantes de pairing ──────────────────────────────
const DISCOVER_MSG  := "DISCOVER"
const ACK_PREFIX    := "GDSERIAL_ACK"
const PAIR_TIMEOUT  := 0.35   # secondes d'attente par port
const BAUD_RATE     := 115200
const SCAN_RETRY_COOLDOWN := 2.0   # secondes avant de relancer un scan après un échec
# Seuls les ports dont le nom contient un de ces indices sont essayés : évite d'ouvrir
# tty.Bluetooth-Incoming-Port / tty.debug-console sur macOS (ça bloque le scan). "COM" = Windows.
const PORT_NAME_HINTS := ["usbmodem", "usbserial", "ttyACM", "ttyUSB", "COM"]
# Port forcé par la variable d'environnement ARDUINO_PORT. S'il est défini, c'est le SEUL port essayé,
# même s'il n'apparaît pas dans list_ports(). Pas de fichier de configuration : un fichier oublié
# empêcherait de retrouver la vraie carte.
const PORT_OVERRIDE_ENV := "ARDUINO_PORT"

# ── État interne ───────────────────────────────────────
var serial  # un GdSerial (vraie carte) ou un SerialTcpSimu (simulateur, si ARDUINO_PORT=tcp://...)
var _paired: bool   = false
var _wasPaired: bool = false
var _is_pairing: bool = false   # garde contre la ré-entrance (process tourne à 60 Hz)
var _pairing_cooldown: float = 0.0
var _buffer: String = ""
var paired_port: String = ""
var timerHeartBeat: float = 0.0
var timerHeartBeatMax: float = 2.0
var lastPortNameUsed
# Dernières valeurs reçues (pour qui préfère lire une variable plutôt qu'écouter un signal)
var sensor_value: int = 0
var encoder_position: int = 0
var button_pressed: bool = false
var _debug: bool = OS.get_environment("ARDUINO_DEBUG") == "1"

func _ready() -> void:
	if _get_port_override().begins_with("tcp://"):
		serial = SerialTcpSimu.new()  # test sans carte : voir serial_tcp_simu.gd
	else:
		serial = GdSerial.new()
	serial.set_baud_rate(BAUD_RATE)
	serial.set_timeout(10)
	start_pairing()


# ══ PAIRING ═══════════════════════════════════════════

func start_pairing() -> void:
	if g_vars.no_arduino:
		return
	if _is_pairing:
		return  # scan déjà en cours, évite d'empiler des coroutines
	_is_pairing = true
	_paired = false
	_wasPaired = false
	paired_port = ""
	encoder_position = 0  # l'Arduino repart de 0 à chaque reset (ouverture du port)
	_buffer = ""          # oublie les morceaux de trame de l'ancienne connexion
	_dbg("[Pairing] Démarrage du scan des ports...")
	var candidates: Array = []
	var override := _get_port_override()
	if override != "":
		# Port forcé : on n'essaie QUE lui (on n'envoie pas DISCOVER aux autres appareils).
		_dbg("[Pairing] Port forcé : " + override)
		candidates.append({"port_name": override})
	else:
		var ports: Dictionary = serial.list_ports()
		for port_info in ports.values():
			var port_name: String = port_info["port_name"]
			for hint in PORT_NAME_HINTS:
				if port_name.contains(hint):
					candidates.append(port_info)
					break
	if candidates.is_empty():
		_dbg("[Pairing] Aucun port Arduino-like détecté.")
		_pairing_cooldown = SCAN_RETRY_COOLDOWN
		_is_pairing = false
		emit_signal("pairing_failed")
		return

	# Lance le scan asynchrone sans bloquer Godot
	_scan_ports(candidates)


func _scan_ports(port_list: Array) -> void:
	if g_vars.no_arduino:
		_is_pairing = false
		return
	for port_info in port_list:
		var port_name: String = port_info["port_name"]
		_dbg("[Pairing] Test de : " + port_name)
		serial.set_port(port_name)

		if not serial.open():
			_dbg("[Pairing]   → impossible d'ouvrir")
			continue

		serial.clear_buffer()

		# Attend que l'Arduino finisse son boot après l'ouverture du port
		await get_tree().create_timer(0.5).timeout

		# Envoie DISCOVER plusieurs fois au cas où le premier serait perdu
		for i in range(3):
			serial.writeline(DISCOVER_MSG)
			await get_tree().create_timer(0.1).timeout
			var response := _read_all_available()
			_dbg("[Pairing]   tentative %d → '%s'" % [i + 1, response.strip_edges()])
			if ACK_PREFIX in response:
				# Garde ce qui suit la ligne d'ACK (premières trames capteur déjà arrivées)
				var fin_ack := response.find("\n", response.find(ACK_PREFIX))
				_buffer = response.substr(fin_ack + 1) if fin_ack != -1 else ""
				paired_port = port_name
				_paired = true
				_wasPaired = true
				lastPortNameUsed = port_name
				print("[Pairing]   → CONNECTÉ sur ", port_name)
				_is_pairing = false
				emit_signal("pairing_success", port_name)
				emit_signal("arduino_connected")
				return

		_dbg("[Pairing]   → pas de réponse")
		serial.close()

	_dbg("[Pairing] Aucun Arduino trouvé.")
	_pairing_cooldown = SCAN_RETRY_COOLDOWN
	_is_pairing = false
	emit_signal("pairing_failed")


func _get_port_override() -> String:
	return OS.get_environment(PORT_OVERRIDE_ENV).strip_edges()


func _dbg(msg: String) -> void:
	if _debug:
		print(msg)


func _read_all_available() -> String:
	var result := ""
	if serial.bytes_available() > 0:
		result = serial.read_string(serial.bytes_available())
	return result


# ══ COMMUNICATION EN TEMPS RÉEL ════════════════════════

func _process(_delta: float) -> void:
	if g_vars.no_arduino:
		return
	timerHeartBeat -= _delta
	if _pairing_cooldown > 0.0:
		_pairing_cooldown -= _delta
	if _paired :
		if timerHeartBeat < 0 :
			timerHeartBeat = timerHeartBeatMax
			if not serial.is_open() :
				emit_signal("arduino_disconnected")
				_paired = false

	if not _paired:
		if not _is_pairing and _pairing_cooldown <= 0.0:
			start_pairing()
		return

	while serial.bytes_available() > 0:
		_buffer += serial.read_string(serial.bytes_available())

	while "\n" in _buffer:
		var idx  := _buffer.find("\n")
		var line := _buffer.substr(0, idx).strip_edges()
		_buffer   = _buffer.substr(idx + 1)
		if line.length() > 0:
			_parse_message(line)

func _parse_message(msg: String) -> void:
	var parts := msg.split(":", false, 1)
	if parts.size() < 2:
		return

	var key := parts[0].to_lower()  # "ENC:3" et "enc:3" sont acceptés
	var value := parts[1]
	emit_signal("message_received", key, value)

	match key:
		"ultrason":
			emit_signal("ultrason_updated", value.to_float())
		"potentiometre":
			emit_signal("potentiometre_updated", value.to_float())
		"button":
			button_pressed = value == "1"
			emit_signal("button_changed", button_pressed)
		"sensor":
			sensor_value = value.to_int()
			emit_signal("sensor_changed", sensor_value)
		"enc":
			var new_position := value.to_int()
			var delta := new_position - encoder_position
			encoder_position = new_position
			if delta != 0:
				emit_signal("encoder_changed", encoder_position, delta)
		"pong":
			print("[Arduino] Latence mesurée : ", Time.get_ticks_msec() - value.to_int(), " ms")
		"ack":
			print("[Arduino] Ack : ", value)
		_:
			_dbg("[Arduino] Message inconnu : " + msg)

# ══ API PUBLIQUE ══════════════════════════════════════

func send_led(on: bool) -> void:
	_send("led:" + ("1" if on else "0"))

func send_blink(times: int) -> void:
	_send("blink:" + str(times))

func send_vibe(on: bool) -> void:
	_send("vibe:" + ("1" if on else "0"))

func send_ping() -> void:
	_send("ping:" + str(Time.get_ticks_msec()))

var _warned_unpaired: bool = false  # un seul avertissement par période « non appairé » (sinon 60 lignes/s)

func _send(cmd: String) -> void:
	if not _paired:
		if not _warned_unpaired:
			_warned_unpaired = true
			push_warning("[Arduino] Non pairé, commandes ignorées (première : " + cmd + ")")
		return
	_warned_unpaired = false
	serial.writeline(cmd)


func _exit_tree() -> void:
	if serial and serial.is_open():
		serial.close()
