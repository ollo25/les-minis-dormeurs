extends Node3D

func _ready():
	print(ArduinoManager.ultrasonUn)
	print(ArduinoManager.potentiometreUn)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	print("Ultrason : ")
	print(ArduinoManager.ultrasonUn)
	print("Potentiomètre  : ")
	print(ArduinoManager.potentiometreUn)
	#get_parent().rotation.y = deg_to_rad(ArduinoManager.ultrasonUn) * 2
	if(ArduinoManager.boutonTrois):
		get_parent().rotation.y = -1.5
	else:
		get_parent().rotation.y = 0
