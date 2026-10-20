# Demo Professor - Sound & Arduino Control Game

This demo project showcases how to create a Godot game that uses sound as a primary gameplay mechanic and integrates Arduino hardware for alternative control methods.

## Hackathon Le Rebours, 19–23 octobre 2026 : versions imposées et démarrage rapide

| Outil | Version | Pourquoi |
|---|---|---|
| **Godot** | **4.7.2** (standard) | Le projet est testé avec cette version ; `config/features` = 4.7. Pas 4.6, pas 4.7.0. |
| **FMOD GDExtension** | **6.1.0** (`addons/fmod/`, moteur FMOD 2.03.06) | Seule release compatible ; déjà dans le dépôt, rien à installer. |
| **FMOD Studio** (pour construire les banques) | **2.03.x, jamais 2.04** | Une banque construite en 2.04 est refusée par le plugin. |
| **GdSerial** | **0.3.0** (`addons/gdserial/`) | Communication série avec l'Arduino ; déjà dans le dépôt. |

**Démarrer :**
1. Cloner la branche `hackathon-oct-2026` (ou télécharger le zip). Sur **Mac**, si une alerte « non ouvert » apparaît ou si Godot se fige à l'ouverture : lire `INSTALLATION_PLUGINS_MACOS.md` (cliquer **Terminé**, jamais Corbeille, puis `xattr -cr <dossier du projet>`).
2. Ouvrir `project.godot` dans Godot 4.7.2. Si des erreurs rouges `Nonexistent function … in base 'FmodServer'` apparaissent au premier import, fermer et rouvrir le projet : elles disparaissent.
3. F5 : écran de démarrage. Brancher l'Arduino (sketch `Arduino Code/AdaptGodot/AdaptGodot.ino`) → pastille verte → **Start Game**. Sans carte : **Start Game with no Arduino** (clavier/souris).
4. **Avant tout « Refresh banks » dans l'explorateur FMOD, sauvegarder la scène** (crash connu du plugin, détail dans `docs/FMOD-PIEGES.md`).

**Arduino :** la carte est gérée par l'autoload `ArduinoManager` (`Scènes/Integration_Arduino/arduino_manager.gd`). Signaux disponibles : `arduino_connected`, `arduino_disconnected`, `button_changed(bool)`, `potentiometre_updated(float)`, `ultrason_updated(float)`, `sensor_changed(int)`, `encoder_changed(position, delta)`, `message_received(clé, valeur)` pour toute autre trame `clé:valeur`. Commandes : `send_led(bool)`, `send_blink(n)`, `send_vibe(bool)`, `send_ping()`.
- Forcer un port : variable d'environnement `ARDUINO_PORT=COM7` (Windows) ou `ARDUINO_PORT=/dev/cu.usbmodem1101` (Mac).
- Voir le détail de l'appairage : `ARDUINO_DEBUG=1`.
- Tester sans carte : `python3 tests/simulateur_arduino.py --tcp 5555 --profil prof` puis lancer Godot avec `ARDUINO_PORT=tcp://127.0.0.1:5555` (voir `docs/NOTES-POUR-TOM.md`).
- Débrancher les téléphones en USB pendant les tests : ils apparaissent comme des ports série.

Documents : **`docs/DEPANNAGE.md` (un problème ? symptôme → geste)**, `docs/REPRISE-AGENT.md` (reprise à froid pour un humain ou un agent IA : règles, carte du code, pannes prévisibles), `tools/strip_fmod_param_cache.sh` (remède au crash FMOD après reconstruction de banque), `docs/CHECKLIST-TEST-4.7.2.md` (ce qui a été testé et ce qui reste à tester), `docs/NOTES-POUR-TOM.md` (changements du code série, bugs relevés dans le sketch), `docs/QUESTIONS-GODOT-BLOCKS.md` (points ouverts), `docs/FMOD-PIEGES.md` (événements et paramètres FMOD, paramètres locaux vs globaux, crashs connus du plugin et comment s'en sortir), `docs/PROTOCOLE-ARDUINO-GODOT.md` (protocole série détaillé).

---

## Features



### Main Features
- **Sound-based Navigation**: Primary collectible objects emit sounds that guide the player
- **Arduino Control**: Use an Arduino with ultrasonic sensor and potentiometer for alternative controls
- **Progressive Ambiance**: The environment's sound changes as objects are collected

### New Features
- **Ground Collectibles with Haptic Feedback**: Special objects on the ground level trigger vibration via Arduino
- **Improved Arduino Altitude Control**: Character defaults to ground level when hand is removed from ultrasonic sensor
- **Dual Control Mode**: Toggle between Arduino and keyboard/mouse with the "ArduinoToggle" input action

## Controls

### Arduino Controls
- **Altitude Control**: Move hand closer/further from ultrasonic sensor (defaults to ground when hand is removed)
- **Rotation Control**: Turn potentiometer to rotate character
- **Haptic Feedback**: Vibration motor intensity increases as player gets closer to ground collectibles

### Keyboard/Mouse Controls
- **Altitude**: Press "Jump" key to ascend, "Run" key to descend
- **Rotation**: Move mouse left/right
- **Toggle Mode**: Press the configured "ArduinoToggle" key to switch between Arduino and keyboard/mouse control

## Arduino Setup

### Hardware Requirements
- Arduino board (e.g., Arduino Uno)
- Ultrasonic distance sensor (HC-SR04)
- Potentiometer
- Vibration motor
- Resistors and wiring as needed

### Connections
1. Connect ultrasonic sensor's TRIG pin to Arduino pin 9
2. Connect ultrasonic sensor's ECHO pin to Arduino pin 10
3. Connect potentiometer to Arduino analog pin A0
4. Connect vibration motor to Arduino PWM pin 3 (through appropriate transistor/driver)

### Software Setup
1. Upload the `Arduino_Vibration_Sample.ino` sketch to your Arduino
2. Configure the COM port in `Arduino_Manager.cs` if needed (default is COM3)

## Gameplay Elements

### Sound Collectibles
- Primary objects that emit sounds
- Collecting one activates the next in the chain
- Creates a progression through the level
- Develops the ambient soundscape as they are collected

### Ground Collectibles
- Located at ground level throughout the environment
- Emit a green glow and pulse effect
- Provide haptic feedback via vibration when nearby
- Can be collected by touching them

## Implementation Notes

### Future FMOD Integration
- Sound placeholders are included that will be replaced with FMOD events
- Ground collectible sounds and footstep sounds will be implemented with FMOD

### Arduino Communication
- The game sends vibration intensities (0-9) as ASCII characters to the Arduino
- The Arduino responds with sensor data in the format "distance:potentiometer_value"
- Enhanced error handling ensures the game recovers gracefully from disconnections

## Development Notes

This project demonstrates:
1. Integration of alternative control schemes in Godot
2. Sound-based gameplay mechanics
3. Progressive audio environments
4. Haptic feedback integration
5. Separating input systems for easier debugging 
