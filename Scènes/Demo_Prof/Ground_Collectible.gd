extends Area3D

@export var activated: bool = true
@export var is_collected: bool = false

@onready var light_node: OmniLight3D = $OmniLight3D
@onready var visual_node = $VisualNode
# Boucle FMOD « VibrObj » qui guide le joueur vers le palet. Mise à null une fois coupée (voir arreter_boucle).
@onready var emetteur_boucle: FmodEventEmitter3D = $FmodEventEmitter3D
@export var Joueur: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add to the ground_collectibles group to be found by the player
	add_to_group("ground_collectibles")

	# Connect signal for body entered
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Set initial visibility
	set_visibility(activated)
	#$FmodEventEmitter3D.set_parameter("Distance", 0)
	# 18/10/2026 soir : la boucle ne démarre que pour un palet actif et pas encore ramassé (autoplay est à false
	# dans la scène : c'est ici, et seulement ici, qu'elle est lancée).
	if activated and not is_collected:
		emetteur_boucle.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Make the light pulse to attract attention
	if light_node != null and activated and !is_collected:
		var pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) / 2.0  # Value between 0 and 1
		light_node.light_energy = 1.0 + (pulse * 3.0)  # Vary between 1 and 4
		
		# Optional: Also scale the visual node slightly
		if visual_node != null:
			var scale_factor = 1.0 + (pulse * 0.1)  # Vary between 1.0 and 1.1
			visual_node.scale = Vector3(scale_factor, scale_factor, scale_factor)
	
			
	#if(Joueur != null):
		#if(global_position.distance_to(Joueur.global_position) < 40):
			#print("CONTACT")
			#$FmodEventEmitter3D.set_parameter("Distance", global_position.distance_to(Joueur.global_position)/2)
			
	

func set_visibility(is_visible):
	if is_visible and !is_collected:
		self.show()
	else:
		self.hide()
	set_deferred("monitoring", is_visible and !is_collected)  # 18/10 : invisible = pas détectable (hide() ne coupe pas l'Area3D)

## Coupe net la boucle « VibrObj » du palet et libère son instance FMOD. Sans effet si déjà fait.
## 18/10/2026 soir — bug « les palets continuent de jouer leur musique une fois attrapés » :
##  - hide() ne touche pas à FMOD : la boucle continuait tant que la scène vivait ;
##  - stop() seul (correctif du 18/10 après-midi) respecte allow_fadeout (vrai par défaut) : l'instance passe en
##    STOPPING le temps du relâchement de l'événement (mesuré très court pour la banque actuelle : 1 à 3 images,
##    donc ce stop() suffisait déjà à l'oreille ; une prochaine banque peut l'allonger), puis reste allouée
##    (stop() ne libère pas l'instance) ;
##  - un play() ultérieur (émetteur relancé) la ferait repartir (signal restarted).
## Donc : arrêt immédiat, puis l'émetteur quitte l'arbre (c'est sa sortie de l'arbre qui libère l'instance),
## et plus aucun nœud ne peut le rejouer. Appelé à la collecte, à la fin de partie et à la sortie de la scène.
func arreter_boucle() -> void:
	if emetteur_boucle == null or not is_instance_valid(emetteur_boucle):
		return
	var emetteur := emetteur_boucle
	emetteur_boucle = null
	emetteur.allow_fadeout = false  # FMOD_STUDIO_STOP_IMMEDIATE au lieu de ALLOWFADEOUT
	emetteur.stop()
	if emetteur.is_inside_tree():
		emetteur.get_parent().remove_child(emetteur)  # hors de l'arbre tout de suite : l'instance est libérée ici
	emetteur.queue_free()

func _exit_tree() -> void:
	# Changement de scène (Rejouer, retour au Start) : ne rien laisser sonner derrière soi, même si la banque
	# restait chargée.
	arreter_boucle()

func _on_body_entered(body):
	if body.name == "JoueurDemo" and !is_collected:
		collect(body)

func collect(body):
	if is_collected:
		return
	# Mark as collected
	is_collected = true

	# 18/10/2026 : un palet ramassé doit disparaître aussi pour l'oreille et pour la physique.
	# Avant, sa boucle FMOD « VibrObj » continuait après la capture (hide() ne l'arrête pas) et l'Area3D
	# restait détectable.
	arreter_boucle()
	set_deferred("monitoring", false)  # set_deferred : interdit de changer monitoring pendant body_entered
	set_deferred("monitorable", false)

	# Play collection effect
	if body.has_method("Play_Ground_Collectible_Sound"):
		body.Play_Ground_Collectible_Sound()
	
	# Visual effect for collection
	if light_node != null:
		var tween = create_tween()
		tween.tween_property(light_node, "light_energy", 10.0, 0.2)
		tween.tween_property(light_node, "light_energy", 0.0, 0.3)
	
	if visual_node != null:
		var tween = create_tween()
		tween.tween_property(visual_node, "scale", Vector3(2.0, 2.0, 2.0), 0.3)
	
	# Remove from scene after effect completes
	await get_tree().create_timer(0.5).timeout
	# 18/10/2026 soir : le palet est supprimé pour de bon (avant : seulement caché). Plus de nœud = plus de zone
	# à re-déclencher, plus d'émetteur à relancer. Le joueur garde une référence dans ground_collectibles et
	# teste is_instance_valid avant de s'en servir.
	queue_free()
