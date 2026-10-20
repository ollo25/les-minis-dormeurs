# tests/test_collecte_headless.gd — vérifie SANS éditeur les corrections de gameplay du 18/10/2026 dans Demo_Prof :
#   B.1  un palet au sol (GroundCollectible) traversé est collecté, sa boucle FMOD « VibrObj » coupée NET (pas en
#        fondu : aucune instance en STOPPING), son émetteur retiré de l'arbre et son instance libérée, sa détection
#        coupée, puis le nœud supprimé ; à la fin de partie plus aucun émetteur de palet n'existe (18/10 soir) ;
#        une bougie (Object_To_Catch) traversée disparaît (queue_free) et active la suivante ;
#        une bougie NON activée (invisible) n'est plus attrapable ;
#   B.2  l'événement FMOD « ObjectCatch » démarre à chaque capture (signal started), palet compris, y compris la dernière ;
#   B.3  la dernière bougie affiche l'écran de fin (FinDePartie) avec le temps final, souris visible ;
#   B.4  en mode Arduino la commande de vibration n'est envoyée qu'au changement d'état (près / loin d'un palet) ;
#   Rejouer : libérer la scène et la ré-instancier ne laisse pas d'instance FMOD derrière (musique pas doublée).
# Lancer, son coupé (FMOD joue sur les enceintes même en headless), depuis le dossier du projet :
#   ARDUINO_PORT=/dev/cu.inexistant "<Godot>" --headless --path . res://tests/test_collecte_headless.tscn
# Attendu : lignes "[COLLECTE] … : ok" et "[COLLECTE] BILAN ok=true", code de sortie 0.
extends Node

var _t := 0
var _jeu: Node
var _joueur: CharacterBody3D
var _reward
var _reward_joue := 0
var _ok := true
var _palet: Area3D
var _bougie1: Area3D
var _bougie2: Area3D
var _bougie3: Area3D
var _vibe_dernier := -2
var _vibe_changements := 0

func _ready() -> void:
	g_vars.no_arduino = true  # pas de scan des ports : mode clavier/souris
	_instancier()

func _instancier() -> void:
	_jeu = load("res://Scènes/Demo_Prof/Demo_Prof.tscn").instantiate()
	add_child(_jeu)
	_joueur = _jeu.get_node("JoueurDemo")
	_reward = _joueur.get_node("FmodEventEmitter3D_reward")
	# 1er play() → signal started ; les suivants (instance conservée, auto_release = false) → signal restarted.
	_reward.started.connect(func(): _reward_joue += 1; print("[COLLECTE] ObjectCatch : signal started reçu (", _reward_joue, ")"))
	_reward.restarted.connect(func(): _reward_joue += 1; print("[COLLECTE] ObjectCatch : signal restarted reçu (", _reward_joue, ")"))
	_palet = _jeu.get_node("GroundCollectibles/GroundCollectible1")
	_bougie1 = _jeu.get_node("Object_To_Catch_1")
	_bougie2 = _jeu.get_node("Object_To_Catch_2")
	_bougie3 = _jeu.get_node("Object_To_Catch_3")

func _verifie(nom: String, cond: bool) -> void:
	print("[COLLECTE] ", nom, " : ", "ok" if cond else "ÉCHEC")
	_ok = _ok and cond

# GUID des événements de la banque (la recherche par chemin « event:/… » échoue dans FmodServer.get_event, le GUID marche).
const GUID := {
	"ObjectCatch": "{f3a9f80e-9842-4b9c-935b-6ef38cde2e51}",
	"VibrObj": "{2b21cc40-f8a8-4c14-bf78-80ba263c54df}",
	"MusiqueNiv1": "{57ca7ceb-50fb-4a88-97d8-9fcf860de541}",
	"Footsteps": "{40522ecf-7ac2-4694-8add-d337378c89f4}",
}

# Nombre d'instances de l'événement (-1 si la banque n'est plus chargée : c'est le cas après libération de la scène,
# le FmodBankLoader décharge la banque en quittant l'arbre, ce qui libère toutes les instances).
func _instances(evenement: String) -> int:
	if not FmodServer.check_event_guid(GUID[evenement]):
		return -1
	return FmodServer.get_event_from_guid(GUID[evenement]).get_instance_count()

# Instances réellement en lecture (stop() sur un émetteur ne libère pas l'instance, il l'arrête).
# FMOD_STUDIO_PLAYBACK_STATE : 0 PLAYING, 1 SUSTAINING, 2 STOPPED, 3 STARTING, 4 STOPPING.
func _en_lecture(evenement: String) -> int:
	if not FmodServer.check_event_guid(GUID[evenement]):
		return 0
	var desc = FmodServer.get_event_from_guid(GUID[evenement])
	var n := 0
	for inst in desc.get_instance_list():
		if inst.get_playback_state() in [0, 1, 3]:
			n += 1
	return n

# Instances en cours d'arrêt (état 4 STOPPING) : avec allow_fadeout (vrai par défaut) un stop() laisse la boucle
# s'éteindre pendant tout le relâchement de l'événement ; l'arrêt immédiat n'en laisse aucune.
func _en_arret(evenement: String) -> int:
	if not FmodServer.check_event_guid(GUID[evenement]):
		return 0
	var n := 0
	for inst in FmodServer.get_event_from_guid(GUID[evenement]).get_instance_list():
		if inst.get_playback_state() == 4:
			n += 1
	return n

func _physics_process(_delta: float) -> void:
	_t += 1
	# Compte les changements d'état envoyés à la carte (B.4), à chaque image. Le rappel périodique (rappel_vibration)
	# renvoie le MÊME état : il ne compte pas comme changement ; le test avec simulateur compte les commandes réelles.
	if is_instance_valid(_joueur) and _joueur._vibration_envoyee != _vibe_dernier:
		_vibe_dernier = _joueur._vibration_envoyee
		_vibe_changements += 1
	if _t == 5:
		var desc = FmodServer.get_event_from_guid(GUID["ObjectCatch"])
		if desc:
			print("[COLLECTE] ObjectCatch 3D=", desc.is_3d(), " min/max distance=", desc.get_min_max_distance(), " ; émetteur reward à ", _reward.position, " du joueur")
		_verifie("émetteur ObjectCatch sur le joueur (plus à 5 m sous lui)", _reward.position.length() < 0.01)
		_verifie("bougie 1 visible et détectable, bougie 3 invisible et non détectable", _bougie1.monitoring and not _bougie3.visible and not _bougie3.monitoring)
		# 7 instances VibrObj : 6 palets + l'émetteur FmodEventEmitter3D_ground_collect du joueur (préchargé, jamais joué).
		print("[COLLECTE] instances VibrObj = ", _instances("VibrObj"), " dont en lecture = ", _en_lecture("VibrObj"))
		_verifie("6 boucles VibrObj en lecture au départ", _en_lecture("VibrObj") == 6)
		# Le joueur avance tout seul (SPEED 10) : on le pose juste avant le palet 1 (10, 2, 2), à hauteur de sol.
		_joueur.rotation.y = -PI / 2  # avance vers +x
		_joueur.global_position = Vector3(8.5, 3.0, 2.0)
	if _t == 20:
		# Le joueur (10 m/s depuis x = 8,5) entre dans le palet 1 (x = 9) vers t = 8 ; l'effet visuel dure 0,5 s (30 images).
		_verifie("palet 1 collecté (is_collected), encore présent pendant l'effet", is_instance_valid(_palet) and _palet.is_collected)
		_verifie("palet 1 : détection coupée (monitoring et monitorable à faux)", not _palet.monitoring and not _palet.monitorable)
		_verifie("palet 1 : émetteur VibrObj retiré du palet", _palet.get_node_or_null("FmodEventEmitter3D") == null and _palet.emetteur_boucle == null)
		print("[COLLECTE] après capture : instances VibrObj = ", _instances("VibrObj"), " en lecture = ", _en_lecture("VibrObj"), " en arrêt (fondu) = ", _en_arret("VibrObj"))
		_verifie("palet 1 : boucle VibrObj coupée (5 en lecture)", _en_lecture("VibrObj") == 5)
		_verifie("palet 1 : arrêt immédiat, aucune instance en fondu (STOPPING)", _en_arret("VibrObj") == 0)
		_verifie("palet 1 : instance FMOD libérée (6 instances : 5 palets + émetteur préchargé du joueur)", _instances("VibrObj") == 6)
		_verifie("palet 1 : ObjectCatch joué", _reward_joue == 1)
	if _t == 60:
		_verifie("palet 1 supprimé de la scène (queue_free après l'effet)", not is_instance_valid(_palet))
		_verifie("palet 1 : toujours 5 boucles VibrObj en lecture, rien de relancé", _en_lecture("VibrObj") == 5 and _en_arret("VibrObj") == 0)
		# Bougie 3 (jamais activée, invisible) à (83.9, 5.08, -11.6) : on la traverse, rien ne doit se passer.
		_joueur.global_position = Vector3(82.4, 5.08, -11.62)
	if _t == 90:
		_verifie("bougie 3 invisible traversée : toujours là", is_instance_valid(_bougie3))
		_verifie("bougie 3 invisible traversée : pas de son, compteur à 0", _reward_joue == 1 and _joueur.compteur_object_collecte == 0)
		# Bougie 1 à (0, 3, 11) : on arrive par -x.
		_joueur.global_position = Vector3(-1.5, 3.0, 11.0)
	if _t == 130:
		_verifie("bougie 1 disparue (freed)", not is_instance_valid(_bougie1))
		_verifie("bougie 2 activée, visible et détectable", is_instance_valid(_bougie2) and _bougie2.visible and _bougie2.activated and _bougie2.monitoring)
		_verifie("compteur du joueur = 1", _joueur.compteur_object_collecte == 1)
		_verifie("ObjectCatch joué pour la bougie 1", _reward_joue == 2)
		# B.4 : mode Arduino simulé, palet 2 en (25, 2, -8). Loin d'abord (joueur en 25, 3, 20 : 28 m).
		_joueur.Is_Arduino_Mode_On = true
		_joueur.target_rotation = PI  # avance vers +z, s'éloigne du palet
		_joueur.rotation.y = PI
		_joueur.global_position = Vector3(25.0, 3.0, 20.0)
		_vibe_changements = 0
	if _t == 160:
		_verifie("vibration : loin d'un palet → état 0 envoyé une fois", _joueur._vibration_envoyee == 0 and _vibe_changements == 1)
		_joueur.target_rotation = 0.0  # avance vers -z, vers le palet 2
		_joueur.rotation.y = 0.0
		_joueur.global_position = Vector3(25.0, 3.0, -8.0 + _joueur.distance_vibration - 0.5)  # à 0,5 m sous le seuil
	if _t == 175:
		_verifie("vibration : sous le seuil → état 1 envoyé une seule fois", _joueur._vibration_envoyee == 1 and _vibe_changements == 2)
	if _t == 240:
		# 65 images à 10 m/s : le joueur a traversé le palet 2 (collecté → plus visible) et s'en éloigne.
		_verifie("vibration : palet passé → état 0, 3 changements en tout (pas d'envoi par image)", _joueur._vibration_envoyee == 0 and _vibe_changements == 3)
		_joueur.Is_Arduino_Mode_On = false
		# Bougie 2 (activée par la 1) à (65, 14, 45), en l'air : on arrive par -x. Elle active la bougie finale (5).
		_joueur.rotation.y = -PI / 2
		_joueur.global_position = Vector3(63.5, 14.0, 45.0)
	if _t == 270:
		var bougie5: Area3D = _jeu.get_node("Object_To_Catch_5")
		_verifie("bougie 2 disparue, bougie 5 (finale) activée et détectable", not is_instance_valid(_bougie2) and bougie5.visible and bougie5.monitoring)
		_verifie("ObjectCatch joué pour la bougie 2 (4 captures)", _reward_joue == 4)  # palet 1, bougie 1, palet 2, bougie 2
		# Dernière bougie (Object_To_Catch_5, final_object) à (101, 2.15, 10.3) : on arrive par -x.
		_joueur.rotation.y = -PI / 2
		_joueur.global_position = Vector3(99.5, 3.0, 10.33)
	if _t == 330:
		var fin := _jeu.get_node_or_null("FinDePartie")
		_verifie("écran de fin présent et affiché", fin != null and fin.visible)
		if fin:
			_verifie("temps final > 0", fin.temps_final > 0.0)
			print("[COLLECTE] temps affiché : « ", fin.get_node("%TempsLabel").text, " » (formatage 83,4 s → ", fin.formater_temps(83.4), ")")
			_verifie("formatage du temps", fin.formater_temps(83.4) == "1 min 23,4 s" and fin.formater_temps(5.0) == "5,0 s" and fin.formater_temps(119.97) == "2 min 00,0 s" and fin.formater_temps(59.97) == "1 min 00,0 s")
			_verifie("pas coupés (CharacterFly) et boucles VibrObj des palets restants arrêtées", str(_joueur.get_node("FmodEventEmitter3D_footsteps").get_parameter("CharacterWalk")) == "CharacterFly" and _en_lecture("VibrObj") == 0)
			print("[COLLECTE] fin de partie : instances VibrObj = ", _instances("VibrObj"), " en arrêt (fondu) = ", _en_arret("VibrObj"))
			_verifie("fin de partie : aucune boucle VibrObj en fondu, seule reste l'instance préchargée (jamais jouée) du joueur", _en_arret("VibrObj") == 0 and _instances("VibrObj") == 1)
			var emetteurs_restants := 0
			for palet in _jeu.get_node("GroundCollectibles").get_children():
				if palet.get_node_or_null("FmodEventEmitter3D") != null:
					emetteurs_restants += 1
			_verifie("fin de partie : plus aucun émetteur VibrObj sous les palets restants", emetteurs_restants == 0)
		_verifie("souris visible pour cliquer (contrôle faible : en headless le mode souris ne change jamais)", Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE)
		_verifie("joueur arrêté (partie_terminee) et vibration coupée", _joueur.partie_terminee and _joueur._vibration_envoyee == 0)
		_verifie("ObjectCatch joué pour la dernière bougie (5 captures)", _reward_joue == 5)
		print("[COLLECTE] instances MusiqueNiv1 avant libération = ", _instances("MusiqueNiv1"))
		# Rejouer = recharger la scène : on libère et on ré-instancie, les instances FMOD ne doivent pas s'accumuler.
		_jeu.queue_free()
	if _t == 360:
		print("[COLLECTE] après libération : MusiqueNiv1=", _instances("MusiqueNiv1"), " VibrObj=", _instances("VibrObj"), " Footsteps=", _instances("Footsteps"))
		_verifie("scène libérée : plus rien en lecture (banque déchargée ou instances libérées)", _en_lecture("MusiqueNiv1") == 0 and _en_lecture("VibrObj") == 0 and _en_lecture("Footsteps") == 0)
		_reward_joue = 0
		_instancier()
	if _t == 390:
		print("[COLLECTE] après ré-instanciation : MusiqueNiv1=", _instances("MusiqueNiv1"), " VibrObj=", _instances("VibrObj"), " en lecture=", _en_lecture("VibrObj"))
		_verifie("scène ré-instanciée (Rejouer) : une seule musique, 6 boucles VibrObj en lecture", _instances("MusiqueNiv1") == 1 and _en_lecture("MusiqueNiv1") == 1 and _en_lecture("VibrObj") == 6)
		print("[COLLECTE] BILAN ok=", _ok)
		get_tree().quit(0 if _ok else 1)
