extends CanvasLayer
## Pantalla de fin de partida. Sirve para VICTORIA y para GAME OVER:
## solo cambian el título, los colores, las partículas y los textos (los pone mostrar()).
## Toda la interfaz se arma aquí en código, igual que el menú principal.

const MENU := "res://menu_principal.tscn"
const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")
const FANTASMA := preload("res://Ghost.png")
const COLOR_VICTORIA := Color(0.45, 1.0, 0.55)
const COLOR_DERROTA := Color(1.0, 0.35, 0.38)
## Porcentaje de suciedad que hay que alcanzar para ganar (se dibuja como marca en la barra).
const META := 100.0
## Segundos que los botones esperan antes de activarse. Si el jugador está presionando
## Espacio (para manchar) justo cuando termina la partida, no debe "pulsar" un botón sin querer.
const RETRASO_BOTONES := 0.8

var _fuente: Font
var _victoria := false
var _color := COLOR_DERROTA
var _raiz: Control
var _fantasma: Sprite2D
var _titulo: Label
var _barra: Control
var _pct_mostrado := 0.0
var _pct_final := 0.0
var _tiempo := 0.0
var _sacudida := 0.0
var _botones: Array[Button] = []
var _cortina: ColorRect


func _ready() -> void:
	_fuente = FUENTE_PIXEL.duplicate()
	_fuente.fallbacks = [ThemeDB.fallback_font]


func _process(delta: float) -> void:
	_tiempo += delta
	if _fantasma:
		if _victoria:
			_fantasma.position.y = 74.0 + absf(sin(_tiempo * 4.0)) * -14.0
		else:
			_fantasma.position.y = 74.0 + sin(_tiempo * 1.6) * 5.0
			_fantasma.rotation = sin(_tiempo * 1.1) * 0.12
	if _titulo:
		if _victoria:
			_titulo.modulate = Color.WHITE.lerp(Color(1.0, 1.0, 0.8), 0.5 + 0.5 * sin(_tiempo * 3.0))
		else:
			# Parpadeo "glitch" de vez en cuando.
			var glitch := fmod(_tiempo, 2.4) < 0.12
			_titulo.modulate = Color(1.0, 0.8, 0.8) if glitch else Color.WHITE
			_titulo.position.x = _titulo_x + (randf_range(-5.0, 5.0) if glitch else 0.0)
	if _sacudida > 0.0 and _raiz:
		_sacudida -= delta
		_raiz.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * clampf(_sacudida / 0.45, 0.0, 1.0)
		if _sacudida <= 0.0:
			_raiz.position = Vector2.ZERO
	if _barra:
		_barra.queue_redraw()


var _titulo_x := 0.0


## Muestra la pantalla. victoria = true -> "¡VICTORIA!", false -> "GAME OVER".
func mostrar(victoria: bool, motivo: String, suciedad: float, tiempo_restante: float) -> void:
	_victoria = victoria
	_color = COLOR_VICTORIA if victoria else COLOR_DERROTA
	_pct_final = clampf(suciedad, 0.0, 100.0)

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_crear_ambiente()
	_crear_particulas()
	_crear_encabezado(motivo)
	_crear_panel(tiempo_restante)
	_crear_botones()
	_crear_pie()
	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	_animar_entrada()

	for b in _botones:
		b.disabled = true
	# create_timer sigue corriendo con el juego en pausa (por defecto ignora la pausa).
	await get_tree().create_timer(RETRASO_BOTONES).timeout
	for b in _botones:
		b.disabled = false
	_botones[0].grab_focus()  # así también se puede usar con teclado (flechas + Enter)


# --- Construcción de la interfaz ---

func _etiqueta(texto: String, tamano: int, color: Color, contorno: int = 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.05))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _crear_ambiente() -> void:
	var tinte := ColorRect.new()
	tinte.color = Color(_color.r * 0.1, _color.g * 0.08, _color.b * 0.1, 0.0)
	tinte.set_anchors_preset(Control.PRESET_FULL_RECT)
	tinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(tinte)
	create_tween().tween_property(tinte, "color:a", 0.86, 0.6)

	# Viñeta: bordes más oscuros (en derrota, con un toque rojizo).
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.35, 1.0])
	var borde := Color(0.2, 0.0, 0.02, 0.85) if not _victoria else Color(0.0, 0.1, 0.04, 0.8)
	degradado.colors = PackedColorArray([Color(0, 0, 0, 0), borde])
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
	_raiz.add_child(vineta)


func _crear_particulas() -> void:
	var p := CPUParticles2D.new()
	p.amount = 60 if _victoria else 45
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	if _victoria:
		# Confeti y chispas que suben desde abajo.
		p.position = Vector2(576, 680)
		p.emission_rect_extents = Vector2(620, 10)
		p.direction = Vector2(0, -1)
		p.spread = 25.0
		p.gravity = Vector2(0, 30)
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 230.0
		p.color_ramp = g
		g.colors = PackedColorArray([Color(1, 1, 0.6, 0.0), Color(0.55, 1.0, 0.6, 0.95), Color(1.0, 0.9, 0.4, 0.0)])
	else:
		# Cenizas y brasas que caen despacio.
		p.position = Vector2(576, -20)
		p.emission_rect_extents = Vector2(620, 10)
		p.direction = Vector2(0, 1)
		p.spread = 20.0
		p.gravity = Vector2(0, 8)
		p.initial_velocity_min = 15.0
		p.initial_velocity_max = 45.0
		p.color_ramp = g
		g.colors = PackedColorArray([Color(1.0, 0.4, 0.3, 0.0), Color(0.9, 0.35, 0.35, 0.7), Color(0.4, 0.4, 0.5, 0.0)])
	_raiz.add_child(p)


func _crear_encabezado(motivo: String) -> void:
	# Halo y fantasma. En derrota está apagado y tristón; en victoria, brillante y saltando.
	_fantasma = Sprite2D.new()
	_fantasma.texture = FANTASMA
	_fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fantasma.scale = Vector2(4, 4)
	_fantasma.position = Vector2(576, 74)
	_fantasma.modulate = Color.WHITE if _victoria else Color(0.55, 0.55, 0.7, 0.85)
	_raiz.add_child(_fantasma)

	_titulo = _etiqueta("¡VICTORIA!" if _victoria else "GAME OVER", 88, _color, 16)
	_titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titulo.offset_top = 118.0
	_titulo.offset_bottom = 224.0
	_titulo.pivot_offset = Vector2(576, 53)
	_raiz.add_child(_titulo)
	_titulo_x = 0.0

	var m := _etiqueta(motivo, 22, Color(1, 1, 1, 0.92), 6)
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	m.offset_top = 226.0
	m.offset_bottom = 262.0
	_raiz.add_child(m)
	m.modulate.a = 0.0
	create_tween().tween_property(m, "modulate:a", 1.0, 0.5).set_delay(0.5)


func _crear_panel(tiempo_restante: float) -> void:
	var panel := Panel.new()
	panel.position = Vector2(296, 284)
	panel.size = Vector2(560, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), _color.darkened(0.15), _color.darkened(0.6)))
	_raiz.add_child(panel)

	var titulo_barra := _etiqueta("SUCIEDAD FINAL", 16, Color(0.85, 0.88, 1.0, 0.9), 4)
	titulo_barra.position = Vector2(24, 16)
	titulo_barra.size = Vector2(260, 24)
	titulo_barra.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(titulo_barra)

	# Barra con la marca de la meta.
	_barra = Control.new()
	_barra.position = Vector2(24, 50)
	_barra.size = Vector2(512, 30)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar_barra)
	panel.add_child(_barra)

	var tiempo := _etiqueta("TIEMPO RESTANTE", 16, Color(0.85, 0.88, 1.0, 0.9), 4)
	tiempo.position = Vector2(24, 106)
	tiempo.size = Vector2(260, 24)
	tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(tiempo)
	var valor := _etiqueta("%d s" % ceili(tiempo_restante), 24, Color.WHITE, 6)
	valor.position = Vector2(300, 102)
	valor.size = Vector2(236, 32)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(valor)

	# Entrada: el panel sube y la barra se llena contando.
	panel.modulate.a = 0.0
	panel.position.y += 30.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.45).set_delay(0.6)
	tw.tween_property(panel, "position:y", 284.0, 0.45).set_delay(0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_pct_mostrado", _pct_final, 1.2).set_delay(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Barra de pixel art: marco duro y bloques que se encienden uno a uno (como una barra retro).
func _dibujar_barra() -> void:
	var ancho := _barra.size.x
	var alto := _barra.size.y
	var u := 4.0
	var marco := _color.darkened(0.25)
	_barra.draw_rect(Rect2(0, 0, ancho, alto), marco)
	_barra.draw_rect(Rect2(u, u, ancho - 2.0 * u, alto - 2.0 * u), Color(0.07, 0.06, 0.12))
	var bloques := 32
	var interior := ancho - 4.0 * u
	var paso := interior / bloques
	var ok := _pct_mostrado >= META
	var col := COLOR_VICTORIA if ok else _color
	for i in bloques:
		var x := 2.0 * u + i * paso
		var encendido := (i + 1.0) / bloques * 100.0 <= _pct_mostrado + 0.001
		var c := col if encendido else Color(1, 1, 1, 0.07)
		_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, alto - 4.0 * u), c.darkened(0.2) if encendido else c)
		if encendido:
			_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, 4.0), col.lightened(0.25))
	# Marca de la meta
	var x_meta := (ancho - 4.0 * u) * META / 100.0 + 2.0 * u
	_barra.draw_rect(Rect2(x_meta - 2.0, -6.0, 4.0, alto + 12.0), Color.WHITE)
	_barra.draw_string(_fuente, Vector2(x_meta - 100.0, -10.0), "META %d%%" % int(META), HORIZONTAL_ALIGNMENT_RIGHT, 100.0, 12, Color(1, 1, 1, 0.85))
	_barra.draw_string_outline(_fuente, Vector2(0, alto * 0.5 + 8.0), "%d%%" % int(_pct_mostrado), HORIZONTAL_ALIGNMENT_CENTER, ancho, 22, 8, Color(0.03, 0.01, 0.05))
	_barra.draw_string(_fuente, Vector2(0, alto * 0.5 + 8.0), "%d%%" % int(_pct_mostrado), HORIZONTAL_ALIGNMENT_CENTER, ancho, 22, Color.WHITE)


func _crear_botones() -> void:
	var defs := [
		["Jugar de nuevo", COLOR_VICTORIA, _reintentar],
		["Menú principal", Color(0.65, 0.7, 1.0), _ir_al_menu],
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
		b.add_theme_stylebox_override("normal", PixelCaja.nueva(Color(0.07, 0.06, 0.13), color.darkened(0.45), Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
		b.add_theme_stylebox_override("focus", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
		b.add_theme_stylebox_override("pressed", PixelCaja.nueva(Color(0.18, 0.16, 0.3), Color.WHITE, color, true))
		b.add_theme_stylebox_override("disabled", PixelCaja.nueva(Color(0.06, 0.05, 0.1), Color(0.3, 0.3, 0.4)))
		b.size = Vector2(250, 58)
		b.position = Vector2(312 + i * 278, 468)
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
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.4).set_delay(1.1 + i * 0.12)


func _crecer(b: Button, escala: float) -> void:
	create_tween().tween_property(b, "scale", Vector2.ONE * escala, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crear_pie() -> void:
	var pie := _etiqueta("Enter = elegir      Esc = menú principal", 13, Color(1, 1, 1, 0.5), 4)
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -44.0
	pie.offset_bottom = -20.0
	_raiz.add_child(pie)


func _animar_entrada() -> void:
	# El título "cae" de golpe: grande y transparente -> tamaño normal, y en derrota la pantalla tiembla.
	_titulo.scale = Vector2(2.6, 2.6)
	_titulo.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_titulo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_titulo, "modulate:a", 1.0, 0.25)
	if not _victoria:
		tw.tween_callback(func() -> void: _sacudida = 0.45).set_delay(0.3)


func _reintentar() -> void:
	_salir(func() -> void:
		get_tree().paused = false  # el HUD pausó el juego al terminar; hay que despausar
		get_tree().reload_current_scene())


func _ir_al_menu() -> void:
	_salir(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU))


func _salir(accion: Callable) -> void:
	for b in _botones:
		b.disabled = true
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.3)
	tw.tween_callback(accion)
