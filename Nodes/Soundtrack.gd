extends Node3D

@export var Son_A_Jouer:AudioStream
@export var Autoplay:bool = false
@export var Spatialiser:bool = false
@export var SpatialiserDistance:float = 10
@export var Volume_dB:float = 0
@export var Jouer_Une_Fois:bool = false
@export var LayeringNumber:int = false
@export var LayeringBeat:float = 0
@export var Master:String = "Master"

# TODO Fonction déclencheur

#@export_enum("Master", "Voice") var audio_bus_name: String = "Master"
#func _ready() -> void:
	#var bus_index: int = AudioServer.get_bus_index(audio_bus_name)
	#print("Selected audio bus index: ", bus_index)
