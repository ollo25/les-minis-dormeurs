extends Node3D
## Commode : un tiroir s'ouvre tout seul quand la main du joueur est devant lui,
## puis se referme quand elle s'en va (avec les objets rangés dedans).

const OUVERTURE := 0.35        # le tiroir sort de 35 cm
const VITESSE := 1.5           # vitesse d'ouverture / fermeture (m/s)
const PORTEE := 0.6            # la main doit être à moins de 60 cm devant la façade
const MARGE := 0.05            # une fois ouvert, on garde le tiroir ouvert un peu plus loin (évite le clignotement)

@onready var tiroirs: Array[Node3D] = [$Tiroir_Haut, $Tiroir_Milieu, $Tiroir_Bas]
var position_fermee := {}
var tiroir_ouvert: Node3D = null
var numero_son := 0


func _ready() -> void:
	for t in tiroirs:
		position_fermee[t] = t.position


func _process(delta: float) -> void:
	var main := Partie.position_main()
	var avant := tiroir_ouvert
	# Si le tiroir déjà ouvert a toujours la main devant lui, on le garde ouvert.
	# Sinon on cherche un autre tiroir avec la main devant.
	if tiroir_ouvert == null or not _main_devant(tiroir_ouvert, main, MARGE):
		tiroir_ouvert = null
		for t in tiroirs:
			if _main_devant(t, main, 0.0):
				tiroir_ouvert = t
				break
	# Son : un tiroir vient de s'ouvrir ou de se fermer
	if tiroir_ouvert != avant:
		_jouer_son_tiroir(tiroir_ouvert != null)
	for t in tiroirs:
		var cible: Vector3 = position_fermee[t]
		if t == tiroir_ouvert:
			cible.x -= OUVERTURE      # la façade est du côté -X de la commode
		t.position = t.position.move_toward(cible, VITESSE * delta)


## La main est-elle "devant" ce tiroir ? On regarde depuis la position FERMÉE du tiroir,
## pour que le fait qu'il bouge ne change pas la réponse (sinon il s'ouvre/ferme en boucle).
func _main_devant(t: Node3D, main: Vector3, marge: float) -> bool:
	var repere := global_transform * Transform3D(Basis(), position_fermee[t])
	var p := repere.affine_inverse() * main     # position de la main vue depuis le tiroir fermé
	var dans_la_largeur := absf(p.z) < 0.48 + marge          # la façade fait 90 cm de large
	# chaque tiroir fait 24 cm de haut ; une fois ouvert, on accepte la main plus haut
	# (au-dessus du tiroir, pour y déposer un objet) sans qu'il se referme
	var haut_max := 0.135 + (0.3 if marge > 0.0 else 0.0)
	var a_la_hauteur := p.y > -(0.135 + marge) and p.y < haut_max
	var devant := p.x > -PORTEE - marge and p.x < 0.1         # devant la façade (côté -X)
	return dans_la_largeur and a_la_hauteur and devant


## Son du tiroir (event FMOD "Tiroir" : paramètre 0 = ouverture, 1 = fermeture).
## L'event boucle tout seul, donc on l'arrête après un passage.
func _jouer_son_tiroir(ouverture: bool) -> void:
	$SonTiroir.set_parameter("Tiroir", 0 if ouverture else 1)
	$SonTiroir.play()
	numero_son += 1
	var mon_numero := numero_son
	await get_tree().create_timer(2.1 if ouverture else 2.5).timeout
	if numero_son == mon_numero:     # aucun autre son de tiroir n'a été lancé entre-temps
		$SonTiroir.stop()
