extends Node3D

func _ready():
	print(ArduinoManager.ultrasonUn)
	print(ArduinoManager.potentiometreUn)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):

	#get_parent().rotation.y = deg_to_rad(ArduinoManager.ultrasonUn) * 2

	get_parent().position.y = ArduinoManager.ultrasonUn / 10
	get_parent().rotation.y = deg_to_rad(ArduinoManager.potentiometreUn/3)
