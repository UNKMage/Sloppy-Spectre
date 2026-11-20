class_name Historia
extends Control
## Escenas de historia con texto que se escribe solo: la introducción (antes del nivel 1) y el
## cierre (después de ganar el nivel 3). Se abren con Historia.contar(arbol, "intro", destino).
## Espacio, Enter o clic = siguiente (si el texto aún se escribe, lo completa). Esc = saltar todo.

const FONDO_INTRO := "res://fondonivel2.jpg"
const FONDO_FINAL := "res://fondonivel3.jpg"
const ESCENA := "res://historia.tscn"
const MENU := "res://menu_principal.tscn"
## Letras por segundo del efecto de máquina de escribir.
const VELOCIDAD_TEXTO := 42.0

## Cada página: texto, fondo y quién aparece (spooky / limpiador, con su ánimo).
const PAGINAS := {
	"intro": [
		{"texto": "En una vieja vecindad vive un fantasma pequeño y travieso.", "fondo": FONDO_INTRO, "spooky": "feliz", "limpiador": ""},
		{"texto": "Se llama Spooky. Le encanta flotar por los pasillos, desordenar y dejar manchas de ectoplasma por todas partes.", "fondo": FONDO_INTRO, "spooky": "feliz", "limpiador": ""},
		{"texto": "Pero un día llegó el Limpiador, con su linterna y su aspiradora implacable.", "fondo": FONDO_INTRO, "spooky": "susto", "limpiador": "serio"},
		{"texto": "Cada mancha que borra es un pedacito de hogar que Spooky pierde.", "fondo": FONDO_INTRO, "spooky": "triste", "limpiador": "serio"},
		{"texto": "Así que Spooky tomó una decisión: ensuciarlo todo, hasta que nadie pueda limpiarlo.", "fondo": FONDO_INTRO, "spooky": "decidido", "limpiador": "serio"},
	],
	"final": [
		{"texto": "La vecindad quedó cubierta de ectoplasma de punta a punta.", "fondo": FONDO_FINAL, "spooky": "feliz", "limpiador": ""},
		{"texto": "El Limpiador miró su aspiradora llena, su linterna sin pilas... y se rindió.", "fondo": FONDO_FINAL, "spooky": "", "limpiador": "derrotado"},
		{"texto": "Spooky flotó feliz por cada rincón. Por fin era su hogar otra vez.", "fondo": FONDO_FINAL, "spooky": "feliz", "limpiador": ""},
		{"texto": "Pero allá a lo lejos, entre las sombras, se encendió otra linterna...", "fondo": FONDO_FINAL, "spooky": "susto", "limpiador": ""},
		{"texto": "¿Habrá más vecindades que ensuciar?", "fondo": FONDO_FINAL, "spooky": "decidido", "limpiador": ""},
	],
}

static var _id: String = "intro"
static var _siguiente: String = "res://main.tscn"

var _fuente: Font
var _paginas: Array
var _indice := -1
var _fondo: TextureRect
var _fondo_viejo: TextureRect
var _texto: Label
var _puntos: Control
var _spooky: Sprite2D
var _limpiador: Sprite2D
var _cortina: ColorRect
var _escribiendo := false
var _caracteres := 0.0
var _t := 0.0
var _saliendo := false
var _luz: Control


## Abre una historia ("intro" o "final") y, al terminar, pasa a la escena `siguiente`.
static func contar(arbol: SceneTree, id: String, siguiente: String) -> void:
	_id = id
	_siguiente = siguiente
	arbol.paused = false
	arbol.change_scene_to_file(ESCENA)


func _ready() -> void:
	_fuente = UIPixel.fuente()
	_paginas = PAGINAS[_id]
	_construir()
	_siguiente_pagina()
	create_tween().tween_property(_cortina, "color:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if _escribiendo:
		_caracteres += VELOCIDAD_TEXTO * delta
		_texto.visible_characters = int(_caracteres)
		if _caracteres >= _texto.text.length():
			_escribiendo = false
	if _spooky:
		_spooky.position.y = 330.0 + sin(_t * 2.2) * 9.0
		_spooky.rotation = sin(_t * 1.5) * 0.08
	if _limpiador:
		_limpiador.position.y = 346.0 + sin(_t * 1.8 + 1.0) * 4.0
	if _luz:
		_luz.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _saliendo:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_terminar()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ensuciar") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _escribiendo:
			_caracteres = _texto.text.length()
			_texto.visible_characters = -1
			_escribiendo = false
		else:
			_siguiente_pagina()


# --- Construcción ---

func _construir() -> void:
	_fondo = _nuevo_fondo()
	add_child(_fondo)
	_fondo_viejo = _nuevo_fondo()
	_fondo_viejo.modulate.a = 0.0
	add_child(_fondo_viejo)

	var oscuro := ColorRect.new()
	oscuro.color = Color(0.03, 0.02, 0.09, 0.55)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oscuro)

	# Luz del Limpiador (cono) y personajes
	_luz = Control.new()
	_luz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_luz.draw.connect(_dibujar_luz)
	add_child(_luz)
	_spooky = Sprite2D.new()
	_spooky.texture = preload("res://Ghost.png")
	_spooky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spooky.scale = Vector2(7, 7)
	_spooky.position = Vector2(330, 330)
	_spooky.visible = false
	add_child(_spooky)
	_limpiador = Sprite2D.new()
	_limpiador.texture = preload("res://personajes/limpiador1.png")
	_limpiador.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_limpiador.scale = Vector2(7, 7)
	_limpiador.position = Vector2(830, 346)
	_limpiador.visible = false
	add_child(_limpiador)

	# Barras de cine arriba y abajo
	for y in [0.0, 568.0]:
		var barra := ColorRect.new()
		barra.color = Color(0.02, 0.015, 0.06)
		barra.position = Vector2(0, y)
		barra.size = Vector2(1152, 80)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(barra)

	# Cuadro de texto
	var caja := Panel.new()
	caja.position = Vector2(106, 440)
	caja.size = Vector2(940, 150)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), Color(0.56, 0.92, 1.0), Color(0.18, 0.4, 0.5)))
	add_child(caja)
	_texto = UIPixel.etiqueta("", 24, Color.WHITE, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_texto.position = Vector2(32, 26)
	_texto.size = Vector2(876, 92)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	caja.add_child(_texto)
	var pista := UIPixel.etiqueta("ESPACIO / clic: continuar      Esc: saltar", 13, Color(1, 1, 1, 0.5), 4, HORIZONTAL_ALIGNMENT_RIGHT)
	pista.position = Vector2(300, 118)
	pista.size = Vector2(620, 22)
	caja.add_child(pista)
	_puntos = Control.new()
	_puntos.position = Vector2(32, 126)
	_puntos.size = Vector2(200, 12)
	_puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puntos.draw.connect(_dibujar_puntos)
	caja.add_child(_puntos)

	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.01, 0.06, 1.0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)


func _nuevo_fondo() -> TextureRect:
	var f := TextureRect.new()
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.pivot_offset = Vector2(576, 324)
	return f


func _dibujar_puntos() -> void:
	for i in _paginas.size():
		var c := Color(0.56, 0.92, 1.0) if i <= _indice else Color(1, 1, 1, 0.2)
		_puntos.draw_rect(Rect2(i * 18, 0, 10, 10), c)


## Cono de luz del Limpiador cuando aparece, para dar ambiente.
func _dibujar_luz() -> void:
	if not _limpiador.visible:
		return
	var origen := _limpiador.position + Vector2(-50, -10)
	var puntas := [Vector2(-420, -120), Vector2(-420, 150)]
	for k in 4:
		var f := 1.0 - k * 0.22
		var a: Vector2 = origen + puntas[0] * f
		var b: Vector2 = origen + puntas[1] * f
		_luz.draw_colored_polygon(PackedVector2Array([origen, a, b]), Color(1.0, 0.9, 0.5, 0.07))


# --- Páginas ---

func _siguiente_pagina() -> void:
	_indice += 1
	if _indice >= _paginas.size():
		_terminar()
		return
	var p: Dictionary = _paginas[_indice]
	# Fondo nuevo con fundido cruzado y zoom lento.
	var textura := load(p["fondo"]) as Texture2D
	if _fondo.texture != textura:
		_fondo_viejo.texture = _fondo.texture
		_fondo_viejo.modulate.a = 1.0 if _fondo.texture else 0.0
		_fondo.texture = textura
		_fondo.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_fondo, "modulate:a", 1.0, 0.6)
		tw.tween_property(_fondo_viejo, "modulate:a", 0.0, 0.6)
	_fondo.scale = Vector2.ONE
	create_tween().tween_property(_fondo, "scale", Vector2(1.1, 1.1), 14.0)

	_poner_personaje(_spooky, p["spooky"], Vector2(330, 330))
	_poner_personaje(_limpiador, p["limpiador"], Vector2(830, 346))
	_texto.text = p["texto"]
	_texto.visible_characters = 0
	_caracteres = 0.0
	_escribiendo = true
	_puntos.queue_redraw()
	# Pequeño golpe de pantalla cuando aparece el Limpiador.
	if p["limpiador"] != "" and (_indice == 0 or _paginas[_indice - 1]["limpiador"] == ""):
		var tw2 := create_tween()
		tw2.tween_property(self, "position:x", 8.0, 0.04)
		tw2.tween_property(self, "position:x", -8.0, 0.04)
		tw2.tween_property(self, "position:x", 0.0, 0.06)


## Muestra u oculta a un personaje y le da su "ánimo" con color y tamaño.
func _poner_personaje(s: Sprite2D, animo: String, destino: Vector2) -> void:
	if animo == "":
		s.visible = false
		return
	var era_visible := s.visible
	s.visible = true
	var color := Color.WHITE
	var escala := 7.0
	match animo:
		"triste":
			color = Color(0.6, 0.65, 0.85)
			escala = 6.4
		"susto":
			escala = 7.8
		"derrotado":
			color = Color(0.55, 0.55, 0.65)
			escala = 6.2
		"decidido":
			color = Color(0.75, 1.0, 0.8)
			escala = 7.6
	var tw := create_tween().set_parallel(true)
	if not era_visible:
		s.position = destino + Vector2(0, 40)
		s.modulate.a = 0.0
		tw.tween_property(s, "modulate:a", 1.0, 0.35)
	tw.tween_property(s, "scale", Vector2(escala, escala), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "self_modulate", color, 0.25)


func _terminar() -> void:
	if _saliendo:
		return
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void:
		var destino := _siguiente
		get_tree().change_scene_to_file(destino if destino != "" else MENU))
