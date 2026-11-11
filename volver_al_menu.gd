extends Node
## Autoload: está activo en TODAS las escenas. Con Esc regresa al menú principal.

const MENU := "res://menu_principal.tscn"


func _ready() -> void:
	# SIEMPRE = sigue funcionando aunque el juego esté en pausa (por ejemplo, tras el Game Over).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var escena := get_tree().current_scene
	# Si ya estamos en el menú, Esc no hace nada.
	if escena == null or escena.scene_file_path == MENU:
		return
	get_tree().paused = false  # el HUD pausa el juego al terminar; hay que despausar
	get_tree().change_scene_to_file(MENU)
