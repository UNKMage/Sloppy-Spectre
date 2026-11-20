class_name PanelOpciones
extends Control
## Panel de opciones (volumen y pantalla completa). Lo usan el menú principal y el de pausa.
## Los cambios se aplican al instante y se guardan al cerrar (botón Volver o Esc).

signal volver

const COLOR := Color(0.56, 0.92, 1.0)

var _sliders: Dictionary = {}   # bus -> PixelSlider
var _porcentajes: Dictionary = {}  # bus -> Label
var _boton_pantalla: Button
var _boton_volver: Button
var _boton_intro: Button
var _boton_tutorial: Button
## En el menú de pausa no se puede ver la introducción (se perdería la partida).
var permitir_intro: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea clics a lo que haya detrás

	var oscuro := ColorRect.new()
	oscuro.color = Color(0.02, 0.015, 0.07, 0.78)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oscuro)

	var panel := Panel.new()
	panel.position = Vector2(256, 86)
	panel.size = Vector2(640, 488)
	panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), COLOR.darkened(0.2), COLOR.darkened(0.65)))
	add_child(panel)

	var titulo := UIPixel.etiqueta("OPCIONES", 40, COLOR, 10)
	titulo.position = Vector2(0, 22)
	titulo.size = Vector2(640, 52)
	panel.add_child(titulo)

	var filas := [["Master", "GENERAL"], ["Musica", "MÚSICA"], ["Efectos", "EFECTOS"]]
	for i in filas.size():
		var bus: String = filas[i][0]
		var y := 104.0 + i * 62.0
		var nombre := UIPixel.etiqueta(filas[i][1], 20, Color.WHITE, 6, HORIZONTAL_ALIGNMENT_LEFT)
		nombre.position = Vector2(36, y + 2)
		nombre.size = Vector2(190, 30)
		panel.add_child(nombre)
		var s := PixelSlider.new()
		s.position = Vector2(236, y)
		s.valor = Opciones.volumen[bus]
		s.cambiado.connect(_on_volumen.bind(bus))
		s.soltado.connect(_on_soltado.bind(bus))
		panel.add_child(s)
		_sliders[bus] = s
		var p := UIPixel.etiqueta("%d%%" % roundi(s.valor * 100.0), 18, Color(0.85, 0.88, 1.0), 5, HORIZONTAL_ALIGNMENT_RIGHT)
		p.position = Vector2(530, y + 4)
		p.size = Vector2(80, 26)
		panel.add_child(p)
		_porcentajes[bus] = p

	_boton_pantalla = UIPixel.boton("", COLOR, Vector2(568, 52), 20)
	_boton_pantalla.position = Vector2(36, 290)
	_boton_pantalla.pressed.connect(_on_pantalla)
	panel.add_child(_boton_pantalla)
	_actualizar_boton_pantalla()

	# Introducción y tutorial: volver a verlos.
	_boton_intro = UIPixel.boton("Ver introducción", COLOR, Vector2(278, 52), 17)
	_boton_intro.position = Vector2(36, 348)
	_boton_intro.disabled = not permitir_intro
	_boton_intro.pressed.connect(_on_intro)
	panel.add_child(_boton_intro)
	_boton_tutorial = UIPixel.boton("Repetir tutorial", COLOR, Vector2(278, 52), 17)
	_boton_tutorial.position = Vector2(326, 348)
	_boton_tutorial.pressed.connect(_on_tutorial)
	panel.add_child(_boton_tutorial)

	_boton_volver = UIPixel.boton("Volver", Color(0.65, 0.7, 1.0), Vector2(568, 52), 22)
	_boton_volver.position = Vector2(36, 414)
	_boton_volver.pressed.connect(_cerrar)
	panel.add_child(_boton_volver)


## Muestra el panel y pone el foco en el primer control (así se maneja con teclado).
func abrir() -> void:
	visible = true
	(_sliders["Master"] as PixelSlider).grab_focus()


func _on_volumen(valor: float, bus: String) -> void:
	Opciones.set_volumen(bus, valor)
	(_porcentajes[bus] as Label).text = "%d%%" % roundi(valor * 100.0)


## Al soltar un deslizador suena una muestra, para oír el volumen que quedó.
func _on_soltado(bus: String) -> void:
	if bus != "Musica":
		UIPixel.sonido().call("reproducir_disparo")


func _on_pantalla() -> void:
	Opciones.set_pantalla_completa(not Opciones.pantalla_completa)
	_actualizar_boton_pantalla()


func _actualizar_boton_pantalla() -> void:
	_boton_pantalla.text = "PANTALLA COMPLETA:  %s" % ("SÍ" if Opciones.pantalla_completa else "NO")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cerrar()


func _cerrar() -> void:
	Opciones.guardar()
	visible = false
	volver.emit()


func _on_intro() -> void:
	Opciones.guardar()
	Historia.contar(get_tree(), "intro", "res://menu_principal.tscn")


func _on_tutorial() -> void:
	for clave in ["tutorial_basico", "orbe_0", "orbe_1"]:
		Opciones.vistos.erase(clave)
	Opciones.guardar()
	_boton_tutorial.text = "¡Listo! Sale en el nivel 1"
