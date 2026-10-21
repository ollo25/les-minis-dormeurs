extends Node3D
## Scène principale : la chambre du bébé.
## Active la VR (OpenXR) si le casque est détecté, sinon reste en mode écran.

func _ready() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("[Chambre] OpenXR prêt : passage en VR")
		get_viewport().use_xr = true
		# Le casque gère lui-même la fréquence d'affichage
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else:
		print("[Chambre] Pas de casque détecté : mode écran (vérifie que Quest Link est lancé)")
