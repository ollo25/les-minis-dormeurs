class_name ObjetRangeable
extends RigidBody3D
## Un objet que le joueur peut ramasser puis ranger (ou lancer !).
## Il reste immobile à sa place de départ (freeze) jusqu'à ce qu'on le prenne.

@export var nom_affiche: String = ""        # ex. "Poupée"
@export var destination: String = ""        # ex. "BacAJouets" (nom de la zone de rangement)
@export var bruyant: bool = false           # fait du bruit si on le manipule brusquement

const VITESSE_LANCER_MAX := 6.0             # m/s, pour éviter les lancers absurdes

var parent_depart: Node   # le nœud "Objets" de la chambre, pour le remettre au bon endroit
var position_depart: Vector3   # si jamais l'objet passe sous le sol, on le remet ici
var est_tenu := false
var est_range := false                       # true quand il est à sa place : on ne peut plus le prendre
var derniere_position := Vector3.ZERO
var vitesse_main := Vector3.ZERO            # vitesse mesurée pendant qu'on le tient


func _ready() -> void:
	add_to_group("objets_rangeables")
	freeze = true                 # ne tombe pas tant qu'on ne l'a pas touché
	collision_layer = 2           # couche 2 = objets à ranger
	collision_mask = 1 | 2        # il touche le décor (couche 1) et les autres objets
	# Détection "continue" : un objet fin ou lancé vite ne traverse plus le sol
	continuous_cd = true
	# Simple et stable : l'objet ne tourne pas sur lui-même, il retombe toujours droit
	lock_rotation = true
	position_depart = global_position


func _physics_process(delta: float) -> void:
	# Filet de sécurité : s'il est passé sous le sol, on le remet à sa place de départ
	if not est_tenu and not est_range and global_position.y < -0.3:
		global_position = position_depart
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	if est_tenu:
		# On mesure à quelle vitesse la main déplace l'objet (lissé pour éviter les à-coups)
		var vitesse_instant := (global_position - derniere_position) / delta
		vitesse_main = vitesse_main.lerp(vitesse_instant, 0.5)
		derniere_position = global_position


## Appelé quand une main (ou la caméra en debug) attrape l'objet.
func etre_pris(main: Node3D) -> void:
	parent_depart = get_parent()
	freeze = true
	$Forme.disabled = true        # pendant qu'on le tient, il ne pousse rien
	reparent(main)                # il suit la main (en gardant sa position actuelle)
	est_tenu = true
	derniere_position = global_position
	vitesse_main = Vector3.ZERO
	Partie.objet_ramasse(self)


## Appelé quand on lâche l'objet : il part avec la vitesse de la main.
func etre_lache() -> void:
	est_tenu = false
	reparent(parent_depart)
	$Forme.disabled = false
	freeze = false
	linear_velocity = vitesse_main.limit_length(VITESSE_LANCER_MAX)
	angular_velocity = Vector3.ZERO


## Appelé par une zone de rangement quand l'objet est posé au bon endroit.
func ranger(zone: Node3D) -> void:
	est_range = true
	freeze = true
	linear_velocity = Vector3.ZERO
	collision_layer = 0          # on ne peut plus l'attraper, il ne gêne plus
	$Forme.set_deferred("disabled", true)
	# Il suit le meuble (ex. le tiroir qui se referme avec l'objet dedans)
	reparent.call_deferred(zone.get_parent())
	Partie.objet_range(self)
