class_name Tutorial
extends Node
## Tutorial dentro del juego, sin pausar la partida. Vive como hijo de Spooky.
##   - Nivel 1, la primera vez: te explica tu cono de luz, cómo ensuciar, a los Limpiadores y la meta.
##     Cada paso avanza cuando haces lo que explica (o tras unos segundos).
##   - Cualquier nivel: la primera vez que aparece un orbe de cada tipo, un cartel arriba lo explica
##     y una flecha lo señala.
## Lo que ya viste se guarda (Opciones.visto), así no se repite. Pulsa T para saltarlo.

const NIVEL_1 := "res://main.tscn"
const PASOS := [
	{"id": "luz", "titulo": "TU LUZ", "texto": "Mueve el mouse para apuntar tu cono de luz. Solo lo que alumbras se ve con claridad: el resto queda en sombra.", "icono": "mouse", "color": Color(0.56, 0.92, 1.0), "max": 14.0},
	{"id": "ensuciar", "titulo": "ENSUCIA", "texto": "Pulsa ESPACIO o haz clic izquierdo para soltar ectoplasma. Gasta tu tanque: lo recargas en el portal del centro.", "icono": "espacio", "color": Color(0.45, 1.0, 0.55), "max": 20.0},
	{"id": "limpiadores", "titulo": "CUIDADO CON LOS LIMPIADORES", "texto": "En la sombra no los ves: alumbra para encontrarlos. Si su linterna te toca, quedas aturdido. ¡Un '!' significa que te vieron!", "icono": "alerta", "color": Color(1.0, 0.45, 0.4), "max": 9.0},
	{"id": "meta", "titulo": "LA META", "texto": "Ensucia el 100 % de la barra antes de que se acabe el tiempo. Ojo: los Limpiadores borran tus manchas.", "icono": "meta", "color": Color(1.0, 0.83, 0.3), "max": 8.0},
]
const ORBES := {
	0: {"clave": "orbe_0", "titulo": "ORBE VERDE: ECTOPLASMA INFINITO", "texto": "Tócalo y durante %d segundos ensuciar no gasta tu tanque."},
	1: {"clave": "orbe_1", "titulo": "ORBE AZUL: INMUNIDAD", "texto": "Tócalo y durante %d segundos los Limpiadores no te ven ni te aturden."},
}

var _ghost: Node2D
var _suelo: Node
var _capa: CanvasLayer
var _panel: Panel
var _titulo: Label
var _texto: Label
var _icono: Control
var _icono_tipo := ""
var _contador: Label
var _orbe_panel: Panel
var _orbe_titulo: Label
var _orbe_texto: Label
var _flecha: Node2D
var _t := 0.0
var _paso := -1
var _paso_t := 0.0
var _manchas_paso := 0
var _angulo_ini := 0.0
var _angulo_acum := 0.0
var _angulo_prev := 0.0
var _orbe_resta := 0.0
var _activo := false


func _ready() -> void:
	Opciones.cargar()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ghost = get_parent() as Node2D
	_suelo = get_tree().get_first_node_in_group("suelo")
	var escena := get_tree().current_scene
	var hacer_basico := escena != null and escena.scene_file_path == NIVEL_1 and not Opciones.visto("tutorial_basico")
	var gestor := escena.get_node_or_null("GestorBoosts") if escena else null
	var hay_orbes_nuevos := false
	if gestor:
		gestor.orbe_aparecio.connect(_on_orbe)
		hay_orbes_nuevos = not (Opciones.visto("orbe_0") and Opciones.visto("orbe_1"))
	if not hacer_basico and not hay_orbes_nuevos:
		queue_free()
		return
	_crear_interfaz()
	if _suelo and _suelo.has_signal("celda_pintada"):
		_suelo.celda_pintada.connect(func(_c: Vector2i, _total: int) -> void: _manchas_paso += 1)
	if hacer_basico:
		_activo = true
		_siguiente_paso()


func _process(delta: float) -> void:
	_t += delta
	if get_tree().paused:
		return
	if Input.is_key_pressed(KEY_T) and _activo:
		_saltar()
	if _activo and _paso >= 0:
		_paso_t += delta
		_vigilar_paso()
		_panel.modulate.a = move_toward(_panel.modulate.a, 1.0, delta * 4.0)
		_icono.queue_redraw()
	if _orbe_resta > 0.0:
		_orbe_resta -= delta
		if _orbe_resta <= 0.0:
			_orbe_panel.visible = false
			if _flecha:
				_flecha.visible = false
	if _flecha and _flecha.visible:
		_flecha.queue_redraw()


# --- Pasos del tutorial básico ---

func _siguiente_paso() -> void:
	_paso += 1
	_paso_t = 0.0
	_manchas_paso = 0
	_angulo_acum = 0.0
	if _paso >= PASOS.size():
		_terminar()
		return
	var p: Dictionary = PASOS[_paso]
	_titulo.text = p["titulo"]
	_titulo.add_theme_color_override("font_color", p["color"])
	_texto.text = p["texto"]
	_contador.text = "%d/%d     T = saltar" % [_paso + 1, PASOS.size()]
	_icono_tipo = p["icono"]
	_panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), p["color"], (p["color"] as Color).darkened(0.6)))
	_panel.visible = true
	_panel.modulate.a = 0.0


## ¿Ya hizo el jugador lo que pide este paso? Si no, avanza solo tras un tiempo máximo.
func _vigilar_paso() -> void:
	var p: Dictionary = PASOS[_paso]
	var listo := false
	match p["id"]:
		"luz":
			var vision := _ghost.get_node_or_null("Vision")
			if vision:
				var a: float = vision.get("_angulo")
				_angulo_acum += absf(angle_difference(_angulo_prev, a))
				_angulo_prev = a
			listo = _angulo_acum > 2.0 and _paso_t > 2.0
		"ensuciar":
			listo = _manchas_paso >= 3
		"limpiadores", "meta":
			listo = _paso_t >= float(p["max"]) * 0.6
	if listo or _paso_t >= float(p["max"]):
		_siguiente_paso()


func _saltar() -> void:
	_terminar()


func _terminar() -> void:
	_activo = false
	_panel.visible = false
	Opciones.marcar_visto("tutorial_basico")


# --- Carteles de orbes ---

func _on_orbe(tipo: int, posicion: Vector2) -> void:
	var d: Dictionary = ORBES.get(tipo, {})
	if d.is_empty() or Opciones.visto(d["clave"]):
		return
	Opciones.marcar_visto(d["clave"])
	_orbe_titulo.text = d["titulo"]
	# La duración depende del nivel (en el nivel 1 el ectoplasma infinito dura menos).
	var gestor := get_tree().current_scene.get_node_or_null("GestorBoosts")
	var segundos: float = 0.0
	if gestor:
		segundos = gestor.duracion_ectoplasma if tipo == 0 else gestor.duracion_inmunidad
	_orbe_texto.text = d["texto"] % roundi(segundos)
	var color: Color = Boost.COLORES[tipo]["cuerpo"]
	_orbe_titulo.add_theme_color_override("font_color", Boost.COLORES[tipo]["luz"])
	_orbe_panel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), color, (Boost.COLORES[tipo]["oscuro"] as Color)))
	_orbe_panel.visible = true
	_orbe_resta = 8.0
	if _flecha == null:
		_flecha = Node2D.new()
		_flecha.z_index = 20
		_flecha.draw.connect(_dibujar_flecha)
		get_tree().current_scene.add_child(_flecha)
	_flecha.position = posicion
	_flecha.set_meta("color", color)
	_flecha.visible = true
	_flecha.queue_redraw()


func _dibujar_flecha() -> void:
	var c: Color = _flecha.get_meta("color", Color.WHITE)
	var rebote := absf(sin(_t * 5.0)) * 8.0
	var y := -64.0 - rebote
	# Flecha de pixel art apuntando hacia abajo, al orbe.
	var filas := [[-12, 24], [-8, 16], [-4, 8]]
	for i in filas.size():
		_flecha.draw_rect(Rect2(filas[i][0] + 0.0, y + i * 6.0 + 6.0, filas[i][1], 6), Color(0.05, 0.04, 0.1))
		_flecha.draw_rect(Rect2(filas[i][0] + 2.0, y + i * 6.0 + 8.0, filas[i][1] - 4, 2), c)
	_flecha.draw_rect(Rect2(-4, y - 10.0, 8, 18), Color(0.05, 0.04, 0.1))
	_flecha.draw_rect(Rect2(-2, y - 8.0, 4, 14), c)


# --- Interfaz ---

func _crear_interfaz() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 7
	add_child(_capa)

	# Cartel de pasos (abajo)
	_panel = Panel.new()
	_panel.position = Vector2(126, 508)
	_panel.size = Vector2(900, 112)
	_panel.visible = false
	_capa.add_child(_panel)
	_icono = Control.new()
	_icono.position = Vector2(20, 16)
	_icono.size = Vector2(80, 80)
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.draw.connect(_dibujar_icono)
	_panel.add_child(_icono)
	_titulo = UIPixel.etiqueta("", 20, Color.WHITE, 6, HORIZONTAL_ALIGNMENT_LEFT)
	_titulo.position = Vector2(116, 12)
	_titulo.size = Vector2(770, 28)
	_panel.add_child(_titulo)
	_texto = UIPixel.etiqueta("", 16, Color(0.92, 0.94, 1.0), 0, HORIZONTAL_ALIGNMENT_LEFT)
	_texto.position = Vector2(116, 42)
	_texto.size = Vector2(770, 52)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel.add_child(_texto)
	_contador = UIPixel.etiqueta("", 12, Color(1, 1, 1, 0.5), 4, HORIZONTAL_ALIGNMENT_RIGHT)
	_contador.position = Vector2(600, 90)
	_contador.size = Vector2(286, 18)
	_panel.add_child(_contador)

	# Cartel de orbes (arriba)
	_orbe_panel = Panel.new()
	_orbe_panel.position = Vector2(176, 62)
	_orbe_panel.size = Vector2(800, 92)
	_orbe_panel.visible = false
	_capa.add_child(_orbe_panel)
	_orbe_titulo = UIPixel.etiqueta("", 20, Color.WHITE, 6)
	_orbe_titulo.position = Vector2(0, 12)
	_orbe_titulo.size = Vector2(800, 28)
	_orbe_panel.add_child(_orbe_titulo)
	_orbe_texto = UIPixel.etiqueta("", 16, Color(0.92, 0.94, 1.0), 0)
	_orbe_texto.position = Vector2(24, 46)
	_orbe_texto.size = Vector2(752, 36)
	_orbe_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	_orbe_panel.add_child(_orbe_texto)


## Iconos de pixel art de cada paso: mouse con cono, tecla espacio, signo de alerta y meta.
func _dibujar_icono() -> void:
	var u := 5.0
	var oscuro := Color(0.08, 0.08, 0.16)
	var blanco := Color(0.95, 0.96, 1.0)
	match _icono_tipo:
		"mouse":
			# cono de luz que se mueve y mouse
			var g := sin(_t * 3.0) * 0.4
			var origen := Vector2(40, 52)
			for k in 3:
				var f := 1.0 - k * 0.3
				var a := origen + Vector2.from_angle(-PI / 2 - 0.5 + g) * 40.0 * f
				var b := origen + Vector2.from_angle(-PI / 2 + 0.5 + g) * 40.0 * f
				_icono.draw_colored_polygon(PackedVector2Array([origen, a, b]), Color(1.0, 0.92, 0.55, 0.22))
			_icono.draw_rect(Rect2(26, 44, 28, 36), oscuro)
			_icono.draw_rect(Rect2(28, 46, 24, 32), blanco)
			_icono.draw_rect(Rect2(39, 46, 2, 14), oscuro)
			_icono.draw_rect(Rect2(28, 60, 24, 2), oscuro)
		"espacio":
			var pulso := int(_t * 3.0) % 2 == 0
			_icono.draw_rect(Rect2(4, 30, 72, 34), oscuro)
			_icono.draw_rect(Rect2(8, 32 if pulso else 30, 64, 28), blanco)
			_icono.draw_rect(Rect2(8, 56 if pulso else 54, 64, 4), Color(0.7, 0.72, 0.85))
			var l := UIPixel.fuente()
			_icono.draw_string(l, Vector2(8, 52 if pulso else 50), "ESPACIO", HORIZONTAL_ALIGNMENT_CENTER, 64.0, 12, oscuro)
		"alerta":
			var s := 1.0 + 0.1 * sin(_t * 8.0)
			_icono.draw_set_transform(Vector2(40, 42), 0.0, Vector2(s, s))
			_icono.draw_rect(Rect2(-24, -30, 48, 60), oscuro)
			_icono.draw_rect(Rect2(-20, -26, 40, 52), Color(1.0, 0.35, 0.3))
			_icono.draw_rect(Rect2(-5, -18, 10, 24), Color.WHITE)
			_icono.draw_rect(Rect2(-5, 11, 10, 8), Color.WHITE)
			_icono.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"meta":
			_icono.draw_rect(Rect2(10, 56, 60, 10), oscuro)
			_icono.draw_rect(Rect2(12, 58, 56, 6), Color(0.1, 0.09, 0.16))
			var lleno := 56.0 * (0.4 + 0.45 * absf(sin(_t * 1.5)))
			_icono.draw_rect(Rect2(12, 58, lleno, 6), Color(0.45, 1.0, 0.55))
			_icono.draw_rect(Rect2(10 + 56 - 1, 48, 3, 24), Color.WHITE)
			_icono.draw_string(UIPixel.fuente(), Vector2(0, 40), "100 %", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(1.0, 0.83, 0.3))
