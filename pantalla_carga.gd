extends CanvasLayer
## Pantalla de carga al entrar al portal de salida. Cubre toda la pantalla mientras carga el
## siguiente nivel: remolino del portal en pixel art, Spooky flotando, nombre del nivel, barra
## de progreso y un consejo. Se arma en código, como el menú. Siempre dura un mínimo, para
## que no sea un parpadeo cuando el nivel carga al instante.

const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")
const FANTASMA := preload("res://Ghost.png")
const PALETA: Array[Color] = [
	Color("1b1040"), Color("2d1b6b"), Color("4b2fa0"), Color("7a5ce6"), Color("8feaff"),
]
const PIXEL := 6.0
const RADIO_PORTAL := 92.0
## Segundos mínimos que se muestra la pantalla.
const DURACION_MINIMA := 2.4

## Nombre y dificultad de cada nivel, según la escena a la que se va.
const NIVELES := {
	"res://main.tscn": ["NIVEL 1", "Fácil"],
	"res://nivel_2.tscn": ["NIVEL 2", "Intermedio"],
	"res://nivel_3.tscn": ["NIVEL 3", "Difícil"],
}
const CONSEJOS: Array[String] = [
	"Apunta con el mouse: tu luz revela el ectoplasma y a los Limpiadores.",
	"Ensucia con la barra espaciadora o con el clic izquierdo.",
	"Regresa al portal del centro para recargar tu tanque de ectoplasma.",
	"Los orbes verdes te dan ectoplasma infinito por 8 segundos.",
	"Los orbes azules te vuelven inmune a los Limpiadores por 10 segundos.",
	"El ectoplasma se ve tenue en la sombra: úsalo para recordar dónde ensuciaste.",
	"Si la linterna del Limpiador te alcanza, quedas aturdido 3 segundos.",
]

var ruta_destino: String = ""
var progreso: Array = []
var cargando: bool = false

var _fuente: Font
var _raiz: Control
var _vortice: Control
var _barra: Control
var _fantasma: Sprite2D
var _estado: Label
var _consejo: Label
var _tiempo := 0.0
var _real := 0.0        # progreso real de la carga (0..1)
var _mostrado := 0.0    # progreso que se dibuja (sube suave)
var _listo := false
var _saliendo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fuente = FUENTE_PIXEL.duplicate()
	_fuente.fallbacks = [ThemeDB.fallback_font]


func iniciar_carga(ruta: String) -> void:
	ruta_destino = ruta
	cargando = true
	_construir()
	ResourceLoader.load_threaded_request(ruta_destino)
	# Entra desde negro.
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.35)


func _process(delta: float) -> void:
	_tiempo += delta
	if _fantasma:
		_fantasma.position.y = 150.0 + sin(_tiempo * 2.4) * 10.0
		_fantasma.rotation = sin(_tiempo * 1.6) * 0.1
		_fantasma.scale = Vector2.ONE * (4.0 + sin(_tiempo * 2.4) * 0.15)
	if _vortice:
		_vortice.queue_redraw()
	if _barra:
		_barra.queue_redraw()
	if _estado and not _listo:
		_estado.text = "CARGANDO" + ".".repeat(int(_tiempo * 2.5) % 4) + "   %d%%" % int(_mostrado * 100.0)
	if not cargando or _saliendo:
		return

	var estado := ResourceLoader.load_threaded_get_status(ruta_destino, progreso)
	if progreso.size() > 0:
		_real = progreso[0]
	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		_real = 1.0
	elif estado == ResourceLoader.THREAD_LOAD_FAILED:
		cargando = false
		_estado.text = "ERROR AL CARGAR EL NIVEL"
		return
	# La barra sube suave y nunca va más rápido que el tiempo mínimo.
	var tope := minf(_real, clampf(_tiempo / DURACION_MINIMA, 0.0, 1.0))
	_mostrado = move_toward(_mostrado, tope, delta * 0.9)

	if estado == ResourceLoader.THREAD_LOAD_LOADED and _tiempo >= DURACION_MINIMA and _mostrado >= 0.999:
		_terminar()


func _terminar() -> void:
	_saliendo = true
	cargando = false
	_listo = true
	_estado.text = "¡LISTO!"
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = false
	var escena_empaquetada := ResourceLoader.load_threaded_get(ruta_destino) as PackedScene
	get_tree().change_scene_to_packed(escena_empaquetada)
	# Se desvanece para revelar el nivel nuevo.
	var tw := create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.6)
	await tw.finished
	queue_free()


# --- Construcción de la interfaz ---

func _etiqueta(texto: String, tamano: int, color: Color, contorno: int = 0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fuente)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.06))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _construir() -> void:
	var datos: Array = NIVELES.get(ruta_destino, ["SIGUIENTE NIVEL", ""])
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea clics al juego mientras carga
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.09)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)

	# Viñeta
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.3, 1.0])
	g.colors = PackedColorArray([Color(0.1, 0.05, 0.25, 0.0), Color(0, 0, 0, 0.85)])
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

	# Motas de espíritu que suben, atraídas por el portal.
	var p := CPUParticles2D.new()
	p.position = Vector2(576, 380)
	p.amount = 60
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(620, 340)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var r := Gradient.new()
	r.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	r.colors = PackedColorArray([Color(0.7, 0.9, 1.0, 0.0), Color(0.7, 0.9, 1.0, 0.6), Color(0.5, 0.4, 1.0, 0.0)])
	p.color_ramp = r
	_raiz.add_child(p)

	# Remolino del portal, centrado arriba
	_vortice = Control.new()
	_vortice.position = Vector2(576, 215)
	_vortice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vortice.draw.connect(_dibujar_vortice)
	_raiz.add_child(_vortice)

	_fantasma = Sprite2D.new()
	_fantasma.texture = FANTASMA
	_fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fantasma.scale = Vector2(4, 4)
	_fantasma.position = Vector2(576, 150)
	_raiz.add_child(_fantasma)

	var nombre := _etiqueta(datos[0], 64, Color(0.56, 0.92, 1.0), 12)
	nombre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nombre.offset_top = 338.0
	nombre.offset_bottom = 420.0
	_raiz.add_child(nombre)
	if datos[1] != "":
		var dificultad := _etiqueta(datos[1], 22, Color(0.9, 0.92, 1.0, 0.9), 6)
		dificultad.set_anchors_preset(Control.PRESET_TOP_WIDE)
		dificultad.offset_top = 418.0
		dificultad.offset_bottom = 452.0
		_raiz.add_child(dificultad)

	_barra = Control.new()
	_barra.position = Vector2(326, 478)
	_barra.size = Vector2(500, 30)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar_barra)
	_raiz.add_child(_barra)

	_estado = _etiqueta("CARGANDO", 16, Color(0.85, 0.88, 1.0, 0.95), 5)
	_estado.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_estado.offset_top = 514.0
	_estado.offset_bottom = 540.0
	_raiz.add_child(_estado)

	var cartel := Panel.new()
	cartel.position = Vector2(176, 566)
	cartel.size = Vector2(800, 52)
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), Color(0.4, 0.34, 0.8), Color(0.18, 0.14, 0.4)))
	_raiz.add_child(cartel)
	_consejo = _etiqueta("CONSEJO:  " + CONSEJOS[randi() % CONSEJOS.size()], 14, Color(1, 1, 1, 0.92), 0)
	_consejo.position = Vector2(12, 14)
	_consejo.size = Vector2(776, 24)
	cartel.add_child(_consejo)


## Remolino del portal en pixel art, igual que el del juego pero grande.
func _dibujar_vortice() -> void:
	var celdas := int(ceil(RADIO_PORTAL * 1.15 / PIXEL))
	var pulso := 0.5 + 0.5 * sin(_tiempo * 2.2)
	for gy in range(-celdas, celdas):
		for gx in range(-celdas, celdas):
			var c := Vector2((gx + 0.5) * PIXEL, (gy + 0.5) * PIXEL)
			var r := c.length() / RADIO_PORTAL
			var color: Color
			if r > 1.1:
				continue
			elif r > 1.0:
				color = Color("14142b")
			elif r > 0.84:
				var n := (gx * 374761393 + gy * 668265263) & 0x7fffffff
				n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
				var piedras: Array[Color] = [Color("48506a"), Color("5b6379"), Color("3d445c"), Color("6a728a")]
				color = piedras[(n & 0xffff) % 4]
				if r > 0.96 or r < 0.87:
					color = color.darkened(0.2)
			elif r > 0.8:
				color = Color("14142b")
			else:
				var ang := atan2(c.y, c.x)
				var giro := sin(ang * 3.0 + r * 7.0 - _tiempo * 2.4) * 0.5 + 0.5
				var v := giro * 0.55 + (1.0 - r / 0.8) * 0.55 + pulso * 0.1
				color = PALETA[clampi(int(v * 4.2), 0, 4)]
			_vortice.draw_rect(Rect2(c - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), color)
	# Runas que giran alrededor del aro.
	for k in 8:
		var a := k * TAU / 8.0 + _tiempo * 0.5
		var p := (Vector2.from_angle(a) * RADIO_PORTAL * 0.92 / PIXEL).round() * PIXEL
		var brillo := 0.5 + 0.5 * sin(_tiempo * 3.0 - k * 0.8)
		_vortice.draw_rect(Rect2(p - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), Color(0.56, 0.92, 1.0, 0.35 + brillo * 0.65))


## Barra segmentada de pixel art.
func _dibujar_barra() -> void:
	var ancho := _barra.size.x
	var alto := _barra.size.y
	var u := 4.0
	var marco := Color(0.4, 0.34, 0.8)
	_barra.draw_rect(Rect2(0, 0, ancho, alto), marco)
	_barra.draw_rect(Rect2(u, u, ancho - 2.0 * u, alto - 2.0 * u), Color(0.06, 0.05, 0.12))
	var bloques := 30
	var paso := (ancho - 4.0 * u) / bloques
	for i in bloques:
		var x := 2.0 * u + i * paso
		var encendido := (i + 1.0) / bloques <= _mostrado + 0.001
		var c := Color(0.56, 0.92, 1.0) if encendido else Color(1, 1, 1, 0.07)
		_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, alto - 4.0 * u), c.darkened(0.2) if encendido else c)
		if encendido:
			_barra.draw_rect(Rect2(x, 2.0 * u, paso - 2.0, 4.0), Color(0.85, 1.0, 1.0))


