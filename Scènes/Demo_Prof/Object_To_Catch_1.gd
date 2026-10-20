extends Area3D

@onready var AudioPlayer3D: AudioStreamPlayer3D = $AudioStreamPlayer3D

var PulseSounds = [
	"res://Ne pas toucher/Sons/SFX_BOUCLES/OBJET_LOOP_1.wav",
	"res://Ne pas toucher/Sons/SFX_BOUCLES/OBJET_LOOP_2.wav",
	"res://Ne pas toucher/Sons/SFX_BOUCLES/OBJET_LOOP_3.wav",
	"res://Ne pas toucher/Sons/SFX_BOUCLES/OBJET_LOOP_4.wav"
]

@export var activated: bool = false
@export var Prochain_Objet_A_Activer: Node
@export var final_object: bool = false

@onready var final_camera = %Final_Camera

var _attrape := false  # évite une double capture pendant la même image physique

func _ready():
	set_visibility(activated)
	if activated:
		play_random_sound()
	connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta):
	pass

# 18/10/2026 : une bougie cachée ne doit plus être « attrapable ». hide() ne coupe pas la détection d'un Area3D :
# avant, traverser une bougie invisible (non activée) la faisait disparaître, activait la suivante, et la bougie
# finale invisible (au sol, près du palet 6) terminait la partie d'un coup. La détection suit maintenant l'activation.
func set_visibility(is_visible):
	if is_visible:
		self.show()
	else:
		self.hide()
	set_deferred("monitoring", is_visible)

func play_random_sound():
	var random_index = randi() % PulseSounds.size()
	AudioPlayer3D.stream = load(PulseSounds[random_index])
	AudioPlayer3D.play()

func _on_body_entered(body):
	if body.name != "JoueurDemo" or _attrape:
		return
	_attrape = true
	ArduinoManager.send_led(1)
	print("sent led")
	# Son de capture (ObjectCatch) et musique : dans tous les cas, même sans objet suivant.
	body.Play_Feedback_Sound()
	if final_object:
		# Fin de partie : le joueur s'arrête (vibration coupée, souris libérée) mais reste visible pour FMOD
		# (l'écouteur et l'émetteur ObjectCatch sont ses enfants : le cacher coupait le dernier son de capture).
		if body.has_method("terminer_partie"):
			body.terminer_partie()
		final_camera.make_current()
		AudioPlayer3D.stream_paused = true
		body.BackgroundSoundPlayer.stream_paused = true
		set_deferred("monitoring", false)  # reste visible pour la caméra finale, plus détectable
		var fin := get_node_or_null("%FinDePartie")
		if fin:
			fin.afficher()
		else:
			push_warning("Object_To_Catch_1 : pas de nœud %FinDePartie dans la scène, pas d'écran de fin")
	else:
		if Prochain_Objet_A_Activer and is_instance_valid(Prochain_Objet_A_Activer):
			Prochain_Objet_A_Activer.activated = true
			Prochain_Objet_A_Activer.set_visibility(true)
			Prochain_Objet_A_Activer.play_random_sound()
		queue_free()

func _on_audio_stream_player_3d_finished():
	AudioPlayer3D.play()
