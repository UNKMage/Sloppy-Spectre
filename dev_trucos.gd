extends Node
## TEMPORAL - atajos de desarrollador. Para quitarlos: borra este archivo y el nodo "DevTrucos"
## de area_2d.tscn. Solo funcionan al correr desde Godot: en un juego exportado
## (OS.is_debug_build() = false) se apagan solos.
##   Tecla 0  ->  pasar el nivel al instante (niveles 1 y 2: entra a la puerta; nivel 3: pantalla final).
##   Tecla 9  ->  llegar a la meta sin entrar a la puerta (la puerta aparece / pantalla final).


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_0:
		_llegar_a_la_meta()
		var puerta := get_tree().get_first_node_in_group("puerta_salida")
		if puerta and puerta.has_method("ir_al_siguiente_nivel"):
			puerta.ir_al_siguiente_nivel()
	elif event.keycode == KEY_9:
		_llegar_a_la_meta()


## Hace lo mismo que cuando la barra de suciedad llega a la meta.
func _llegar_a_la_meta() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not hud.get("partida_terminada") and hud.has_method("_activar_escape"):
		hud.call("_activar_escape")
