# Checklist de test — Godot_Blocks en Godot 4.7.2 (branche `hackathon-oct-2026`)

Ce qui a été vérifié en headless le 17/10/2026 est coché. Le reste demande l'éditeur fenêtré, du son, ou la vraie carte : c'est pour Mourdjen et Tom.

## A. Déjà vérifié en headless (logs dans `docs/logs/`)
- [x] Import 4.7.2 ×2 sur le projet existant : aucune erreur (`import-4.7.2-run1.log`, `run2`).
- [x] Premier import sur une copie **sans** `.godot/` : 10 erreurs rouges `FmodServer` au 1er import, aucune au 2e (`premier-import-sans-dotgodot-run1.log`). Voir le résultat du test « avec `extension_list.cfg` » dans `QUESTIONS-GODOT-BLOCKS.md`.
- [x] Scène principale `Start.tscn` 200 images avec un port forcé inexistant : seule erreur, l'ouverture du port inexistant, attendue (`start-200.log`, `start-200-v2.log`). Puis 300 images **sans port forcé** (`start-300-scan-normal.log`) : `GdSerial.list_ports()` fonctionne en 4.7.2, le filtre écarte les ports Bluetooth / debug du Mac, « Aucun port Arduino-like détecté » puis nouvelle tentative toutes les 2 s, aucune erreur. Aucune carte n'était branchée : l'appairage réel reste à faire (section C).
- [x] `Demo_Prof.tscn` 300 images avec le simulateur : appairage OK, FMOD initialisé (`demo-prof-300.log`).
- [x] `Integration_Arduino.tscn` 200 images avec le simulateur : appairage, ping, latence 15 ms (`integration-200.log`).
- [x] `tests/test_arduino_headless.tscn` avec `simulateur_arduino.py --profil prof` : `pairing_success` en 0,63 s, trames `ultrason` / `potentiometre`, `button_changed` (`test-arduino-simu.log`).

## B. Dans l'éditeur 4.7.2 (15 min, Mac, sans carte)
1. [ ] Ouvrir le projet dans **Godot 4.7.2**. Si des erreurs rouges `Nonexistent function … in base 'FmodServer'` apparaissent : fermer, rouvrir, elles doivent disparaître.
2. [ ] Paramètres du projet → Extensions : FMOD et GdSerial cochés, aucune erreur. Fenêtre « Fmod banks explorer » : la banque `Master` liste `event:/Footsteps`, `event:/MusiqueNiv1`, `event:/ObjectCatch`, `event:/VibrObj` (et `ObjectLoop`).
3. [ ] **Avant tout « Refresh banks » : sauvegarder la scène** (crash connu du plugin 6.1.0, voir `docs/FMOD-PIEGES.md` § 2b).
4. [ ] F5 : écran Start, pastille rouge « Arduino Pas Connectée », bouton « Start Game with no Arduino » actif.
5. [ ] Cliquer « Start Game with no Arduino » : la scène Demo_Prof se charge, **on entend la musique** (`MusiqueNiv1`, état `Etat1`) ; au sol, les pas (`Footsteps`, paramètre `CharacterWalk`) ; en l'air, silence. *18/10 : Tom n'entendait pas les pas ; l'émetteur était en 2D pour un événement 3D, retypé en `FmodEventEmitter3D` (voir `QUESTIONS` 15). À réécouter : au clavier, descendre au sol (touche « Courir » = Shift) ; en Arduino, retirer la main du capteur.*
6. [ ] Ramasser un objet : son `ObjectCatch`, la musique passe à `Etat2` puis `Etat3`, `Etat4`. Aucune ligne rouge `Cannot set parameter` dans la console (si oui : voir `docs/FMOD-PIEGES.md`, « Local vs global parameters » et § 4).
7. [ ] Console : aucune ligne rouge au chargement de Demo_Prof (le `Node not found: AudioStreamPlayer3` d'avril est corrigé : le nœud, qui était à la racine de la scène, a été déplacé sous `JoueurDemo`).
8. [ ] **Cmd+S** sur Demo_Prof.tscn : pas de crash. Fermer et rouvrir le projet : pas de crash au lancement (l'éditeur rouvre les dernières scènes).
9. [ ] Clic sur `FmodEventEmitter2D_music` dans l'arbre : l'inspecteur s'affiche sans crash, `MusiqueEtat` listé avec ses labels.

## C. Avec la vraie carte (15 min, Mac puis Windows)
1. [ ] **Débrancher le téléphone Samsung** (il apparaît en `usbmodem` et reçoit `DISCOVER`), fermer le moniteur série de l'IDE Arduino.
2. [ ] Téléverser `Arduino Code/AdaptGodot/AdaptGodot.ino` (ou la version corrigée de Tom).
3. [ ] F5 : pastille verte « Arduino Connecté » en 2–3 s (console : `[Pairing]   → CONNECTÉ sur /dev/cu.usbmodem…`). Bouton « Start Game » actif.
4. [ ] Dans Demo_Prof : la main devant l'ultrason change l'altitude, le potentiomètre tourne le joueur, le vibreur réagit près d'un objet au sol.
5. [ ] Débrancher la carte : « Déconnecté » en moins de 2 s ; rebrancher : ré-appairage en 3–5 s (cartes Uno/Nano ; Leonardo et Uno R4 : voir `NOTES-POUR-TOM.md` point 5).
6. [ ] Même chose sur un **PC Windows** du Rebours avec Godot 4.7.2 win64 (ports `COM`) : rien n'a été testé sous Windows.
7. [ ] Option : `ARDUINO_DEBUG=1` dans l'environnement avant de lancer Godot pour voir le détail de l'appairage.

## D. Installation « comme un étudiant » (10 min)
1. [ ] Télécharger le zip du dépôt **par le navigateur** sur un Mac qui n'a jamais ouvert ces plugins, double-cliquer pour décompresser, ouvrir dans Godot 4.7.2 : fenêtre Gatekeeper → **Terminé** (jamais Corbeille) → `xattr -cr <dossier du projet>` → rouvrir. Suivre `INSTALLATION_PLUGINS_MACOS.md`.
2. [ ] Vérifier que la fiche est compréhensible par quelqu'un qui n'a jamais ouvert un Terminal.

## E. Avant de distribuer aux 14 équipes
- [ ] Décider ce qu'on fait du zip de 72 Mo `Graphismes/…/Medieval Builder Pack 1.0/tiles/square/addons.zip` suivi par git (non référencé par les scènes, voir `QUESTIONS-GODOT-BLOCKS.md`).
- [ ] Fusionner `hackathon-oct-2026` dans `main` (décision de Mourdjen), puis créer les 14 dépôts d'équipe à partir de `main`.

## F. Branche `gameplay-fixes` (18/10/2026, corrections B.1–B.4 de `10-CHANTIERS-SUIVANTS-18-10.md`) — à tester par Mourdjen avant fusion
Tout a été vérifié en headless (`tests/test_collecte_headless.tscn`, `tests/test_vibration_simu_headless.tscn`, logs dans `docs/logs/`) : jamais à l'oreille, jamais avec la vraie carte. `git fetch && git checkout gameplay-fixes` ; ne pas fusionner avant d'avoir coché.
1. [ ] **Palets (disques verts au sol)** : en passer un au sol → il grossit brièvement puis **disparaît**, sa boucle sonore `VibrObj` **s'arrête**, et on entend le son de capture `ObjectCatch` (nouveau pour les palets : avant, aucun son). Repasser au même endroit : rien ne se redéclenche.
2. [ ] **Bougies** : la bougie 1 (devant le départ, derrière soi : faire demi-tour) disparaît quand on la traverse, la 2 apparaît (en l'air, à 65, 14, 45), puis la 5 au sol (101, 2, 10). On doit **pouvoir traverser l'emplacement des bougies 3 et 4 (jamais activées) et de la 5 avant son activation sans que rien n'arrive** (avant : capture invisible, fin de partie surprise près du palet 6).
3. [ ] **Son de capture** à chaque bougie et à chaque palet, y compris la **dernière bougie** (avant : muette, le joueur était caché juste après `play()`). L'émetteur est maintenant sur le joueur (il était 5 m sous lui).
4. [ ] **Écran de fin** : dernière bougie → caméra finale, fondu au noir (4 s, `duree_fondu` sur le nœud `FinDePartie`), puis « Partie terminée », **« Temps : 1 min 23,4 s »** (chronomètre depuis l'entrée dans Demo_Prof), boutons **Rejouer** (recharge Demo_Prof, même mode avec/sans Arduino) et **Quitter** (ferme le jeu). La souris est visible ; Entrée sur Rejouer marche aussi. Après Rejouer : une seule musique (pas de doublon), palets et bougies remis à zéro.
5. [ ] **Vibration (vraie carte)** : la manette ne vibre **que** à moins de `distance_vibration` (5,0 par défaut) d'un palet **visible**, et s'arrête au-delà de 5,5 (marge). Régler : sélectionner `JoueurDemo` dans Demo_Prof.tscn → inspecteur, groupe en tête du script : « Distance Vibration », « Marge Vibration ». La commande `vibe` ne part qu'au changement, plus un rappel du même état chaque seconde (console Arduino : plus de rafale). Après Rejouer, les LED de la carte ne s'allument plus (compteur `nbLed` du sketch, pour Tom : `NOTES-POUR-TOM.md`) ; pas de pas ni de boucle de palet audibles sous l'écran de fin. Vibration coupée à la fin de partie, en coupant le mode Arduino (Entrée) et en quittant la scène. Au branchement de la carte, l'état est renvoyé une fois.
6. [ ] **Écran Start** (inchangé, vérifié dans le code seulement) : « Start Game » grisé tant que la carte n'est pas appairée, actif à l'appairage, regrisé au débranchement ; « Start Game with no Arduino » toujours actif.
7. [ ] Console : aucune ligne rouge pendant tout ça (les `WARNING: [Arduino] Non pairé` en mode sans Arduino sont normaux).
8. [ ] **Réécouter les palets (18/10 soir, branche `fix-son-palets` = `hackathon-oct-2026` de Tom + `gameplay-fixes` + ce correctif)** : passer les 6 palets au sol un par un ; à chaque capture la boucle `VibrObj` du palet se tait **net** (arrêt immédiat, émetteur supprimé), rien ne repart en repassant au même endroit (le palet n'existe plus), aucune boucle de palet sous l'écran de fin, et après Rejouer les 6 boucles repartent une seule fois. Si une boucle s'entend encore : vérifier la branche (`git branch --show-current`) ; Tom l'entendait parce que `hackathon-oct-2026` n'a aucun arrêt de la boucle.
