class_name GestorBoosts
extends Node
## Boosts del nivel. Hace aparecer orbes en lugares al azar del mapa, aplica sus efectos a Spooky
## y muestra en pantalla cuánto tiempo le queda a cada uno:
##   - Ectoplasma infinito (verde): manchar no gasta el tanque durante 8 s.
##   - Inmunidad (azul): los Limpiadores no lo ven ni lo aturden durante 10 s.
## Se agrega al nivel y se elige qué boosts hay con las casillas de abajo.

const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")

## Aviso de que apareció un orbe (lo usa el tutorial para explicarlo la primera vez).
signal orbe_aparecio(tipo: int, posicion: Vector2)
const NOMBRES := {
	Boost.Tipo.ECTOPLASMA: "ECTOPLASMA INFINITO",
	Boost.Tipo.INMUNIDAD: "INMUNIDAD",
}

@export_group("Boosts de este nivel")
@export var ectoplasma_infinito: bool = true
@export var inmunidad: bool = false
@export_group("Duración (segundos)")
@export var duracion_ectoplasma: float = 8.0
@export var duracion_inmunidad: float = 10.0
@export_group("Aparición")
## Zona del mapa donde pueden aparecer los orbes.
@export var zona: Rect2 = Rect2(90, 120, 972, 450)
## Espera antes del primer orbe (mínimo, máximo).
@export var primera_espera: Vector2 = Vector2(4.0, 8.0)
## Espera entre un orbe y el siguiente del mismo tipo (mínimo, máximo).
@export var espera_entre_orbes: Vector2 = Vector2(9.0, 15.0)
## Segundos que un orbe espera en el mapa antes de desaparecer.
@export var vida_orbe: float = 15.0
## Capas físicas que bloquean un orbe (paredes).
@export_flags_2d_physics var mascara_paredes: int = 4

var _fuente: Font
var _ghost: Node2D
var _espera: Dictionary = {}     # tipo -> segundos para el próximo orbe
var _orbe: Dictionary = {}       # tipo -> Boost actual (o null)
var _restante: Dictionary = {}   # tipo -> segundos de efecto que quedan
var _duracion: Dictionary = {}
var _insignias: Dictionary = {}  # tipo -> Panel del HUD
var _barras: Dictionary = {}     # tipo -> Control de la barra
var _aura: Node2D
var _t: float = 0.0


func _ready() -> void:
	_fuente = FUENTE_PIXEL.duplicate()
	_fuente.fallbacks = [ThemeDB.fallback_font]
	_duracion = {Boost.Tipo.ECTOPLASMA: duracion_ectoplasma, Boost.Tipo.INMUNIDAD: duracion_inmunidad}
	var activos: Array = []
	if ectoplasma_infinito:
		activos.append(Boost.Tipo.ECTOPLASMA)
	if inmunidad:
		activos.append(Boost.Tipo.INMUNIDAD)
	for tipo in activos:
		_espera[tipo] = randf_range(primera_espera.x, primera_espera.y) + activos.find(tipo) * 3.0
		_orbe[tipo] = null
		_restante[tipo] = 0.0
	await get_tree().physics_frame
	_ghost = get_tree().get_first_node_in_group("jugador") as Node2D
	_crear_hud(activos)
	_crear_aura()


func _process(delta: float) -> void:
	_t += delta
	if _ghost == null:
		return
	for tipo in _espera.keys():
		# Efecto activo: cuenta atrás.
		if _restante[tipo] > 0.0:
			_restante[tipo] -= delta
			if _restante[tipo] <= 0.0:
				_terminar(tipo)
		# Aparición del siguiente orbe.
		if _orbe[tipo] == null:
			_espera[tipo] -= delta
			if _espera[tipo] <= 0.0:
				_aparecer(tipo)
	_actualizar_hud()
	if _aura:
		_aura.queue_redraw()


# --- Aparición de orbes ---

func _aparecer(tipo: int) -> void:
	var pos: Variant = _buscar_posicion()
	if pos == null:
		_espera[tipo] = 1.0  # no hubo lugar libre, reintenta pronto
		return
	var b := Boost.new()
	b.tipo = tipo
	b.vida = vida_orbe
	b.position = pos
	b.recogido.connect(_on_recogido)
	b.expirado.connect(_on_expirado)
	get_parent().add_child(b)
	_orbe[tipo] = b
	orbe_aparecio.emit(tipo, b.position)


## Busca un punto al azar: con suelo, lejos de las paredes y a distancia de Spooky.
func _buscar_posicion() -> Variant:
	var suelo := get_tree().get_first_node_in_group("suelo")
	var capa := suelo.get_node_or_null("CapaSuelo") as TileMapLayer if suelo else null
	# El nodo raíz del nivel 1 es un Node (no Node2D): el espacio físico se pide a Spooky.
	var espacio := _ghost.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = 34.0
	for intento in 60:
		var p := Vector2(randf_range(zona.position.x, zona.end.x), randf_range(zona.position.y, zona.end.y))
		if _ghost and p.distance_to(_ghost.global_position) < 130.0:
			continue
		var portal := get_parent().get_node_or_null("Portal") as Node2D
		if portal and p.distance_to(portal.global_position) < 90.0:
			continue
		if capa and capa.get_cell_source_id(capa.local_to_map(capa.to_local(p))) == -1:
			continue
		var consulta := PhysicsShapeQueryParameters2D.new()
		consulta.shape = forma
		consulta.transform = Transform2D(0.0, p)
		consulta.collision_mask = mascara_paredes
		consulta.collide_with_areas = false
		if not espacio.intersect_shape(consulta, 1).is_empty():
			continue
		# Tampoco encima de otro orbe.
		var ocupado := false
		for otro in _orbe.values():
			if otro != null and is_instance_valid(otro) and (otro as Node2D).position.distance_to(p) < 80.0:
				ocupado = true
		if not ocupado:
			return p
	return null


func _on_expirado(tipo: int) -> void:
	_orbe[tipo] = null
	_espera[tipo] = randf_range(espera_entre_orbes.x * 0.5, espera_entre_orbes.y * 0.5)


func _on_recogido(tipo: int, posicion: Vector2) -> void:
	_orbe[tipo] = null
	_espera[tipo] = _duracion[tipo] * 0.5 + randf_range(espera_entre_orbes.x, espera_entre_orbes.y)
	_restante[tipo] = _duracion[tipo]
	_aplicar(tipo, true)
	_destello(tipo, posicion)
	GameFeel.sacudir(get_tree(), 5.0, 0.2)
	GameFeel.destello(get_tree(), Color(0.7, 1.0, 0.8, 0.25) if tipo == Boost.Tipo.ECTOPLASMA else Color(0.6, 0.85, 1.0, 0.25), 0.3)


# --- Efectos sobre Spooky ---

func _aplicar(tipo: int, activo: bool) -> void:
	if _ghost == null:
		return
	if tipo == Boost.Tipo.ECTOPLASMA:
		_ghost.set("ectoplasma_infinito", activo)
	else:
		_ghost.set("boost_inmunidad", activo)


func _terminar(tipo: int) -> void:
	_restante[tipo] = 0.0
	_aplicar(tipo, false)


## Chispas de colores y un texto que sube al recoger el orbe.
func _destello(tipo: int, posicion: Vector2) -> void:
	var col: Dictionary = Boost.COLORES[tipo]
	var luz: Color = col["luz"]
	var cuerpo: Color = col["cuerpo"]
	var p := CPUParticles2D.new()
	p.global_position = posicion
	p.z_index = 8
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 80)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(luz.r, luz.g, luz.b, 1.0), Color(cuerpo.r, cuerpo.g, cuerpo.b, 0.9), Color(cuerpo.r, cuerpo.g, cuerpo.b, 0.0)])
	p.color_ramp = g
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

	var l := Label.new()
	l.text = "¡%s!" % NOMBRES[tipo]
	l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", luz)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(360, 30)
	l.position = posicion - Vector2(180, 50)
	l.z_index = 9
	get_parent().add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


# --- Interfaz: insignias con cuenta atrás y aura alrededor de Spooky ---

func _crear_hud(activos: Array) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 4
	add_child(capa)
	var x := 16.0
	for tipo in activos:
		var panel := Panel.new()
		panel.position = Vector2(x, 590.0)
		panel.size = Vector2(250, 46)
		panel.visible = false
		var col: Dictionary = Boost.COLORES[tipo]
		panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), col["cuerpo"], (col["oscuro"] as Color).darkened(0.2)))
		capa.add_child(panel)
		var icono := Control.new()
		icono.position = Vector2(10, 9)
		icono.size = Vector2(30, 30)
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tipo_c: int = tipo
		icono.draw.connect(func() -> void: Boost.dibujar_icono(icono, tipo_c, Vector2.ZERO, 2.0))
		panel.add_child(icono)
		var nombre := Label.new()
		nombre.text = NOMBRES[tipo]
		nombre.add_theme_font_override("font", _fuente)
		nombre.add_theme_font_size_override("font_size", 13)
		nombre.add_theme_color_override("font_color", Color.WHITE)
		nombre.position = Vector2(48, 6)
		nombre.size = Vector2(196, 18)
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(nombre)
		var barra := Control.new()
		barra.position = Vector2(48, 26)
		barra.size = Vector2(190, 10)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.draw.connect(func() -> void: _dibujar_barra(barra, tipo_c))
		panel.add_child(barra)
		_insignias[tipo] = panel
		_barras[tipo] = barra
		x += 262.0


func _dibujar_barra(barra: Control, tipo: int) -> void:
	var col: Dictionary = Boost.COLORES[tipo]
	var frac := clampf(_restante[tipo] / _duracion[tipo], 0.0, 1.0)
	barra.draw_rect(Rect2(Vector2.ZERO, barra.size), Color(0.1, 0.09, 0.16))
	var bloques := 19
	var ancho := barra.size.x / bloques
	for i in bloques:
		if (i + 1.0) / bloques <= frac + 0.001:
			barra.draw_rect(Rect2(i * ancho, 0.0, ancho - 1.0, barra.size.y), col["cuerpo"])
			barra.draw_rect(Rect2(i * ancho, 0.0, ancho - 1.0, 3.0), col["luz"])


func _actualizar_hud() -> void:
	for tipo in _insignias.keys():
		var panel: Panel = _insignias[tipo]
		var activo: bool = _restante[tipo] > 0.0
		panel.visible = activo
		if activo:
			# Parpadea cuando quedan 3 segundos o menos.
			panel.modulate.a = 0.45 if (_restante[tipo] < 3.0 and int(_t * 6.0) % 2 == 0) else 1.0
			(_barras[tipo] as Control).queue_redraw()


func _crear_aura() -> void:
	if _ghost == null:
		return
	_aura = Node2D.new()
	_aura.show_behind_parent = true
	_aura.z_index = -1
	_aura.draw.connect(_dibujar_aura)
	_ghost.add_child(_aura)


## Aro de cuadritos girando alrededor de Spooky mientras haya un boost activo.
func _dibujar_aura() -> void:
	var colores: Array[Color] = []
	if _restante.get(Boost.Tipo.ECTOPLASMA, 0.0) > 0.0:
		colores.append(Boost.COLORES[Boost.Tipo.ECTOPLASMA]["cuerpo"])
	if _restante.get(Boost.Tipo.INMUNIDAD, 0.0) > 0.0:
		colores.append(Boost.COLORES[Boost.Tipo.INMUNIDAD]["cuerpo"])
	if colores.is_empty():
		return
	var n := 20
	for i in n:
		var a := TAU * i / n + _t * 1.4
		var p := Vector2.from_angle(a) * (34.0 + sin(_t * 5.0 + i) * 2.0)
		p = (p / 3.0).round() * 3.0
		var c := colores[i % colores.size()]
		c.a = 0.55 + 0.35 * sin(_t * 6.0 + i)
		_aura.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), c)
