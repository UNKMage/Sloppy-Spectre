class_name MenuPausa
extends CanvasLayer
## Menú de pausa de los niveles (se abre con Esc). Congela el juego de verdad y ofrece:
## Continuar, Opciones, Reiniciar nivel y Menú principal (estos dos piden confirmación).

const MENU := "res://menu_principal.tscn"
const COLOR := Color(0.56, 0.92, 1.0)

var _raiz: Control
var _botones: Array[Button] = []
var _confirmacion: Control
var _opciones: PanelOpciones
var _contenido: Control
var _cerrando := false


## Abre el menú de pausa si no hay otro. Lo llama VolverAlMenu al presionar Esc.
static func abrir(arbol: SceneTree) -> void:
	if arbol.get_first_node_in_group("pausa"):
		return
	var m := MenuPausa.new()
	arbol.root.add_child(m)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pausa")
	get_tree().paused = true
	UIPixel.sonido().call("pausar_juego", true)
	_construir()


func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var oscuro := ColorRect.new()
	oscuro.color = Color(0.02, 0.015, 0.07, 0.7)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(oscuro)

	_contenido = Control.new()
	_contenido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_contenido)

	var titulo := UIPixel.etiqueta("PAUSA", 80, COLOR, 14)
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 70.0
	titulo.offset_bottom = 170.0
	_contenido.add_child(titulo)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var resumen := "SUCIEDAD  %d%%        TIEMPO  %d s" % [int(hud.get("_porcentaje_suciedad")), ceili(hud.get("tiempo_restante"))]
		var linea := UIPixel.etiqueta(resumen, 18, Color(0.85, 0.88, 1.0, 0.95), 6)
		linea.set_anchors_preset(Control.PRESET_TOP_WIDE)
		linea.offset_top = 172.0
		linea.offset_bottom = 204.0
		_contenido.add_child(linea)

	var defs := [
		["Continuar", Color(0.45, 1.0, 0.55), _continuar],
		["Opciones", COLOR, _abrir_opciones],
		["Reiniciar nivel", Color(1.0, 0.83, 0.3), _pedir_reinicio],
		["Menú principal", Color(1.0, 0.55, 0.42), _pedir_menu],
	]
	for i in defs.size():
		var b := UIPixel.boton(defs[i][0], defs[i][1], Vector2(320, 56))
		b.position = Vector2(416, 236 + i * 70)
		b.pressed.connect(defs[i][2])
		_contenido.add_child(b)
		_botones.append(b)

	var pie := UIPixel.etiqueta("Esc = continuar", 13, Color(1, 1, 1, 0.5), 4)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -40.0
	pie.offset_bottom = -16.0
	_contenido.add_child(pie)

	_opciones = PanelOpciones.new()
	_opciones.permitir_intro = false
	_opciones.visible = false
	_opciones.volver.connect(_cerrar_opciones)
	_raiz.add_child(_opciones)

	_botones[0].grab_focus()


# --- Acciones ---

func _continuar() -> void:
	if _cerrando:
		return
	_cerrando = true
	get_tree().paused = false
	UIPixel.sonido().call("pausar_juego", false)
	queue_free()


func _abrir_opciones() -> void:
	_contenido.visible = false
	_opciones.abrir()


func _cerrar_opciones() -> void:
	_contenido.visible = true
	_botones[1].grab_focus()


func _pedir_reinicio() -> void:
	_confirmar("¿Reiniciar el nivel?\nPerderás el progreso de esta partida.", _reiniciar)


func _pedir_menu() -> void:
	_confirmar("¿Volver al menú principal?\nPerderás el progreso de esta partida.", _ir_al_menu)


func _reiniciar() -> void:
	_cerrando = true
	UIPixel.sonido().call("pausar_juego", false)
	get_tree().paused = false
	get_tree().reload_current_scene()
	queue_free()


func _ir_al_menu() -> void:
	_cerrando = true
	UIPixel.sonido().call("pausar_juego", false)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
	queue_free()


## Pregunta sí/no antes de una acción que pierde la partida. Esc o "No" la cancelan.
func _confirmar(texto: String, accion: Callable) -> void:
	for b in _botones:
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = true
	_confirmacion = Control.new()
	_confirmacion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmacion.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(_confirmacion)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.5)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirmacion.add_child(fondo)
	var panel := Panel.new()
	panel.position = Vector2(256, 200)
	panel.size = Vector2(640, 230)
	panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), Color(1.0, 0.83, 0.3), Color(0.45, 0.35, 0.1)))
	_confirmacion.add_child(panel)
	var pregunta := UIPixel.etiqueta(texto, 22, Color.WHITE, 6)
	pregunta.position = Vector2(20, 34)
	pregunta.size = Vector2(600, 90)
	pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(pregunta)
	var no := UIPixel.boton("No", Color(0.45, 1.0, 0.55), Vector2(250, 56))
	no.position = Vector2(50, 146)
	no.pressed.connect(_cancelar_confirmacion)
	panel.add_child(no)
	var si := UIPixel.boton("Sí", Color(1.0, 0.55, 0.42), Vector2(250, 56))
	si.position = Vector2(340, 146)
	si.pressed.connect(accion)
	panel.add_child(si)
	no.grab_focus()  # por defecto "No": evita perder la partida con un Enter sin querer


func _cancelar_confirmacion() -> void:
	if _confirmacion:
		_confirmacion.queue_free()
		_confirmacion = null
	for b in _botones:
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = false
	_botones[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _opciones and _opciones.visible:
		return  # el panel de opciones se cierra solo con Esc
	get_viewport().set_input_as_handled()
	if _confirmacion:
		_cancelar_confirmacion()
	else:
		_continuar()
