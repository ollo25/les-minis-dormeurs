# Notes pour Tom — branche `hackathon-oct-2026` (17 octobre 2026)

Tu vas reprendre le code série Godot ↔ Arduino avant lundi. Voici ce qui a changé et ce qu'on a relevé, pour que tu ne le redécouvres pas.

## Où travailler
- Dépôt `liaroc/Godot_Blocks`, **branche `hackathon-oct-2026`** (pas `main`, pas `Godot_Blocks`). Clone ou `git fetch` puis `git checkout hackathon-oct-2026`.
- Ouvrir le projet dans **Godot 4.7.2** (pas 4.6, pas 4.7.0). Au tout premier import, une dizaine d'erreurs rouges `Nonexistent function … in base 'FmodServer'` peuvent apparaître : fermer et rouvrir le projet, elles disparaissent (scripts `@tool` du plugin FMOD qui démarrent avant la GDExtension).
- Le script série est `Scènes/Integration_Arduino/arduino_manager.gd`, chargé en **autoload `ArduinoManager`** (project.godot → Autoload). Ne pas ajouter une deuxième instance dans une scène : deux instances ouvriraient les mêmes ports en parallèle.

## Ce qui a changé dans `arduino_manager.gd` (tout l'ancien marche encore)
- Trames `sensor:<0..1023>` et `enc:<position>` désormais traitées (signaux `sensor_changed`, `encoder_changed`). Avant, elles tombaient dans « message inconnu ».
- Signal générique `message_received(clé, valeur)` : émis pour **toute** trame `clé:valeur`. Pratique pour un capteur maison sans toucher au manager.
- Clés acceptées en minuscules ou majuscules (`ENC:3` = `enc:3`).
- Tampon vidé à chaque appairage ; les trames arrivées dans la même lecture que `GDSERIAL_ACK` ne sont plus perdues.
- `ARDUINO_PORT=COM7` (ou `/dev/cu.usbmodem1101`) force un port : seul celui-là est essayé, aucun `DISCOVER` n'est envoyé aux autres appareils USB. `ARDUINO_PORT=tcp://127.0.0.1:5555` branche le simulateur Python (voir plus bas).
- `ARDUINO_DEBUG=1` affiche le détail de l'appairage dans la console.
- L'avertissement « Non pairé, commande ignorée » n'est plus émis à chaque image (il l'était 60 fois par seconde tant que la carte n'était pas trouvée).
- Inchangé : `g_vars.no_arduino`, `potentiometre_updated`, `ultrason_updated`, `button_changed`, `send_led`, `send_blink`, `send_vibe`, `send_ping`, filtre `PORT_NAME_HINTS`, délais 0,5 s / 2 s.

## Tester sans carte
Mac (vérifié le 17/10) :
```
python3 tests/simulateur_arduino.py --tcp 5555 --profil prof
```
puis, dans un autre terminal, depuis le dossier du projet :
```
ARDUINO_PORT=tcp://127.0.0.1:5555 "/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" --headless --path . res://tests/test_arduino_headless.tscn
```
Attendu : `CONNECTÉ`, des lignes `message ultrason:` / `potentiometre:`, `button_changed`, puis `[TEST] BILAN apparie=true`. Profils : `prof` (ultrason + potentiomètre + bouton, comme `AdaptGodot.ino`), `base` (`sensor:` + `button:`), `encodeur` (`enc:` + `button:`).
Windows (non testé) : `py tests\simulateur_arduino.py --tcp 5555 --profil prof`, puis dans un autre terminal `set ARDUINO_PORT=tcp://127.0.0.1:5555` avant de lancer Godot. Seul le mode `--tcp` existe sous Windows.
Limite : le profil `prof` répond à `DISCOVER` à tout moment et traite `blink`, ce que le vrai sketch du dépôt ne fait pas (points 1 et 3 ci-dessous) : le simulateur ne reproduit pas ces deux bugs.

## Ce qu'on a relevé dans `Arduino Code/AdaptGodot/AdaptGodot.ino` du dépôt (non modifié : c'est toi qui le reprends)
Attention : il existe **deux versions** de ce sketch, celle du dépôt et celle du Google Drive d'avril (`Code Arduino/AdaptGodot.ino`). Elles divergent (LED1 sur la broche 4 dans le dépôt, 13 sur le Drive ; le Drive a encore un bug sur `vibe` que le dépôt n'a plus). Il faudra décider laquelle les équipes reçoivent. Ce qui suit concerne la version **du dépôt**, relue ligne par ligne le 17/10.
1. **`paired` ne redevient jamais `false`** (lignes 74 et 88). Après le premier appairage, la branche `if (!paired) { if (cmd == "DISCOVER") … }` de `loop()` est du code mort. Conséquence : une carte **sans reset automatique à l'ouverture du port** (Leonardo, Micro, Uno R4) ne renvoie plus `GDSERIAL_ACK` après un débranchement / rebranchement, donc Godot ne la retrouve pas. Un Uno ou un Nano redémarre à l'ouverture du port, donc ça marche par hasard. Correction : répondre `GDSERIAL_ACK` à **tout** `DISCOVER`, même quand `paired` est vrai.
2. **`pulseIn(ECHO_PIN, HIGH)` sans délai maximal** (ligne 35) → 1 s de blocage par mesure si le capteur à ultrasons est absent ou sans écho : les trames tombent à 1 Hz et les commandes de Godot attendent jusqu'à 1 s. Proposition : `pulseIn(ECHO_PIN, HIGH, 30000)` (30 ms ≈ 5 m).
3. **`blink` n'existe pas dans ce sketch** : `ArduinoManager.send_blink(n)` est accepté côté Godot mais la carte l'ignore. Soit l'ajouter (sans `delay` bloquant), soit ne pas le promettre aux équipes.
4. **Commandes `led1`/`led2`/`led3`** (lignes 113–125) : le `delay(3000)` de `led3` bloque la carte 3 s (ni capteur ni bouton pendant ce temps). La commande `final` fait clignoter les trois LED avec des `delay`, bloquants aussi (~1,7 s).
5. **`vibe`** : correct dans le dépôt (`value == "1"`, ligne 133). La version du Drive teste la chaîne entière (`vibe:0` allume le vibreur) : ne pas repartir de celle-là.
6. Un **téléphone Samsung branché en USB** apparaît sur Mac comme `/dev/cu.usbmodemXXXX` et reçoit `DISCOVER` (sans effet, mais le scan perd ~1,6 s). Débrancher les téléphones pendant les tests, ou forcer `ARDUINO_PORT`.
7. Pour une manette à **encodeur rotatif** : un brouillon de sketch est dans `Arduino Code/GODOTSERIAL_encodeur/GODOTSERIAL_encodeur.ino` (compile pour Uno, **jamais téléversé**, broches à adapter) ; explications dans `docs/MANETTE-ENCODEUR.md`. Sans anti-rebond, compter « +2 par cran » est normal sur un encodeur demi-pas.
8. GdSerial `read_string()` renvoie une chaîne vide si le morceau lu n'est pas de l'UTF-8 valide (parasites au démarrage) : le morceau est perdu. Rare en ASCII ; sans effet sur l'appairage (3 tentatives).

## Les pas qu'on n'entendait pas (ton retour du 18/10)
L'événement `Footsteps` est spatialisé (3D) dans la banque d'Alexia, mais son émetteur dans `Demo_Prof.tscn` était un `FmodEventEmitter2D` : posé à l'origine du monde, loin du `FmodListener3D` qui suit le joueur, donc atténué jusqu'au silence. Il est maintenant un **`FmodEventEmitter3D` enfant de `JoueurDemo`, renommé `FmodEventEmitter3D_footsteps`** ; les quatre références dans `JoueurDemo.gd` ont été renommées (lignes `_ready` et `_physics_process`), rien d'autre n'a changé dans ton script. Un test headless confirme que l'événement démarre et que le label bascule `CharacterFly` ↔ `CharacterWalk` ; **à toi d'écouter**. Rappel : les pas ne sonnent qu'au sol (hauteur < 2,1) ; en mode Arduino, main devant le capteur = en l'air = silence voulu. Si ça ne suffit pas, regarde dans FMOD Studio 2.03 le label `CharacterWalk` et les distances min/max du spatialiseur.

## Ne pas supprimer `serial_tcp_simu.gd`
`Scènes/Integration_Arduino/serial_tcp_simu.gd` (classe `SerialTcpSimu`) est **référencé par `arduino_manager.gd`** (ligne `serial = SerialTcpSimu.new()`). Si on le supprime ou le renomme, le script série ne se charge plus et l'écran Start ne marche plus. Il ne sert qu'avec `ARDUINO_PORT=tcp://…`, mais il doit rester dans le projet. Le dossier `tests/` (simulateur Python, scène de test), lui, peut être retiré sans conséquence.

## Protocole (rappel)
115200 bauds, lignes terminées par `\n`, format `clé:valeur`. Godot envoie `DISCOVER`, la carte répond `GDSERIAL_ACK:<nom>`. Commandes Godot → carte : `led:0|1` (le sketch du dépôt attend `led1`/`led2`/`led3`), `blink:<n>` (ignoré par le sketch du dépôt), `vibe:0|1`, `ping:<ms>` (réponse `pong:<ms>`). Trames carte → Godot : `ultrason:<cm>`, `potentiometre:<0..1023>`, `button:0|1`, `sensor:<0..1023>`, `enc:<position>`, `ack:<texte>`. Détail complet : `docs/PROTOCOLE-ARDUINO-GODOT.md` (écrit pour le sketch GODOTSERIAL du petit projet 2D ; les sections 1 à 5 et 7 valent pour les deux).

## Variables d'environnement : comment les passer
Elles n'atteignent Godot que s'il est lancé depuis le terminal où elles sont définies (pas depuis le Dock ou le menu Démarrer).
- Mac : `ARDUINO_DEBUG=1 "/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" --path . --editor`
- Windows (cmd) : `set ARDUINO_PORT=COM7` puis `"C:\chemin\Godot_v4.7.2-stable_win64.exe" --path . --editor` ; PowerShell : `$env:ARDUINO_PORT="COM7"`.

## Si tu renommes un signal
Préviens Mourdjen : la vidéo du cours Godot (chapitre 8, pont Arduino → FMOD) utilise `sensor_changed` et `button_changed`.

## 18/10 soir — branche `gameplay-fixes` (corrections de gameplay demandées le 18/10), et ce que ça change pour le sketch
Branche **`gameplay-fixes`** créée depuis `hackathon-oct-2026`, **pas fusionnée** (Mourdjen teste et décide). **Rien n'a été touché dans `arduino_manager.gd` ni dans les `.ino`** : tout est côté jeu (`JoueurDemo.gd`, `Object_To_Catch_1.gd`, `Ground_Collectible.gd`, nouvel écran `fin_de_partie.tscn`). Détail : `docs/CHECKLIST-TEST-4.7.2.md` § F et les messages des 4 commits.

**La vibration permanente : cause côté jeu, corrigée.** En mode Arduino, `JoueurDemo._physics_process` appelait `ArduinoManager.send_vibe(1)` ou `send_vibe(0)` **à chaque image physique** (60 commandes `vibe:…` par seconde, plus un `print`), avec un seuil fixe de 10 unités autour des palets au sol. Le sketch lit **une** ligne par `loop()` et bloque dans `pulseIn` (délai par défaut 1 s sans écho) et dans `delay(3000)` (`led3`) : il traitait donc des commandes vieilles de plusieurs secondes (un `vibe:1` arrive alors que le joueur est déjà loin), et le tampon de réception de 64 octets débordait (lignes mélangées → ignorées, donc plutôt vibreur éteint). **Mécanisme plausible, pas prouvé sur la carte** : si après cette branche la manette vibre encore hors des palets, le dis-nous, la cause est ailleurs (câblage, ou sketch). Maintenant : seuil réglable dans l'inspecteur (`distance_vibration`, 5,0 ; hystérésis `marge_vibration`, 0,5), **commande envoyée seulement au changement d'état** plus un rappel du même état toutes les `rappel_vibration` secondes (1 s ; 0 = jamais) pour rattraper une commande perdue pendant un `delay()`, état renvoyé à chaque (ré)appairage, arrêt explicite à la fin de partie / quand on coupe le mode Arduino / en quittant la scène. Vérifié avec le simulateur : 3 commandes `vibe` sur toute une partie de test (`docs/logs/simulateur-vibe.log`).

**Ce qui reste de ton côté (sketch), si tu veux rendre la carte robuste même avec un jeu bavard :**
1. `pulseIn(ECHO_PIN, HIGH, 30000)` (30 ms ≈ 5 m) au lieu de `pulseIn(ECHO_PIN, HIGH)` : sans écho, chaque mesure bloque 1 s et le tampon série déborde.
2. Les `delay(3000)` de `led3` et les `delay` de `final` bloquent la carte : pendant ce temps toute commande `vibe:0` est perdue et le vibreur peut rester allumé.
3. À la réception de `DISCOVER` (appairage), mettre `VIB_PIN` à `LOW` : le jeu renvoie l'état une fois appairé, mais une carte qui redémarre vibreur allumé le resterait jusque-là.
4. **Nouveau avec le bouton Rejouer** : `nbLed` (ligne 18) est incrémenté à chaque `led:` et n'a de cas que 1 à 3 ; il ne revient à zéro qu'au redémarrage de la carte. Avant, « rejouer » = relancer le jeu = carte redémarrée ; maintenant Rejouer garde le port ouvert, donc **dès la 2ᵉ partie les LED ne s'allument plus**. Remettre `nbLed = 0` à la réception de `DISCOVER` ou d'une commande dédiée (le jeu n'en envoie pas encore ; si tu en ajoutes une, dis-nous son nom, une ligne dans `fin_de_partie.gd` suffira).
5. Toujours valable : `paired` jamais remis à faux (point 1 du 17/10) et `blink` absent (point 3).
Si après ça la manette vibre encore sans palet à moins de 5 m : regarder le câblage (`VIB_PIN` flottant, transistor), pas le jeu.

**Écran Start** : il existe (`Scènes/Demo_Prof/Start.tscn` + `start_screen.gd`, scène principale du projet) : « Start Game » grisé au départ, activé par `arduino_connected`, regrisé par `arduino_disconnected` ; « Start Game with no Arduino » met `g_vars.no_arduino = true`. Les deux chargent `Demo_Prof.tscn`. Pas modifié.

## 18/10 soir (suite) — « les palets continuent de jouer leur musique même quand on les a attrapés »
Tu l'entends parce que tu testes **`hackathon-oct-2026`** : sur cette branche, un palet ramassé est seulement caché (`hide()`), et FMOD ne s'en aperçoit pas, donc sa boucle `VibrObj` continue jusqu'à la fin de la scène. Le correctif était déjà dans `gameplay-fixes` (non fusionnée) ; il est maintenant durci et posé **par-dessus ton commit `e5ac1ed`** dans la branche **`fix-son-palets`** (= ton `hackathon-oct-2026` + `gameplay-fixes` + ce correctif). Pour l'entendre : `git fetch && git checkout fix-son-palets`. Rien n'est touché dans `arduino_manager.gd` ni dans `AdaptGodot.ino`.
- Ce que fait le correctif (`Scènes/Demo_Prof/Ground_Collectible.gd`, méthode `arreter_boucle()`) : arrêt **immédiat** (`allow_fadeout = false`, sinon `stop()` laisse l'événement finir son relâchement), émetteur retiré de l'arbre (c'est ce qui libère l'instance FMOD : `stop()` seul la garde allouée), détection coupée, puis le palet est **supprimé** 0,5 s après (avant : caché). Le joueur appelle la même méthode sur les palets restants à la fin de partie.
- Ton sketch `e5ac1ed` vu de Godot : `potentiometre:0..1023` depuis l'encodeur avec retour à 0 après un tour → `target_rotation = deg_to_rad(value / 3)` donne 0 → 341°, un tour de bouton ≈ un tour de personnage. **Une ligne changée côté jeu** (`JoueurDemo.gd`, lissage de la rotation, trouvée par la relecture) : au passage 1023 → 0 le lissage ne repliait l'écart que dans un sens, le personnage refaisait presque un tour à l'envers en ~1 s ; le repli symétrique est ajouté (`elif rotation_difference < -PI: += TAU`). Simulé, pas testé avec ta manette : si la rotation saute encore au passage du tour, dis-le. `nbLed = 0` dans le `default` : après une partie complète (3 bougies = 3 `led:1`), la première bougie de la partie suivante éteint tout, la 2ᵉ allume LED1, la 3ᵉ LED2 ; le point 4 ci-dessus (remise à zéro à `DISCOVER`) reste donc valable si tu veux 3 LED à chaque partie. La commande `final` ne fait plus qu'éteindre les LED (le jeu ne l'envoie pas de toute façon). Le brouillon `GODOTSERIAL_encodeur.ino` (point 7) n'existe plus depuis ton commit : l'encodeur est dans `AdaptGodot.ino`.
