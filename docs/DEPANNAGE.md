# Dépannage rapide — Godot_Blocks (hackathon Le Rebours, octobre 2026)

Pour les équipes et les encadrants. Cherche ton symptôme, applique le geste. Si ça ne suffit pas, appelle un encadrant avec un **ticket** (pas de ticket, pas de déplacement).

## Ouverture du projet

**Mac : fenêtre « Élément "libxxx.dylib" non ouvert » ou Godot figé à l'ouverture**
→ Quarantaine macOS sur les plugins. Clique **Terminé** (jamais « Placer dans la corbeille »), quitte Godot, puis dans le Terminal : `xattr -cr ` suivi du dossier du projet glissé depuis le Finder, Entrée, rouvre. Détail : `INSTALLATION_PLUGINS_MACOS.md`. Si tu as cliqué « Corbeille » : Corbeille → clic droit sur le fichier → Remettre.

**Dix erreurs rouges `Nonexistent function '…' in base 'FmodServer'` à l'ouverture**
→ Premier import du projet : les scripts du plugin FMOD démarrent avant la GDExtension. Ferme et rouvre le projet, elles disparaissent. Si elles reviennent à chaque ouverture : le fichier `.godot/extension_list.cfg` a été supprimé ; `git checkout .godot/extension_list.cfg` ou rouvrir deux fois.

**« Godot 4.6 » ou « 4.7.0 » demande à convertir le projet, ou refuse de l'ouvrir**
→ Mauvaise version. Il faut **Godot 4.7.2** exactement (version standard, pas .NET).

**Le projet s'ouvre mais aucune scène n'est ouverte, l'éditeur est vide**
→ Normal après un crash : l'éditeur a vidé sa liste de scènes ouvertes. Double-clique sur `Scènes/Demo_Prof/Start.tscn` dans le dock Système de fichiers.

## Son et FMOD

**Aucun son dans le jeu**
→ Vérifie que la banque est chargée : console → ligne `FMOD Sound System: LOADING BANK …/Master.bank`. Si absente, le nœud `FmodBankLoader` a été supprimé ou déplacé de la scène `Demo_Prof.tscn` : il doit rester le **premier enfant de la racine**. Vérifie aussi le volume du Mac et que FMOD Studio n'est pas en « Live Update » connecté sur le même port.

**La musique joue mais pas les bruits de pas (`Footsteps`)**
→ Deux causes possibles, vues le 18/10. (1) Les pas ne sonnent **qu'au sol** : en mode Arduino, tant que la main est devant le capteur, le personnage est en l'air (`CharacterFly` = silence voulu) ; retire la main (ou vole à moins de 2,1 de hauteur) pour les entendre. (2) L'événement `Footsteps` est **spatialisé (3D)** dans la banque : son émetteur doit être un `FmodEventEmitter3D` enfant du joueur (c'est le cas depuis le 18/10 : `FmodEventEmitter3D_footsteps`). S'il est redevenu un `FmodEventEmitter2D`, il est posé à l'origine du monde, loin du `FmodListener3D`, et l'atténuation le rend inaudible. Règle générale : événement 3D (icône spatialiseur dans FMOD Studio) → `FmodEventEmitter3D` ; musique ou son d'interface sans spatialisation → `FmodEventEmitter2D`.

**`Cannot set parameter X to value 0.000000` (valeur zéro alors que tu as passé un label)**
→ Tu as donné le nom de l'**événement** ou un label mal orthographié à la place du nom du **paramètre**. Vérifie dans la fenêtre « Fmod banks explorer ». Exemple correct : `$FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat2")`.

**`Cannot set parameter Hauteur to value 12.5` (la valeur est la bonne)**
→ C'est un paramètre **global** FMOD, pas local à l'événement : `FmodServer.set_global_parameter_by_name("Hauteur", 12.5)` au lieu de `emitter.set_parameter(...)`. Si le nom est `Distance`, `Direction`, `Elevation`, `Speed` : c'est un paramètre automatique de FMOD, ne le règle pas toi-même, supprime l'appel.

**La banque ne se charge pas : « bank version » / « incompatible » / « FMOD_ERR_FORMAT »**
→ La banque a été construite avec **FMOD Studio 2.04**. Le plugin ne lit que du 2.03 (moteur 2.03.06). Ouvrir le projet FMOD dans **FMOD Studio 2.03.x** (jamais 2.04), reconstruire, remplacer `Master.bank` et `Master.strings.bank`.

**Godot plante (disparaît) quand on sauvegarde (Cmd+S) ou quand on clique sur un `FmodEventEmitter` après avoir reconstruit la banque ou cliqué « Refresh banks »**
→ Bug connu du plugin 6.1.0 : les identifiants de paramètres mis en cache dans la scène sont périmés. **Godot fermé**, lance `tools/strip_fmod_param_cache.sh` (Mac/Linux) depuis le dossier du projet : il retire les lignes `fmod_parameters/…` des scènes, le plugin les régénère au prochain clic. Sous Windows : ouvre le `.tscn` dans un éditeur de texte et supprime les lignes `fmod_parameters/...` du nœud concerné. Prévention : **toujours sauvegarder la scène avant un « Refresh banks »**, et relancer l'outil après chaque reconstruction de banque. Détail : `docs/FMOD-PIEGES.md` § 2b.

**Godot plante au lancement en rouvrant `Demo_Prof.tscn`**
→ Même cause. Ferme Godot, édite `.godot/editor/editor_layout.cfg` : `open_scenes=PackedStringArray()` et `current_scene=""`, rouvre, puis applique le geste précédent.

**Un son chargé par code s'arrête net après une seconde**
→ Une banque chargée avec `FmodServer.load_bank(...)` dans une variable locale est déchargée à la fin de la fonction. Garde la référence dans une variable membre, ou utilise le nœud `FmodBankLoader`.

## Arduino

**Pastille rouge « Arduino Pas Connectée », rien ne se passe**
1. Ferme le **moniteur série** de l'IDE Arduino (un seul programme peut tenir le port).
2. **Débranche les téléphones** en USB (ils apparaissent comme des ports série et ralentissent le scan).
3. Le sketch téléversé doit répondre `GDSERIAL_ACK` à `DISCOVER` (c'est le cas de `Arduino Code/AdaptGodot/AdaptGodot.ino`). Un sketch perso qui n'écrit pas cette ligne ne sera jamais appairé.
4. Lance Godot depuis un terminal avec `ARDUINO_DEBUG=1` pour voir les ports essayés, ou force le port : `ARDUINO_PORT=/dev/cu.usbmodem1101` (Mac) / `ARDUINO_PORT=COM7` (Windows). Voir `docs/NOTES-POUR-TOM.md` pour la syntaxe.
5. Windows : si la carte n'apparaît pas dans le gestionnaire de périphériques, installe le pilote **CH340** (clones) ou le pilote Arduino officiel.

**Ça marchait, j'ai débranché/rebranché, plus rien**
→ Sur Uno/Nano : attendre 3 à 5 s, la carte redémarre à l'ouverture du port. Sur **Leonardo, Micro, Uno R4** : le sketch d'origine ne répond plus à `DISCOVER` une fois appairé ; il faut un sketch qui répond `GDSERIAL_ACK` à tout moment (voir `docs/NOTES-POUR-TOM.md`, point 1), ou appuyer sur le bouton reset de la carte.

**Les valeurs du capteur arrivent une fois par seconde au lieu de 20 fois**
→ `pulseIn` sans délai maximal et capteur à ultrasons absent ou sans écho : `pulseIn(ECHO_PIN, HIGH, 30000)`.

**Je veux lire mon propre capteur sans modifier `arduino_manager.gd`**
→ Fais écrire `moncapteur:123` par l'Arduino et connecte-toi au signal `ArduinoManager.message_received` : `func _on_msg(cle, valeur): if cle == "moncapteur": …`.

**`Script inherits from native type 'Node2D', so it can't be assigned to an object of type 'Node'`**
→ Tu as ajouté `arduino_manager.gd` à un nœud de ta scène. Ne le fais pas : il est déjà chargé en autoload `ArduinoManager`, utilise-le directement (`ArduinoManager.button_changed.connect(...)`).

## Git et fichiers

**`git status` montre des centaines de fichiers dans `.godot/`**
→ Le `.gitignore` a été modifié ou tu es dans un sous-dossier qui a son propre projet Godot. Ne commite jamais `.godot/` (sauf `extension_list.cfg`, voulu).

**Le projet d'un coéquipier reçu par Discord/AirDrop ne s'ouvre pas sur Mac**
→ Nouvelle copie = nouvelle quarantaine. Refais `xattr -cr <dossier>` avant d'ouvrir. Avec `git clone`/`git pull`, le problème n'existe pas.

**Conflit git sur `Demo_Prof.tscn`**
→ Les scènes Godot se fusionnent mal à la main. Le plus sûr : garder une des deux versions entière (`git checkout --theirs` ou `--ours` sur le fichier), rouvrir dans Godot, refaire l'autre modification à la main.
