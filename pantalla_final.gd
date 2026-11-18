extends CanvasLayer
## Pantalla de victoria final (al ganar el último nivel): fuegos artificiales, título grande,
## resumen de la partida con calificación de 1 a 3 estrellas y los créditos del equipo.
## Se arma en código, como el menú y la pantalla de fin. Misma llamada que PantallaFin.

const MENU := "res://menu_principal.tscn"
const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")
const FANTASMA := preload("res://Ghost.png")
const ORO := Color(1.0, 0.83, 0.3)
const VERDE := Color(0.45, 1.0, 0.55)
const META := 80.0
## Segundos antes de activar los botones (por si el jugador sigue presionando Espacio).
const RETRASO_BOTONES := 1.4
## Tiempo restante (en segundos) para ganar 3 y 2 estrellas.
const TIEMPO_3_ESTRELLAS := 60.0
const TIEMPO_2_ESTRELLAS := 30.0
const ESTRELLA := [
	"....#....",
	"....#....",
	"...###...",
	"#########",
	".#######.",
	"..#####..",
	"..##.##..",
	".##...##.",
	".#.....#.",
]

var _fuente: Font
var _raiz: Control
var _fantasma: Sprite2D
var _titulo: Label
var _barra: Control
var _estrellas_ctrl: Control
var _pct_mostrado := 0.0
var _pct_final := 0.0
var _estrellas_final := 1
var _estrellas_mostradas := 0
var _tiempo := 0.0
var _botones: Array[Button] = []
var _cortina: ColorRect


func _ready() -> void:
	_fuente = FUENTE_PIXEL.duplicate()
	_fuente.fallbacks = [ThemeDB.fallback_font]


func _process(delta: float) -> void:
	_tiempo += delta
	if _fantasma:
		_fantasma.position.y = 70.0 - absf(sin(_tiempo * 3.5)) * 16.0
		_fantasma.rotation = sin(_tiempo * 2.0) * 0.1
	if _titulo:
		_titulo.modulate = Color.WHITE.lerp(Color(1.0, 1.0, 0.75), 0.5 + 0.5 * sin(_tiempo * 3.0))
	if _barra:
		_barra.queue_redraw()
	if _estrellas_ctrl:
		_estrellas_ctrl.queue_redraw()


## Misma firma que PantallaFin.mostrar(), para que el HUD pueda usar cualquiera de las dos.
func mostrar(_victoria: bool, _motivo: String, suciedad: float, tiempo_restante: float) -> void:
	_pct_final = clampf(suciedad, 0.0, 100.0)
	_estrellas_final = 3 if tiempo_restante >= TIEMPO_3_ESTRELLAS else (2 if tiempo_restante >= TIEMPO_2_ESTRELLAS else 1)

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_crear_ambiente()
	_crear_encabezado()
	_crear_panel(tiempo_restante)
	_crear_botones()
	_crear_pie()
	_cortina = ColorRect.new()
	_cortina.color = Color(1, 1, 1, 0.9)  # destello blanco inicial
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	_animar_entrada()

	for b in _botones:
		b.disabled = true
	await get_tree().create_timer(RETRASO_BOTONES).timeout
	for b in _botones:
		b.disabled = false
	_botones[0].grab_focus()


func _etiqueta(texto: String, tamano: int, color: Color, contorno: int = 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.06))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_ambiente() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.1, 0.0)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)
	create_tween().tween_property(fondo, "color:a", 0.9, 0.7)

	# Viñeta
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.4, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.0, 0.08, 0.8)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
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
	_raiz.add_child(vineta)

	# Fuegos artificiales sin fin detrás de la interfaz.
	var fuegos := FuegosArtificiales.new()
	fuegos.zona = Rect2(90, 40, 970, 330)
	fuegos.intervalo = Vector2(0.25, 0.6)
	_raiz.add_child(fuegos)

	# Confeti dorado que sube desde abajo.
	var p := CPUParticles2D.new()
	p.position = Vector2(576, 670)
	p.amount = 50
	p.lifetime = 5.0
	p.preprocess = 3.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(620, 10)
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2(0, 28)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var r := Gradient.new()
	r.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	r.colors = PackedColorArray([Color(1, 0.9, 0.4, 0.0), Color(1.0, 0.85, 0.35, 0.9), Color(0.5, 1.0, 0.6, 0.0)])
	p.color_ramp = r
	_raiz.add_child(p)


func _crear_encabezado() -> void:
	_fantasma = Sprite2D.new()
	_fantasma.texture = FANTASMA
	_fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fantasma.scale = Vector2(5, 5)
	_fantasma.position = Vector2(576, 70)
	_raiz.add_child(_fantasma)

	var corona := _etiqueta("— ¡JUEGO COMPLETADO! —", 18, VERDE, 6)
	corona.set_anchors_preset(Control.PRESET_TOP_WIDE)
	corona.offset_top = 108.0
	corona.offset_bottom = 134.0
	_raiz.add_child(corona)
	_titulo = _etiqueta("¡LO LOGRASTE!", 84, ORO, 16)
	_titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titulo.offset_top = 132.0
	_titulo.offset_bottom = 236.0
	_titulo.pivot_offset = Vector2(576, 52)
	_raiz.add_child(_titulo)
	var sub := _etiqueta("Spooky reclamó toda la vecindad", 22, Color(1, 1, 1, 0.95), 6)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 238.0
	sub.offset_bottom = 272.0
	_raiz.add_child(sub)


func _crear_panel(tiempo_restante: float) -> void:
	var panel := Panel.new()
	panel.position = Vector2(256, 292)
	panel.size = Vector2(640, 180)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), ORO.darkened(0.1), ORO.darkened(0.6)))
	_raiz.add_child(panel)

	var l1 := _etiqueta("SUCIEDAD FINAL", 16, Color(0.85, 0.88, 1.0, 0.9), 4)
	l1.position = Vector2(24, 14)
	l1.size = Vector2(260, 24)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(l1)
	_barra = Control.new()
	_barra.position = Vector2(24, 46)
	_barra.size = Vector2(592, 28)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar_barra)
	panel.add_child(_barra)

	var l2 := _etiqueta("TIEMPO RESTANTE", 16, Color(0.85, 0.88, 1.0, 0.9), 4)
	l2.position = Vector2(24, 100)
	l2.size = Vector2(260, 24)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(l2)
	var v2 := _etiqueta("%d s" % ceili(tiempo_restante), 24, Color.WHITE, 6)
	v2.position = Vector2(24, 126)
	v2.size = Vector2(260, 32)
	v2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(v2)

	var l3 := _etiqueta("CALIFICACIÓN", 16, Color(0.85, 0.88, 1.0, 0.9), 4)
	l3.position = Vector2(356, 100)
	l3.size = Vector2(260, 24)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(l3)
	_estrellas_ctrl = Control.new()
	_estrellas_ctrl.position = Vector2(616 - 3 * 58, 126)
	_estrellas_ctrl.size = Vector2(3 * 58, 46)
	_estrellas_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estrellas_ctrl.draw.connect(_dibujar_estrellas)
	panel.add_child(_estrellas_ctrl)

	# Entrada del panel y animación: la barra se llena y las estrellas aparecen una a una.
	panel.modulate.a = 0.0
	panel.position.y += 30.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.45).set_delay(0.9)
	tw.tween_property(panel, "position:y", 292.0, 0.45).set_delay(0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_pct_mostrado", _pct_final, 1.2).set_delay(1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _estrellas_final:
		tw.tween_callback(func() -> void: _estrellas_mostradas = i + 1).set_delay(2.0 + i * 0.35)


func _dibujar_barra() -> void:
	var ancho := _barra.size.x
	var alto := _barra.size.y
	var u := 4.0
	_barra.draw_rect(Rect2(0, 0, ancho, alto), ORO.darkened(0.3))
	_barra.draw_rect(Rect2(u, u, ancho - 2.0 * u, alto - 2.0 * u), Color(0.07, 0.06, 0.12))
	var bloques := 37
	var paso := (ancho - 4.0 * u) / bloques
	for i in bloques:
		var x := 2.0 * u + i * paso
		var encendido := (i + 1.0) / bloques * 100.0 <= _pct_mostrado + 0.001
		var c := VERDE if encendido else Color(1, 1, 1, 0.07)
		_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, alto - 4.0 * u), c.darkened(0.2) if encendido else c)
		if encendido:
			_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, 4.0), VERDE.lightened(0.25))
	var x_meta := (ancho - 4.0 * u) * META / 100.0 + 2.0 * u
	_barra.draw_rect(Rect2(x_meta - 2.0, -4.0, 4.0, alto + 8.0), Color.WHITE)
	_barra.draw_string_outline(_fuente, Vector2(0, alto * 0.5 + 8.0), "%d%%" % int(_pct_mostrado), HORIZONTAL_ALIGNMENT_CENTER, ancho, 22, 8, Color(0.03, 0.01, 0.05))
	_barra.draw_string(_fuente, Vector2(0, alto * 0.5 + 8.0), "%d%%" % int(_pct_mostrado), HORIZONTAL_ALIGNMENT_CENTER, ancho, 22, Color.WHITE)


## Tres estrellas de pixel art: las ganadas en dorado, el resto apagadas.
func _dibujar_estrellas() -> void:
	var celda := 5.0
	for e in 3:
		var origen := Vector2(e * 58.0, 0.0)
		var ganada := e < _estrellas_mostradas
		var color := ORO if ganada else Color(1, 1, 1, 0.12)
		var rebote := 0.0
		if ganada and e == _estrellas_mostradas - 1:
			rebote = -absf(sin(_tiempo * 6.0)) * 4.0
		for fila in ESTRELLA.size():
			var linea: String = ESTRELLA[fila]
			for col in linea.length():
				if linea[col] == "#":
					var p := origen + Vector2(col * celda, fila * celda + rebote)
					_estrellas_ctrl.draw_rect(Rect2(p + Vector2(2, 2), Vector2(celda, celda)), Color(0, 0, 0, 0.5))
		for fila in ESTRELLA.size():
			var linea: String = ESTRELLA[fila]
			for col in linea.length():
				if linea[col] == "#":
					var p := origen + Vector2(col * celda, fila * celda + rebote)
					var c := color
					if ganada and fila < 3:
						c = ORO.lightened(0.3)
					_estrellas_ctrl.draw_rect(Rect2(p, Vector2(celda, celda)), c)


func _crear_botones() -> void:
	var defs := [
		["Menú principal", VERDE, _ir_al_menu],
		["Repetir nivel", Color(0.65, 0.7, 1.0), _reintentar],
	]
	for i in defs.size():
		var d: Array = defs[i]
		var color: Color = d[1]
		var b := Button.new()
		b.text = d[0]
		b.add_theme_font_override("font", _fuente)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", color)
		b.add_theme_color_override("font_focus_color", color)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		b.add_theme_stylebox_override("normal", PixelCaja.nueva(Color(0.07, 0.06, 0.13), color.darkened(0.45)))
		b.add_theme_stylebox_override("hover", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
		b.add_theme_stylebox_override("focus", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
		b.add_theme_stylebox_override("pressed", PixelCaja.nueva(Color(0.18, 0.16, 0.3), Color.WHITE, color, true))
		b.add_theme_stylebox_override("disabled", PixelCaja.nueva(Color(0.06, 0.05, 0.1), Color(0.3, 0.3, 0.4)))
		b.size = Vector2(250, 58)
		b.position = Vector2(312 + i * 278, 490)
		b.pivot_offset = b.size * 0.5
		b.pressed.connect(d[2])
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				b.grab_focus())
		b.focus_entered.connect(func() -> void: _crecer(b, 1.07))
		b.focus_exited.connect(func() -> void: _crecer(b, 1.0))
		_raiz.add_child(b)
		_botones.append(b)
		b.modulate.a = 0.0
		create_tween().tween_property(b, "modulate:a", 1.0, 0.4).set_delay(1.6 + i * 0.12)


func _crecer(b: Button, escala: float) -> void:
	create_tween().tween_property(b, "scale", Vector2.ONE * escala, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crear_pie() -> void:
	var cred := _etiqueta("Un juego de  Sofia  ·  Emiliano  ·  Ángel  ·  Karol", 15, Color(1.0, 0.9, 0.55, 0.9), 5)
	cred.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cred.offset_top = -64.0
	cred.offset_bottom = -40.0
	_raiz.add_child(cred)
	var pie := _etiqueta("Enter = elegir      Esc = menú principal", 13, Color(1, 1, 1, 0.5), 4)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -34.0
	pie.offset_bottom = -12.0
	_raiz.add_child(pie)


func _animar_entrada() -> void:
	# Destello blanco que se apaga y el título que cae de golpe.
	create_tween().tween_property(_cortina, "color:a", 0.0, 0.6)
	_titulo.scale = Vector2(2.6, 2.6)
	_titulo.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_titulo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tw.tween_property(_titulo, "modulate:a", 1.0, 0.25).set_delay(0.2)


func _reintentar() -> void:
	_salir(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())


func _ir_al_menu() -> void:
	_salir(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU))


func _salir(accion: Callable) -> void:
	for b in _botones:
		b.disabled = true
	_cortina.color = Color(0.02, 0.01, 0.06, 0.0)
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.3)
	tw.tween_callback(accion)
