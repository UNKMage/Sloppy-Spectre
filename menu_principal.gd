extends Control
## Menú principal: elige un nivel con tarjetas (mouse o teclado: flechas + Enter).
## Toda la interfaz se arma aquí en código para poder ajustarla sin tocar la escena.

const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")
const FANTASMA := preload("res://Ghost.png")

## Una tarjeta por nivel: nombre, dificultad (1-3 puntos), escena, imagen de fondo y color de acento.
const NIVELES := [
	{"titulo": "NIVEL 1", "dificultad": "Fácil", "puntos": 1, "escena": "res://main.tscn",
		"fondo": "res://fondonivel1.jpg", "color": Color(0.45, 1.0, 0.55)},
	{"titulo": "NIVEL 2", "dificultad": "Intermedio", "puntos": 2, "escena": "res://nivel_2.tscn",
		"fondo": "res://fondonivel2.jpg", "color": Color(0.6, 0.72, 1.0)},
	{"titulo": "NIVEL 3", "dificultad": "Difícil", "puntos": 3, "escena": "res://nivel_3.tscn",
		"fondo": "res://fondonivel3.jpg", "color": Color(1.0, 0.55, 0.42)},
]
const TARJETA := Vector2(270, 290)

var _tarjetas: Array[Button] = []
var _fantasma: Sprite2D
var _titulo: Label
var _cortina: ColorRect
var _entrando := false
var _fuente: Font


func _ready() -> void:
	# Si venimos de un Game Over, el juego estaba pausado: sin esto los botones no responderían.
	get_tree().paused = false
	Opciones.cargar()
	# Al abrir el juego siempre se cuenta la historia antes del menú.
	if not Historia.inicio_mostrado:
		Historia.inicio_mostrado = true
		Historia.contar.call_deferred(get_tree(), "intro", "res://menu_principal.tscn")
		return
	# La fuente pixel no trae acentos: se copia y se le da la fuente normal como respaldo.
	_fuente = FUENTE_PIXEL.duplicate()
	_fuente.fallbacks = [ThemeDB.fallback_font]
	_crear_fondo()
	_crear_particulas()
	_crear_encabezado()
	_crear_tarjetas()
	_crear_pie()
	_crear_boton_opciones()
	_crear_boton_creditos()
	_crear_cortina()
	_animar_entrada()
	# Con el foco en la primera tarjeta también se puede jugar con teclado.
	_tarjetas[0].grab_focus()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _fantasma:
		_fantasma.position.y = 100.0 + sin(t * 2.0) * 7.0
		_fantasma.rotation = sin(t * 1.3) * 0.06
	if _titulo:
		_titulo.modulate = Color.WHITE.lerp(Color(0.8, 1.0, 0.85), 0.5 + 0.5 * sin(t * 1.6))


# --- Construcción de la interfaz ---

func _crear_fondo() -> void:
	var fondo := TextureRect.new()
	fondo.texture = load("res://fondonivel2.jpg")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	# Zoom lento y suave, para que el fondo no se sienta estático.
	fondo.pivot_offset = Vector2(576, 324)
	var tw := create_tween().set_loops()
	tw.tween_property(fondo, "scale", Vector2(1.08, 1.08), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(fondo, "scale", Vector2.ONE, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var oscuro := ColorRect.new()
	oscuro.color = Color(0.04, 0.03, 0.1, 0.62)
	oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oscuro)

	# Viñeta: bordes más oscuros para centrar la mirada.
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.45, 1.0])
	degradado.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.7)])
	var tex := GradientTexture2D.new()
	tex.gradient = degradado
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var vineta := TextureRect.new()
	vineta.texture = tex
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vineta)


func _crear_particulas() -> void:
	# Motas de espíritu que suben despacio, como en los niveles.
	for cfg in [[Color(0.75, 0.9, 1.0), 40, 0.5], [Color(0.45, 1.0, 0.55), 18, 0.55]]:
		var p := CPUParticles2D.new()
		p.position = Vector2(576, 340)
		p.amount = cfg[1]
		p.lifetime = 9.0
		p.preprocess = 9.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(600, 340)
		p.direction = Vector2(0, -1)
		p.spread = 30.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 22.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.0
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		var c: Color = cfg[0]
		g.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, cfg[2]), Color(c.r, c.g, c.b, 0.0)])
		p.color_ramp = g
		add_child(p)


func _etiqueta(texto: String, tamano: int, color: Color, contorno: int = 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _crear_encabezado() -> void:
	_fantasma = Sprite2D.new()
	_fantasma.texture = FANTASMA
	_fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fantasma.scale = Vector2(4, 4)
	_fantasma.position = Vector2(250, 100)
	add_child(_fantasma)

	_titulo = _etiqueta("SLOPPY SPECTRE", 64, Color(0.45, 1.0, 0.55), 12)
	_titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titulo.offset_top = 52.0
	_titulo.offset_left = 130.0
	_titulo.offset_bottom = 140.0
	add_child(_titulo)

	var sub := _etiqueta("Ensucia la vecindad antes de que llegue el Limpiador", 17, Color(0.82, 0.86, 1.0, 0.85), 5)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 142.0
	sub.offset_bottom = 170.0
	add_child(sub)

	var elige := _etiqueta("— ELIGE UN NIVEL —", 22, Color(1, 1, 1, 0.95), 6)
	elige.set_anchors_preset(Control.PRESET_TOP_WIDE)
	elige.offset_top = 196.0
	elige.offset_bottom = 230.0
	add_child(elige)


func _crear_tarjetas() -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 30)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.position = Vector2(576 - (TARJETA.x * 3 + 60) * 0.5, 258)
	add_child(fila)
	for datos in NIVELES:
		var boton := _crear_tarjeta(datos)
		fila.add_child(boton)
		_tarjetas.append(boton)



func _crear_tarjeta(datos: Dictionary) -> Button:
	var color: Color = datos["color"]
	var b := Button.new()
	b.custom_minimum_size = TARJETA
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", PixelCaja.nueva(Color(0.07, 0.06, 0.13), color.darkened(0.5), Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", PixelCaja.nueva(Color(0.11, 0.1, 0.2), color, color.darkened(0.55), true))
	b.add_theme_stylebox_override("focus", PixelCaja.nueva(Color(0.11, 0.1, 0.2), color, color.darkened(0.55), true))
	b.add_theme_stylebox_override("pressed", PixelCaja.nueva(Color(0.16, 0.14, 0.26), Color.WHITE, color, true))

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 12.0
	caja.offset_top = 12.0
	caja.offset_right = -12.0
	caja.offset_bottom = -12.0
	caja.add_theme_constant_override("separation", 8)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caja)

	var miniatura := TextureRect.new()
	miniatura.texture = load(datos["fondo"])
	miniatura.custom_minimum_size = Vector2(0, 140)
	miniatura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	miniatura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	miniatura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	miniatura.modulate = Color(0.62, 0.62, 0.7)
	miniatura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	miniatura.clip_contents = true
	caja.add_child(miniatura)

	caja.add_child(_etiqueta(datos["titulo"], 26, color, 6))
	caja.add_child(_etiqueta(datos["dificultad"], 18, Color(0.88, 0.9, 1.0), 4))

	# Dificultad: tres cuadritos, encendidos según el nivel.
	var puntos := HBoxContainer.new()
	puntos.alignment = BoxContainer.ALIGNMENT_CENTER
	puntos.add_theme_constant_override("separation", 6)
	puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var punto := ColorRect.new()
		punto.custom_minimum_size = Vector2(16, 16)
		punto.color = color if i < datos["puntos"] else Color(1, 1, 1, 0.15)
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puntos.add_child(punto)
	caja.add_child(puntos)

	b.pivot_offset = TARJETA * 0.5
	b.pressed.connect(_abrir_nivel.bind(datos["escena"]))
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_resaltar.bind(b, miniatura, true))
	b.focus_exited.connect(_resaltar.bind(b, miniatura, false))
	return b


func _resaltar(b: Button, miniatura: TextureRect, activo: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE * (1.07 if activo else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(miniatura, "modulate", Color.WHITE if activo else Color(0.62, 0.62, 0.7), 0.14)


func _crear_pie() -> void:
	var pie := _etiqueta("WASD / flechas: moverse     Espacio: ensuciar     Mouse: apuntar tu luz", 14, Color(1, 1, 1, 0.7), 5)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -64.0
	pie.offset_bottom = -40.0
	add_child(pie)
	var esc := _etiqueta("Esc dentro de un nivel = pausa", 12, Color(1, 1, 1, 0.45), 4)
	esc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	esc.offset_top = -36.0
	esc.offset_bottom = -14.0
	add_child(esc)


func _crear_cortina() -> void:
	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.01, 0.06, 1.0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)


func _animar_entrada() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cortina, "color:a", 0.0, 0.7)
	for i in _tarjetas.size():
		var t := _tarjetas[i]
		var y_final := t.position.y
		t.position.y = y_final + 40.0
		t.modulate.a = 0.0
		tw.tween_property(t, "position:y", y_final, 0.5).set_delay(0.15 + i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "modulate:a", 1.0, 0.4).set_delay(0.15 + i * 0.12)


func _abrir_nivel(escena: String) -> void:
	if _entrando:
		return
	_entrando = true
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		# La primera vez (o tras "Repetir tutorial") el nivel 1 va precedido del tutorial.
		if escena == "res://main.tscn" and not Opciones.visto("tutorial_basico"):
			get_tree().change_scene_to_file("res://tutorial_nivel.tscn")
		else:
			get_tree().change_scene_to_file(escena))


# --- Opciones (volumen y pantalla completa) ---

var _panel_opciones: PanelOpciones


func _crear_boton_opciones() -> void:
	var b := UIPixel.boton("OPCIONES", Color(0.56, 0.92, 1.0), Vector2(170, 46), 16)
	b.position = Vector2(962, 584)
	b.pressed.connect(_abrir_opciones)
	add_child(b)


func _abrir_opciones() -> void:
	if _panel_opciones != null and is_instance_valid(_panel_opciones):
		return
	_panel_opciones = PanelOpciones.new()
	add_child(_panel_opciones)  # el último hijo se dibuja encima de todo
	_panel_opciones.volver.connect(func() -> void:
		_panel_opciones.queue_free()
		_tarjetas[0].grab_focus())
	_panel_opciones.abrir()


func _crear_boton_creditos() -> void:
	var b := UIPixel.boton("CRÉDITOS", Color(1.0, 0.83, 0.3), Vector2(170, 46), 16)
	b.position = Vector2(20, 584)
	b.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://creditos.tscn"))
	add_child(b)
