class_name Creditos
extends Control
## Créditos: texto que sube por la pantalla sobre el fondo del último nivel. Al terminar queda
## "GRACIAS POR JUGAR". Abajo: mantén Espacio o clic para ir más rápido; Esc vuelve al menú.

const MENU := "res://menu_principal.tscn"
const VELOCIDAD := 46.0
const VELOCIDAD_RAPIDA := 190.0
const ORO := Color(1.0, 0.83, 0.3)
const CIAN := Color(0.56, 0.92, 1.0)

## Cada línea: [tipo, texto]. Tipos: titulo, seccion, nombre, texto, espacio.
const LINEAS := [
	["titulo", "SLOPPY SPECTRE"],
	["texto", "Juego arcade 2D de vista superior"],
	["espacio", ""],
	["seccion", "UN JUEGO DE"],
	["nombre", "Sofia Fernanda Flores Amador"],
	["nombre", "Jesús Emiliano Gutiérrez Luna"],
	["nombre", "Ángel Federico López Ruiz"],
	["nombre", "Karol Citlaly Ramírez Martínez"],
	["espacio", ""],
	["seccion", "HERRAMIENTAS"],
	["texto", "Motor: Godot Engine 4"],
	["texto", "Lenguaje: GDScript"],
	["texto", "Barras de estado y fuente pixel: Pixel Bars"],
	["texto", "por heyheythere (itch.io)"],
	["espacio", ""],
	["seccion", "ARTE"],
	["texto", "Fondos de los niveles y personajes ilustrados"],
	["texto", "Interfaz, efectos y animaciones en pixel art"],
	["texto", "dibujados con código"],
	["espacio", ""],
	["seccion", "AGRADECIMIENTOS"],
	["texto", "A todos los que probaron el juego"],
	["texto", "y soportaron al Limpiador"],
	["espacio", ""],
	["espacio", ""],
	["titulo", "GRACIAS POR JUGAR"],
]

var _fuente: Font
var _rollo: Control
var _spooky: Sprite2D
var _cortina: ColorRect
var _t := 0.0
var _alto_rollo := 0.0
var _termino := false
var _saliendo := false
var _aviso: Label


func _ready() -> void:
	_fuente = UIPixel.fuente()
	_construir_fondo()
	_construir_rollo()
	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.01, 0.06, 1.0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	create_tween().tween_property(_cortina, "color:a", 0.0, 0.8)


func _process(delta: float) -> void:
	_t += delta
	if _spooky:
		_spooky.offset.y = (sin(_t * 2.4) * 1.4) if _termino else 0.0
	if _termino or _saliendo:
		return
	var rapido := Input.is_action_pressed("ensuciar") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_rollo.position.y -= (VELOCIDAD_RAPIDA if rapido else VELOCIDAD) * delta
	# Cuando la última línea llega al centro, el rollo se detiene.
	if _rollo.position.y + _alto_rollo <= 340.0:
		_rollo.position.y = 340.0 - _alto_rollo
		_terminar_rollo()


func _unhandled_input(event: InputEvent) -> void:
	if _saliendo:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_salir()
	elif _termino and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ensuciar")
			or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		_salir()


func _construir_fondo() -> void:
	var fondo := TextureRect.new()
	fondo.texture = load("res://fondonivel3.jpg")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.pivot_offset = Vector2(576, 324)
	add_child(fondo)
	create_tween().tween_property(fondo, "scale", Vector2(1.12, 1.12), 60.0)
	var oscuro := ColorRect.new()
	oscuro.color = Color(0.02, 0.015, 0.07, 0.8)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oscuro)
	# Motas doradas que suben
	var p := CPUParticles2D.new()
	p.position = Vector2(576, 380)
	p.amount = 50
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(620, 340)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 0.9, 0.5, 0.0), Color(1.0, 0.88, 0.45, 0.55), Color(0.6, 1.0, 0.7, 0.0)])
	p.color_ramp = g
	add_child(p)


func _construir_rollo() -> void:
	_rollo = Control.new()
	_rollo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rollo)
	var y := 0.0
	for linea in LINEAS:
		var tipo: String = linea[0]
		var texto: String = linea[1]
		var l: Label
		var alto := 0.0
		match tipo:
			"titulo":
				l = UIPixel.etiqueta(texto, 56, ORO, 12)
				alto = 78.0
			"seccion":
				l = UIPixel.etiqueta("— %s —" % texto, 22, CIAN, 6)
				alto = 52.0
			"nombre":
				l = UIPixel.etiqueta(texto, 26, Color.WHITE, 6)
				alto = 44.0
			"texto":
				l = UIPixel.etiqueta(texto, 18, Color(0.85, 0.88, 1.0, 0.95), 5)
				alto = 34.0
			_:
				alto = 36.0
		if l != null:
			l.position = Vector2(0, y)
			l.size = Vector2(1152, alto)
			_rollo.add_child(l)
		y += alto
	_alto_rollo = y
	_rollo.position = Vector2(0, 648.0)  # empieza justo debajo de la pantalla

	_spooky = Sprite2D.new()
	_spooky.texture = preload("res://Ghost.png")
	_spooky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spooky.scale = Vector2(6, 6)
	_spooky.position = Vector2(576, 700)  # entra al final
	add_child(_spooky)

	_aviso = UIPixel.etiqueta("Presiona ESPACIO o haz clic para volver al menú", 16, Color(1, 1, 1, 0.8), 5)
	_aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_aviso.offset_top = -50.0
	_aviso.offset_bottom = -22.0
	_aviso.modulate.a = 0.0
	add_child(_aviso)
	var pie := UIPixel.etiqueta("Mantén ESPACIO o clic: más rápido      Esc: salir", 12, Color(1, 1, 1, 0.4), 4)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -24.0
	pie.offset_bottom = -4.0
	pie.name = "Pie"
	add_child(pie)


func _terminar_rollo() -> void:
	_termino = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_spooky, "position:y", 520.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_aviso, "modulate:a", 1.0, 0.8).set_delay(1.2)
	var pie := get_node_or_null("Pie")
	if pie:
		pie.queue_free()


func _salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU))
