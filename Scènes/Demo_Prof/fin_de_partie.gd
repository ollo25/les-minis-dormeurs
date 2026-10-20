extends CanvasLayer
# Écran de fin de Demo_Prof (18/10/2026) : fondu au noir, temps final de la partie, boutons Rejouer / Quitter.
# Instancié dans Demo_Prof.tscn sous le nom unique « FinDePartie ». La dernière bougie (Object_To_Catch_1.gd,
# final_object = true) appelle afficher(). Le chronomètre démarre à l'entrée de la scène (_ready).
# Avant : la dernière bougie faisait un fondu au noir et le jeu restait noir, souris capturée, sans bouton.

@export_range(0.5, 10.0, 0.5) var duree_fondu: float = 4.0  ## Secondes de fondu au noir avant l'affichage du panneau
@export var titre: String = "Partie terminée"

var temps_final: float = 0.0  # secondes, figé au moment de afficher()
var _debut_ms: int = 0
var _affiche := false

@onready var _fond: ColorRect = %Fond
@onready var _panneau: Control = %Panneau
@onready var _titre_label: Label = %TitreLabel
@onready var _temps_label: Label = %TempsLabel
@onready var _rejouer: Button = %RejouerButton
@onready var _quitter: Button = %QuitterButton

func _ready() -> void:
	_debut_ms = Time.get_ticks_msec()
	visible = false
	_fond.color.a = 0.0
	_panneau.visible = false
	_rejouer.pressed.connect(_on_rejouer)
	_quitter.pressed.connect(_on_quitter)

## Temps écoulé depuis le début de la partie, en secondes.
func temps_ecoule() -> float:
	return float(Time.get_ticks_msec() - _debut_ms) / 1000.0

## « 1 min 23,4 s » ; « 45,2 s » sous la minute.
static func formater_temps(secondes: float) -> String:
	var dixiemes := roundi(secondes * 10.0)  # arrondi d'abord : sinon 119,97 s donnerait « 1 min 60,0 s »
	@warning_ignore("integer_division")
	var minutes := dixiemes / 600
	var reste := (dixiemes % 600) / 10.0
	var s := ("%d min %04.1f s" % [minutes, reste]) if minutes > 0 else ("%.1f s" % reste)
	return s.replace(".", ",")

## Fige le temps, fond au noir en duree_fondu secondes, puis montre le panneau (souris libérée, focus sur Rejouer).
func afficher() -> void:
	if _affiche:
		return
	_affiche = true
	temps_final = temps_ecoule()
	_titre_label.text = titre
	_temps_label.text = "Temps : " + formater_temps(temps_final)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var tween := create_tween()
	tween.tween_property(_fond, "color:a", 1.0, duree_fondu)
	tween.tween_callback(_montrer_panneau)

func _montrer_panneau() -> void:
	_panneau.visible = true
	_rejouer.grab_focus()

func _on_rejouer() -> void:
	# Recharge Demo_Prof : le choix « avec / sans Arduino » (g_vars.no_arduino) est conservé.
	get_tree().reload_current_scene()

func _on_quitter() -> void:
	get_tree().quit()
