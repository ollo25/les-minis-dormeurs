extends Node3D
## Commode : un tiroir s'ouvre tout seul quand la main du joueur s'en approche,
## puis se referme quand elle s'éloigne (avec les objets rangés dedans).

const OUVERTURE := 0.35        # le tiroir sort de 35 cm
const DISTANCE_MAIN := 0.45    # distance main ↔ façade pour ouvrir
const VITESSE := 3.0           # vitesse d'ouverture / fermeture

@onready var tiroirs: Array[Node3D] = [$Tiroir_Haut, $Tiroir_Milieu, $Tiroir_Bas]
var position_fermee := {}


func _ready() -> void:
	for t in tiroirs:
		position_fermee[t] = t.position


func _process(delta: float) -> void:
	var main := Partie.position_main()
	# On n'ouvre que le tiroir le plus proche de la main (s'il est assez proche)
	var plus_proche: Node3D = null
	var meilleure := DISTANCE_MAIN
	for t in tiroirs:
		var facade: Vector3 = t.get_node("Facade").global_position
		var d := main.distance_to(facade)
		if d < meilleure:
			meilleure = d
			plus_proche = t
	for t in tiroirs:
		var cible: Vector3 = position_fermee[t]
		if t == plus_proche:
			cible.x -= OUVERTURE      # la façade est du côté -X de la commode
		t.position = t.position.move_toward(cible, VITESSE * delta)
