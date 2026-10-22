class_name ZoneRangement
extends Area3D
## Zone invisible où l'on doit déposer certains objets (bac, table de nuit, tiroir...).
## Si un objet qui a CETTE destination s'y trouve et qu'on ne le tient plus : il est rangé.
## Une fois rangé, l'objet est posé proprement à une place prévue à l'avance
## (en rangées bien centrées), sans changer de taille.

@export var destination: String = ""   # doit être identique à la "destination" des objets
## Les objets sont posés un peu plus haut que le fond de la zone (ex. dans le bac à jouets,
## pour qu'on les voie dépasser, comme posés sur une pile de jouets).
@export var surelevation: float = 0.0

var places := {}   # objet -> { "position": Vector3, "tourner": bool }


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2     # on ne détecte que les objets à ranger


func _physics_process(_delta: float) -> void:
	for corps in get_overlapping_bodies():
		if corps is ObjetRangeable and not corps.est_tenu and not corps.est_range:
			if corps.destination == destination:
				corps.ranger(self)


## Pose l'objet à sa place prévue dans la zone (appelé par l'objet quand il est rangé).
func placer(objet: ObjetRangeable) -> void:
	if places.is_empty():
		_preparer_places()
	objet.reparent(self, false)   # il suit le meuble (le tiroir qui se referme, par exemple)
	objet.plier()                  # ex. le plaid se replie à plat
	var dims: Array = objet.dimensions_rangees()   # [taille, centre]
	var taille: Vector3 = dims[0]
	var place: Dictionary = places.get(objet, {"position": Vector3.ZERO, "tourner": false})
	objet.rotation = Vector3(0, PI / 2 if place["tourner"] else 0.0, 0)
	objet.scale = Vector3.ONE
	var centre: Vector3 = objet.basis * dims[1]
	var zone: Vector3 = $Forme.shape.size
	var case: Vector3 = place["position"]
	objet.position = Vector3(case.x - centre.x, -zone.y / 2 + surelevation - (centre.y - taille.y / 2), case.z - centre.z)


## Calcule une fois pour toutes la place de chaque objet qui doit finir ici :
## en rangées le long du grand côté de la zone, les plus longs d'abord, le tout bien centré.
func _preparer_places() -> void:
	var zone: Vector3 = $Forme.shape.size
	var long_en_x := zone.x >= zone.z
	var longueur := zone.x if long_en_x else zone.z
	var largeur := zone.z if long_en_x else zone.x
	var objets := []
	for objet in get_tree().get_nodes_in_group("objets_rangeables"):
		if objet.destination == destination:
			objets.append(objet)
	# Les plus longs d'abord (ça se range mieux)
	objets.sort_custom(func(a, b): return _long(a) > _long(b))
	var rangees := []   # chaque rangée : liste d'objets
	var longueurs := []
	for objet in objets:
		var mis := false
		for i in rangees.size():
			if longueurs[i] + _long(objet) <= longueur:
				rangees[i].append(objet)
				longueurs[i] += _long(objet) + 0.01
				mis = true
				break
		if not mis:
			rangees.append([objet])
			longueurs.append(_long(objet) + 0.01)
	# Les rangées sont réparties sur la largeur, les objets sur la longueur (bien centrés)
	for r in rangees.size():
		var b := 0.0 if rangees.size() == 1 else lerpf(-largeur / 2 + 0.07, largeur / 2 - 0.07, float(r) / (rangees.size() - 1))
		var total := 0.0
		for objet in rangees[r]:
			total += _long(objet)
		var curseur := -minf(total, longueur) / 2
		var serrage := minf(1.0, longueur / maxf(total, 0.001))   # si ça déborde, on resserre un peu
		for objet in rangees[r]:
			var a := curseur + _long(objet) * serrage / 2
			curseur += _long(objet) * serrage
			var taille: Vector3 = objet.dimensions_rangees()[0]
			var objet_long_en_x := taille.x >= taille.z
			places[objet] = {
				"position": Vector3(a, 0, b) if long_en_x else Vector3(b, 0, a),
				"tourner": objet_long_en_x != long_en_x,
			}


func _long(objet) -> float:
	var t: Vector3 = objet.dimensions_rangees()[0]
	return maxf(t.x, t.z)
