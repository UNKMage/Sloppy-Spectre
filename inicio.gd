extends Control
## Pantalla de inicio: la portada del juego con solo dos botones.
##   JUGAR -> la primera vez cuenta la historia (introducción) y de ahí pasa al menú de niveles;
##            después va directo al menú de niveles.
##   SALIR -> cierra el juego.
## Se maneja con mouse o teclado (flechas + Enter).

const FONDO := preload("res://Inicio_juego.jpg")
const MENU := "res://menu_principal.tscn"
const VERDE := Color(0.45, 1.0, 0.55)
const ROJO := Color(1.0, 0.55, 0.42)

var _fondo: TextureRect
var _cortina: ColorRect
var _botones: Array[Button] = []
var _saliendo := false


func _ready() -> void:
	get_tree().paused = false
	Opciones.cargar()
	_crear_fondo()
	_crear_particulas()
	_crear_botones()
	_crear_cortina()
	_animar_entrada()
	_botones[0].grab_focus()


# --- Construcción ---

func _crear_fondo() -> void:
	_fondo = TextureRect.new()
	_fondo.texture = FONDO
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# La portada es un dibujo (no pixel art): con filtro suave se ve limpia al escalar.
	_fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.pivot_offset = Vector2(576, 324)
	add_child(_fondo)
	# Zoom lento y suave, igual que en el menú de niveles.
	var tw := create_tween().set_loops()
	tw.tween_property(_fondo, "scale", Vector2(1.05, 1.05), 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fondo, "scale", Vector2.ONE, 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Sombra suave abajo para que los botones resalten sobre el dibujo.
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(0.02, 0.01, 0.08, 0.0), Color(0.02, 0.01, 0.08, 0.6)])
	var tex := GradientTexture2D.new()
	tex.gradient = degradado
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 256
	var sombra := TextureRect.new()
	sombra.texture = tex
	sombra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sombra.offset_top = -150.0
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)


func _crear_particulas() -> void:
	# Motas de espíritu que suben despacio, como en el menú y los niveles.
	for cfg in [[Color(0.75, 0.9, 1.0), 30, 0.45], [VERDE, 16, 0.5]]:
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


func _crear_botones() -> void:
	# Los dos botones en una fila, cada uno cerca de una esquina inferior:
	# JUGAR a la izquierda y SALIR a la derecha (flechas izquierda/derecha para cambiar).
	var tam := Vector2(220, 56)
	var jugar := UIPixel.boton("JUGAR", VERDE, tam, 26)
	jugar.position = Vector2(48, 648 - 48 - tam.y)
	jugar.pressed.connect(_jugar)
	add_child(jugar)
	_botones.append(jugar)

	var salir := UIPixel.boton("SALIR", ROJO, tam, 26)
	salir.position = Vector2(1152 - 48 - tam.x, 648 - 48 - tam.y)
	salir.pressed.connect(_salir)
	add_child(salir)
	_botones.append(salir)

	jugar.focus_neighbor_right = jugar.get_path_to(salir)
	jugar.focus_neighbor_left = jugar.get_path_to(salir)
	salir.focus_neighbor_left = salir.get_path_to(jugar)
	salir.focus_neighbor_right = salir.get_path_to(jugar)
	for b in _botones:
		b.pivot_offset = tam * 0.5
		b.focus_entered.connect(_resaltar.bind(b, true))
		b.focus_exited.connect(_resaltar.bind(b, false))


func _resaltar(b: Button, activo: bool) -> void:
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * (1.07 if activo else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crear_cortina() -> void:
	_cortina = ColorRect.new()
	_cortina.color = Color(0.02, 0.01, 0.06, 1.0)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)


func _animar_entrada() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cortina, "color:a", 0.0, 0.8)
	for i in _botones.size():
		var b := _botones[i]
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.4).set_delay(0.35 + i * 0.12)


# --- Acciones ---

func _jugar() -> void:
	if _saliendo:
		return
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.4)
	tw.tween_callback(func() -> void:
		# La primera vez se cuenta la historia y de ahí al menú de niveles. Una vez vista
		# (se guarda en user://opciones.cfg), JUGAR va directo al menú de niveles.
		if Opciones.visto("intro"):
			get_tree().change_scene_to_file(MENU)
		else:
			Historia.contar(get_tree(), "intro", MENU))


func _salir() -> void:
	if _saliendo:
		return
	_saliendo = true
	Opciones.guardar()
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 0.35)
	tw.tween_callback(get_tree().quit)
