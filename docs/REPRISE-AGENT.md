# Reprise à froid — pour un humain ou un agent (Claude Code ou autre) qui doit intervenir vite sur ce projet

Écrit le 17/10/2026 au soir, avant le hackathon Le Rebours (lundi 19 → vendredi 23 octobre 2026, ~110 étudiants, 14 équipes). Lis ceci en premier si tu arrives sans contexte, par exemple pour corriger un bug en urgence pendant la semaine.

## 1. Ce qu'est ce dépôt
- `Godot_Blocks` = « Demo Prof » : jeu 3D où le son guide le joueur, contrôlé par un Arduino (ultrason + potentiomètre + vibreur) ou au clavier/souris. Il sert de **projet de base** aux 14 équipes du hackathon : chaque équipe part d'une copie (dépôt GitHub par équipe, créés par Mourdjen) et construit son jeu dessus.
- Propriétaire : Mourdjen Bari (`liaroc`). Collaborateurs : Tom (`DreaMixedReality`, Arduino et code série), Alexia (banques FMOD, GDScript). Les étudiants ne poussent pas ici : ils poussent dans leur dépôt d'équipe.
- Branches : `main` = version d'avril 2026 jusqu'à la fusion ; **`hackathon-oct-2026`** = version du hackathon (Godot 4.7.2, correctifs, docs) ; `Godot_Blocks` = vieille version C#/.NET de 2025, ignorer.
- **`gameplay-fixes`** (18/10 soir, depuis `hackathon-oct-2026`) : corrections de gameplay B.1–B.4 (bougies invisibles plus attrapables, palets qui se taisent, son `ObjectCatch` sur le joueur et pour les palets, écran de fin avec temps + Rejouer / Quitter, vibration par distance réglable envoyée au changement). **Non fusionnée : Mourdjen teste (`docs/CHECKLIST-TEST-4.7.2.md` § F) et décide.**
- **`fix-son-palets`** (18/10 soir, 21h) : = `hackathon-oct-2026` **avec le sketch encodeur de Tom (`e5ac1ed`)** + `gameplay-fixes` fusionnée (fichiers disjoints, sans conflit) + correctif durci du bug « les palets continuent de jouer leur musique une fois attrapés » (`Ground_Collectible.gd::arreter_boucle()`). **C'est la branche la plus complète ; non fusionnée, Mourdjen décide** (§ F point 8 de la checklist).

## 2. Versions et règles non négociables
- **Godot 4.7.2** standard. Pas .NET, pas 4.6, pas 4.7.0.
- **FMOD GDExtension 6.1.0** (`addons/fmod/`, moteur 2.03.06) : seule release qui marche. **Banques construites avec FMOD Studio 2.03.x, jamais 2.04** (refusées).
- **GdSerial 0.3.0** (`addons/gdserial/`). La 0.3.4 n'apporte rien, ne pas changer.
- Ne jamais committer `.godot/` **sauf** `.godot/extension_list.cfg` (voulu, voir `.gitignore`).
- Ne pas renommer les signaux de `ArduinoManager` sans prévenir Mourdjen : la vidéo du cours Godot et les projets des équipes en dépendent (`arduino_connected`, `arduino_disconnected`, `button_changed`, `potentiometre_updated`, `ultrason_updated`, `sensor_changed`, `encoder_changed`, `message_received`).
- `Scènes/Integration_Arduino/serial_tcp_simu.gd` est **requis** par `arduino_manager.gd` même s'il ne sert qu'aux tests : ne pas le supprimer.
- Pas de nom d'étudiant ni de secret dans le dépôt.

## 3. Carte du code
| Fichier | Rôle |
|---|---|
| `project.godot` | autoloads `g_vars`, `ArduinoManager`, `FmodManager` ; scène principale `Scènes/Demo_Prof/Start.tscn` ; chemin des banques FMOD |
| `Scènes/Demo_Prof/Start.tscn` + `start_screen.gd` | écran de démarrage : « Start Game » (actif si Arduino appairé) / « Start Game with no Arduino » (met `g_vars.no_arduino = true`) |
| `Scènes/Demo_Prof/Demo_Prof.tscn` + `JoueurDemo.gd` | le jeu ; `FmodBankLoader` premier enfant de la racine ; émetteurs FMOD sous `JoueurDemo` (`MusiqueNiv1`, `Footsteps`, `ObjectCatch`, `VibrObj`) |
| `Scènes/Demo_Prof/object_to_catch_1.tscn` + `Object_To_Catch_1.gd` | les 5 bougies (chaîne 1 → 2 → 5 ; 3 et 4 jamais activées) ; la 5 (`final_object`) termine la partie. Depuis `gameplay-fixes` : détection coupée tant que la bougie n'est pas activée |
| `Scènes/Demo_Prof/ground_collectible.tscn` + `Ground_Collectible.gd` | les 6 palets au sol (groupe `ground_collectibles`, boucle FMOD `VibrObj`) : font vibrer la manette à moins de `distance_vibration` (export sur `JoueurDemo`) |
| `Scènes/Demo_Prof/fin_de_partie.tscn` + `fin_de_partie.gd` | (`gameplay-fixes`, 18/10) écran de fin instancié dans Demo_Prof (`%FinDePartie`) : chronomètre, fondu, temps final, Rejouer / Quitter |
| `Scènes/Integration_Arduino/arduino_manager.gd` | autoload `ArduinoManager` : appairage série (DISCOVER / GDSERIAL_ACK, 115200), parsing `clé:valeur`, commandes `send_led/blink/vibe/ping` |
| `Scènes/Integration_Arduino/serial_tcp_simu.gd` | remplaçant de GdSerial quand `ARDUINO_PORT=tcp://…` (simulateur) |
| `Arduino Code/AdaptGodot/AdaptGodot.ino` | sketch du jeu (ultrason, potentiomètre, bouton, vibreur, 3 LED). Bugs connus : `docs/NOTES-POUR-TOM.md` |
| `Arduino Code/GODOTSERIAL_encodeur/` | brouillon de sketch pour une manette à encodeur, jamais téléversé. **Supprimé par Tom le 18/10 (`e5ac1ed`)** : l'encodeur est désormais dans `AdaptGodot.ino` (envoie `potentiometre:0..1023`, retour à 0 après un tour) |
| `Ne pas toucher/` | `g_vars.gd` (globals) et assets partagés : lecture seule |
| `tests/` | scènes headless : appairage (`test_arduino_headless`), pas (`test_footsteps_headless`), collecte / son / fin de partie / vibration (`test_collecte_headless`), vibration avec simulateur (`test_vibration_simu_headless`) ; simulateur Arduino Python (TCP) |
| `tools/strip_fmod_param_cache.sh` | remède au crash du plugin FMOD après reconstruction de banque |
| `docs/` | `DEPANNAGE.md` (symptôme → geste), `NOTES-POUR-TOM.md`, `FMOD-PIEGES.md`, `PROTOCOLE-ARDUINO-GODOT.md`, `CHECKLIST-TEST-4.7.2.md`, `QUESTIONS-GODOT-BLOCKS.md`, `logs/` |

## 4. Comment tester sans casser (Mac)
```bash
GODOT="/Applications/Godot 4.7.2.app/Contents/MacOS/Godot"
cd /Users/mourdjenbari/Documents/Godot_Blocks
osascript -e 'set volume output muted true'          # FMOD joue sur les enceintes MÊME en headless
"$GODOT" --headless --path . --import --quit          # 1er import : peut crasher à la sortie (signal 11), relancer
"$GODOT" --headless --path . --import --quit
ARDUINO_PORT=/dev/cu.inexistant "$GODOT" --headless --path . --quit-after 300           # scène Start, sans toucher aux vrais ports
python3 tests/simulateur_arduino.py --tcp 5555 --profil prof &                          # simulateur
ARDUINO_PORT=tcp://127.0.0.1:5555 "$GODOT" --headless --path . res://tests/test_arduino_headless.tscn   # attendu : [TEST] BILAN apparie=true
ARDUINO_PORT=/dev/cu.inexistant "$GODOT" --headless --path . res://tests/test_collecte_headless.tscn     # attendu : [COLLECTE] BILAN ok=true (gameplay-fixes)
ARDUINO_PORT=tcp://127.0.0.1:5555 "$GODOT" --headless --path . res://tests/test_vibration_simu_headless.tscn  # puis compter « <- vibe: » dans la sortie du simulateur : 3
kill %1 ; osascript -e 'set volume output muted false'
```
- Il n'y a pas de `timeout` sur le Mac de Mourdjen : si Godot ne rend pas la main, `pkill -f "Godot_Blocks"`.
- Sans `ARDUINO_PORT`, le scan envoie `DISCOVER` à tout port `usbmodem` : débrancher les téléphones.
- Les logs de référence du 17/10 sont dans `docs/logs/` : compare avant de conclure à une régression.
- Pièges FMOD vus le 18/10 en écrivant les tests : `FmodServer.get_event("event:/X")` ne trouve rien, passer par `get_event_from_guid` (et `check_event_guid` avant) ; le 2ᵉ `play()` d'un émetteur émet `restarted`, pas `started` ; `stop()` n'enlève pas l'instance (`get_instance_count` inchangé, regarder `get_playback_state`) ; libérer `Demo_Prof` décharge la banque (le `FmodBankLoader` part avec), donc « Cannot find event » juste après est normal ; les émetteurs enfants d'un nœud **caché** (`hide()`) ne démarrent pas leur événement.
- Pièges FMOD vus le 18/10 soir (bug des palets) : `allow_fadeout` est **vrai par défaut** sur un émetteur, donc `stop()` = `FMOD_STUDIO_STOP_ALLOWFADEOUT` (l'instance reste en STOPPING le temps du relâchement de l'événement : 1 à 3 images mesurées pour `VibrObj` aujourd'hui, donc inaudible, mais c'est la banque qui décide) ; l'émetteur n'a **pas** de `release()` public : c'est sa **sortie de l'arbre** (`remove_child` / `queue_free`) qui libère l'instance (`get_instance_count` baisse alors) ; `hide()` n'a aucun effet sur FMOD. Pour couper un son pour de bon : `allow_fadeout = false`, `stop()`, puis retirer l'émetteur de l'arbre.
- **Rien n'a été testé dans l'éditeur fenêtré, ni avec une vraie carte, ni sous Windows** au 17/10 (voir `docs/CHECKLIST-TEST-4.7.2.md`). Mourdjen et Tom le font dimanche 18.

## 5. Les problèmes qui vont arriver pendant la semaine, et le geste
| Symptôme probable | Cause | Geste | Détail |
|---|---|---|---|
| Mac : « non ouvert », Godot figé | quarantaine des plugins | `xattr -cr <projet>`, jamais Corbeille | `INSTALLATION_PLUGINS_MACOS.md` |
| 10 erreurs rouges `FmodServer` | premier import | fermer / rouvrir | `DEPANNAGE.md` |
| Godot disparaît au Cmd+S ou au clic sur un émetteur | cache `fmod_parameters/*/id` périmé après rebuild de banque | Godot fermé, `tools/strip_fmod_param_cache.sh` | `FMOD-PIEGES.md` § 2b |
| banque refusée | construite en FMOD Studio 2.04 | reconstruire en 2.03 | `DEPANNAGE.md` |
| `Cannot set parameter X` | mauvais nom, paramètre global, ou paramètre automatique | voir tableau des 4 causes | `FMOD-PIEGES.md` § 4 |
| musique OK mais pas de bruits de pas | en l'air (main devant le capteur) = silence voulu ; ou émetteur 2D pour l'événement 3D `Footsteps` | descendre au sol ; l'émetteur doit rester un `FmodEventEmitter3D` enfant du joueur | `DEPANNAGE.md`, `QUESTIONS` 15 |
| Arduino jamais appairé | moniteur série ouvert, téléphone en USB, sketch sans `GDSERIAL_ACK`, pilote Windows | `ARDUINO_DEBUG=1`, `ARDUINO_PORT=…` | `DEPANNAGE.md`, `NOTES-POUR-TOM.md` |
| plus d'appairage après débranchement (Leonardo / Uno R4) | `paired` jamais remis à faux dans le sketch | sketch qui répond à `DISCOVER` toujours ; sinon reset | `NOTES-POUR-TOM.md` point 1 |
| conflit git sur un `.tscn` | fusion à la main impossible | garder une version entière, refaire l'autre modif dans Godot | `DEPANNAGE.md` |

## 6. Ce qu'une intervention d'urgence doit respecter
- Travailler sur une **branche** ou dans le dépôt de l'équipe concernée, jamais directement sur `main` de ce dépôt.
- Ne pas changer de version de Godot, de plugin ou de banque pendant la semaine : 14 équipes en dépendent.
- Pas de `git push --force`, pas de `reset --hard`, pas de réécriture d'historique.
- Après une correction du projet de base, dire à Mourdjen quelles équipes doivent la récupérer et comment (patch, copier un fichier) : les équipes ne font pas de `git pull` depuis ce dépôt.
- Documenter la correction dans `docs/QUESTIONS-GODOT-BLOCKS.md` ou dans ce fichier, en une ligne datée.

## 7. Contexte plus large (sur le Mac de Mourdjen, pas dans ce dépôt)
- Tout le dossier de préparation : `~/Downloads/Matériaux Hackathon Lerebours Avril 2026/HACKATHON-NUIT/` (`00-DASHBOARD.md` en premier, puis `07-GODOT-BLOCKS.md` pour ce dépôt).
- Le petit projet 2D de test de connexion : version d'avril non versionnée dans `~/Documents/Godot_Projects/test-communication-arduino-for-students` ; **version à jour sur GitHub : `liaroc/godot-arduino-test-connexion`** (clone `~/Documents/Godot_Projects/godot-arduino-test-connexion`, créé le 18/10), même `arduino_manager.gd` que ce dépôt. C'est aussi la base de la vidéo du cours Godot (tâche T8). Si tu corriges le script série ici, reporte la correction là-bas (et inversement).
- `CLAUDE.md` à la racine du clone (non versionné) : notes détaillées d'avril et du 17/10 ; l'essentiel FMOD est recopié dans `docs/FMOD-PIEGES.md`.
