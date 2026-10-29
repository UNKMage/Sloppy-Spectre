extends Node

const ESCENA_PANTALLA_CARGA := preload("res://pantalla_carga.tscn")

func cargar_nivel(ruta_siguiente: String) -> void:
	get_tree().paused = false
	var pantalla := ESCENA_PANTALLA_CARGA.instantiate()
	get_tree().root.add_child(pantalla)
	pantalla.iniciar_carga(ruta_siguiente)
