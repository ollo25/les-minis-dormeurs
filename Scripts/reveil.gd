extends Node3D
## Réveil posé sur la table de nuit : affiche le temps restant (compte à rebours de 3 min).

@onready var ecran: Label3D = $Ecran


func _process(_delta: float) -> void:
	var secondes := int(ceil(Partie.temps_restant))
	ecran.text = "%d:%02d" % [secondes / 60, secondes % 60]
	# Les 30 dernières secondes, les chiffres passent en rouge
	ecran.modulate = Color(1.0, 0.35, 0.35) if secondes <= 30 else Color(0.5, 1.0, 0.85)
