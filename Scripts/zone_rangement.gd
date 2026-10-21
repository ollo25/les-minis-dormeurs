class_name ZoneRangement
extends Area3D
## Zone invisible où l'on doit déposer certains objets (bac, table de nuit, tiroir...).
## Si un objet qui a CETTE destination s'y trouve et qu'on ne le tient plus : il est rangé.

@export var destination: String = ""   # doit être identique à la "destination" des objets


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # on ne détecte que les objets à ranger


func _physics_process(_delta: float) -> void:
	for corps in get_overlapping_bodies():
		if corps is ObjetRangeable and not corps.est_tenu and not corps.est_range:
			if corps.destination == destination:
				corps.ranger(self)
