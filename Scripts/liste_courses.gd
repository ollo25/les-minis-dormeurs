extends Node3D
## Liste "de courses" accrochée au mur : les objets à ranger.
## Quand un objet est rangé au bon endroit, sa ligne est barrée.

const TAILLE_TEXTE := 30
const TAILLE_PIXEL := 0.0006       # taille d'un pixel de texte en mètres
const INTERLIGNE := 0.022          # espace entre deux lignes (m)
const COULEUR_ENCRE := Color(0.15, 0.18, 0.45)
const COULEUR_BARREE := Color(0.15, 0.18, 0.45, 0.45)

var lignes := {}   # objet -> { "texte": Label3D, "barre": CSGBox3D }


func _ready() -> void:
	Partie.objet_range_signal.connect(_on_objet_range)
	# On attend une image : les objets de la chambre doivent être prêts
	await get_tree().process_frame
	_construire_liste()


func _construire_liste() -> void:
	var y := 0.08   # première ligne, sous le titre
	for objet in get_tree().get_nodes_in_group("objets_rangeables"):
		var texte := Label3D.new()
		texte.text = "- " + objet.nom_affiche
		texte.font_size = TAILLE_TEXTE
		texte.pixel_size = TAILLE_PIXEL
		texte.modulate = COULEUR_ENCRE
		texte.outline_size = 0
		texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texte.position = Vector3(-0.085, y, 0.003)
		add_child(texte)
		# Trait pour barrer la ligne (caché tant que l'objet n'est pas rangé)
		var largeur := ThemeDB.fallback_font.get_string_size(texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE).x * TAILLE_PIXEL
		var barre := CSGBox3D.new()
		barre.size = Vector3(largeur + 0.006, 0.0018, 0.001)
		barre.position = Vector3(-0.088 + largeur / 2.0, y, 0.004)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.2, 0.3)
		barre.material = mat
		barre.visible = false
		add_child(barre)
		lignes[objet] = {"texte": texte, "barre": barre}
		y -= INTERLIGNE


func _on_objet_range(objet) -> void:
	if lignes.has(objet):
		lignes[objet]["barre"].visible = true
		lignes[objet]["texte"].modulate = COULEUR_BARREE
