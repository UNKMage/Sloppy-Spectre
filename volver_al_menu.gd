extends Node
## Autoload: está activo en TODAS las escenas. Maneja la tecla Esc:
##   - Dentro de un nivel: abre el menú de pausa (ya no se pierde la partida por accidente).
##   - En las pantallas de fin de partida: vuelve al menú principal.
##   - En el menú principal: no hace nada.
## También carga las opciones guardadas (volumen y pantalla completa) al abrir el juego.

const MENU := "res://menu_principal.tscn"


func _ready() -> void:
	# SIEMPRE = sigue funcionando aunque el juego esté en pausa (por ejemplo, tras el Game Over).
	process_mode = Node.PROCESS_MODE_ALWAYS
	Opciones.cargar()


func _input(event: InputEvent) -> void:
	# F11 o Alt+Enter: alterna pantalla completa en cualquier escena (y lo guarda).
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.physical_keycode
		if k == KEY_F11 or (k == KEY_ENTER and event.alt_pressed):
			Opciones.set_pantalla_completa(not Opciones.pantalla_completa)
			Opciones.guardar()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var escena := get_tree().current_scene
	# Si ya estamos en el menú, Esc no hace nada.
	if escena == null or escena.scene_file_path == MENU:
		return
	# El menú de pausa y la pantalla de carga manejan su propio Esc.
	if get_tree().get_first_node_in_group("pausa") or get_tree().get_first_node_in_group("pantalla_carga"):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.get("partida_terminada"):
		# Partida terminada (victoria o game over): Esc vuelve al menú, como dicen esas pantallas.
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU)
	else:
		MenuPausa.abrir(get_tree())
