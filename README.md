# Don't Wake Up The Baby

Jeu VR fait pendant le hackathon Le Rebours (19 au 23 octobre 2026), en équipe de 5.

Il fait nuit, tu es dans la chambre du bébé. Tu le tiens dans ton bras gauche (une vraie poupée, avec un Arduino caché dans le dos) et avec ta main droite tu dois ranger les 10 objets qui traînent dans la pièce avant la fin du temps (5 minutes).

Le problème : si tu bouges trop brusquement, le bébé se réveille et c'est perdu.

Et tu ne sais pas où ranger les objets. Quand tu en ramasses un, une voix te chuchote où il va. C'est la seule indication, il n'y a rien d'écrit. Sur le mur il y a juste une liste de ce qu'il reste à ranger, les objets se barrent au fur et à mesure.

## Ce qu'il faut

- Godot 4.7.2 (la version normale, pas .NET)
- Un Meta Quest 3, relié au PC avec Quest Link ou ALVR (SteamVR)
- La poupée avec l'Arduino, branchée en USB (chez nous c'est COM3)
- Une seule manette, la droite

## Lancer le jeu

1. Brancher la poupée, et vérifier que le moniteur série de l'IDE Arduino est fermé (sinon Godot ne peut pas ouvrir le port).
2. Lancer Link (ou ALVR) et mettre le casque.
3. Ouvrir le projet dans Godot et lancer avec F5.
4. Sur l'écran d'accueil, attendre que le point passe au vert ("Arduino connecté"), puis Jouer.

L'écran d'accueil a aussi deux boutons pour tester sans tout le matériel :
- **Jouer en VR sans Arduino** : avec le casque mais sans la poupée.
- **Jouer sans Arduino (debug clavier)** : sans casque, au clavier et à la souris.

## Les contrôles

En VR (manette droite) :
- gâchette : attraper / lâcher un objet (on peut le lancer)
- joystick : se déplacer
- les tiroirs de la commode s'ouvrent tout seuls quand on approche la main

En debug clavier : ZQSD pour bouger, la souris pour regarder, clic gauche maintenu pour attraper, C pour s'accroupir, F1 pour revenir au menu.

Pour tester rapidement la fin de partie :
- clavier : V = victoire, R = défaite (bébé réveillé), T = défaite (temps écoulé)
- en VR sans Arduino : A = victoire, B = défaite (réveil), clic du joystick = défaite (temps)

## Comment marche le bébé

L'Arduino mesure les mouvements de la poupée avec un gyroscope (BMI160) et envoie à Godot un niveau de 0 à 5, dix fois par seconde (`NIVEAU:3` par exemple).

- Ce niveau s'affiche en bas à droite de la vue : c'est l'indicateur "mouvement", 5 petites cases. Il montre juste à quel point tu es brutal en ce moment.
- Derrière, il y a une jauge cachée : l'agitation du bébé. Elle descend quand tu es doux (niveaux 0 à 2) et elle monte à partir de 3, de plus en plus vite. Si elle arrive au bout, le bébé se réveille et tu perds.
- Tu ne vois pas cette jauge, mais tu la sens : les sons du bébé changent (4 états, du calme jusqu'aux pleurs) et la poupée vibre de plus en plus fort et de plus en plus souvent.

Les réglages (vitesse de la jauge, force des vibrations, durée de la partie) sont en haut de `Scripts/partie.gd`. La sensibilité du capteur se règle en haut du sketch Arduino (`SEUIL_1` à `SEUIL_5`).

### Branchements de la poupée (Arduino Uno R3)

| Composant | Branchement |
|---|---|
| BMI160 (gyroscope + accéléromètre) | SDA → A4, SCL → A5, 3.3V, GND |
| Piezo (détection des chocs) | A0 |
| Buzzer | D8 |
| Moteur vibrant | D9 |

Le sketch est dans `Arduino Code/Bebe/Bebe.ino`. Il répond au `DISCOVER` de Godot (c'est le système des profs, `ArduinoManager`), donc si vous ouvrez le moniteur série tout seul, il ne se passe rien tant que vous n'avez pas tapé `DISCOVER`. C'est normal.

## Le son

Tout le son passe par FMOD Studio 2.03 (pas 2.04, sinon la banque est refusée).

- Le projet FMOD est dans `Sons & musiques/Fichiers FMOD/Projet_FMOD/`.
- Les banques buildées que le jeu charge sont dans `Sons & musiques/Fichiers FMOD/FmodBank/Desktop/` (`Master.bank` et `Master.strings.bank`).
- Dans Godot, les sons sont des nœuds FMOD dans les scènes : `AmbianceBebe`, `VoixObjets`, `SonsObjets`, `SonVictoire` et `SonDefaite` dans la chambre, `SonTiroir` dans la commode, `Son` dans le bac à jouets.

Après un nouveau build de la banque, il suffit de remplacer les deux fichiers `.bank`. Si Godot plante quand on clique sur un émetteur FMOD, voir `docs/FMOD-PIEGES.md` (bug connu du plugin).

## Où est quoi

- `Scènes/Accueil/` : le menu
- `Scènes/Chambre/` : la scène de jeu (`Chambre.tscn` et `chambre.gd`)
- `Scènes/Meubles/` : un fichier par meuble ou déco
- `Scènes/Objets/` : les 10 objets à ranger
- `Scènes/Bebe/` : le bébé qu'on porte
- `Scènes/Joueur/` : la main droite et l'indicateur de mouvement
- `Scripts/` : la logique (partie, objets, zones de rangement, commode, liste au mur…)
- `Arduino Code/Bebe/` : le code de la poupée
- `Ne pas toucher/`, `addons/`, `docs/` : ce qui vient du projet de base des profs

## Git

- Ne jamais commit le dossier `.godot/` (Godot le recrée tout seul).
- Fermer Godot avant un `git pull`, sinon il peut réécrire les scènes ouvertes par-dessus ce qui arrive.
- Toujours `git pull` avant de commencer à bosser, et commit + push dès qu'un truc marche.

## Crédits

Voir `CREDITS.md`. La base du projet (Arduino, FMOD, scripts de connexion) vient des profs du hackathon, leur doc est dans `README_Demo_Prof.md` et `docs/`.
