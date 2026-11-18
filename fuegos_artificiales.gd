class_name FuegosArtificiales
extends Node2D
## Fuegos artificiales en pixel art: un cohete sube, explota y suelta chispas cuadradas que
## caen con gravedad y se apagan. Se usa para celebrar:
##   - en la pantalla final del último nivel (sin duración: no paran).

const PALETA: Array[Color] = [
	Color("ffd34d"), Color("ff5c8a"), Color("5ce6ff"), Color("6bff8a"), Color("a87cff"), Color("ffffff"),
]
const PIXEL := 4.0
const MAX_CHISPAS := 1600

## Zona del cielo donde explotan (coordenadas de este nodo).
@export var zona: Rect2 = Rect2(140, 70, 870, 230)
## Altura desde donde salen los cohetes.
@export var base_y: float = 650.0
## Segundos entre cohete y cohete (mínimo, máximo).
@export var intervalo: Vector2 = Vector2(0.22, 0.55)
## Segundos que dura la celebración (0 = no termina nunca).
@export var duracion: float = 0.0

var _cohetes: Array = []
var _chispas: Array = []
var _tiempo := 0.0
var _proximo := 0.0
var _activo := true


## Avisa que se pasó el nivel (niveles con puerta): cartel abajo de la pantalla. Sin fuegos artificiales,
## porque los niveles ocurren dentro de una casa.
static func celebrar_nivel(escena: Node) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	escena.add_child(capa)
	var fuente: Font = (preload("res://addons/pixel_bars/font/pixel_ui_font.fnt") as Font).duplicate()
	fuente.fallbacks = [ThemeDB.fallback_font]
	var cartel := Panel.new()
	cartel.size = Vector2(620, 74)
	cartel.position = Vector2(266, 640)
	cartel.add_theme_stylebox_override("panel", PixelCaja.nueva(Color(0.05, 0.04, 0.1), Color(1.0, 0.83, 0.3), Color(0.45, 0.35, 0.1)))
	capa.add_child(cartel)
	var titulo := Label.new()
	titulo.text = "¡NIVEL SUPERADO!"
	titulo.add_theme_font_override("font", fuente)
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(0, 10)
	titulo.size = Vector2(620, 32)
	cartel.add_child(titulo)
	var sub := Label.new()
	sub.text = "Entra a la puerta de arriba para pasar al siguiente nivel"
	sub.add_theme_font_override("font", fuente)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 42)
	sub.size = Vector2(620, 22)
	cartel.add_child(sub)
	# El cartel sube desde abajo, se queda un rato y se va.
	var tw := capa.create_tween()
	tw.tween_property(cartel, "position:y", 546.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(6.0)
	tw.tween_property(cartel, "position:y", 660.0, 0.4)
	tw.tween_callback(capa.queue_free)


func _process(delta: float) -> void:
	_tiempo += delta
	if duracion > 0.0 and _tiempo >= duracion:
		_activo = false
	if _activo:
		_proximo -= delta
		if _proximo <= 0.0:
			_lanzar()
			_proximo = randf_range(intervalo.x, intervalo.y)
	_actualizar(delta)
	if not _activo and _cohetes.is_empty() and _chispas.is_empty():
		queue_free()
		return
	queue_redraw()


func _lanzar() -> void:
	var x := randf_range(zona.position.x, zona.end.x)
	var objetivo := randf_range(zona.position.y, zona.end.y)
	var subida := base_y - objetivo
	# v = sqrt(2 * g * h) para llegar justo a la altura objetivo con la gravedad de los cohetes.
	var g := 260.0
	_cohetes.append({"pos": Vector2(x, base_y), "vel": Vector2(randf_range(-20, 20), -sqrt(2.0 * g * subida)),
		"color": PALETA[randi() % PALETA.size()], "g": g})


func _explotar(pos: Vector2, color: Color) -> void:
	var tipo := randi() % 3
	var n := randi_range(70, 110)
	var segundo := PALETA[randi() % PALETA.size()]
	for i in n:
		var ang := TAU * i / n + randf_range(-0.05, 0.05)
		var vel := randf_range(100.0, 230.0)
		var c := color
		if tipo == 0:
			vel = 190.0  # anillo perfecto
		elif tipo == 1 and i % 2 == 0:
			vel *= 0.55  # esfera doble, con dos colores
			c = segundo
		_chispas.append({"pos": pos, "vel": Vector2.from_angle(ang) * vel, "edad": 0.0,
			"vida": randf_range(1.3, 2.1), "color": c, "tam": PIXEL * (2.0 if randf() < 0.25 else 1.0)})
	# Destello blanco en el centro.
	for i in 6:
		_chispas.append({"pos": pos + Vector2.from_angle(randf() * TAU) * randf_range(0, 6), "vel": Vector2.ZERO,
			"edad": 0.0, "vida": 0.18, "color": Color.WHITE, "tam": PIXEL * 2.0})


func _actualizar(delta: float) -> void:
	var i := 0
	while i < _cohetes.size():
		var c: Dictionary = _cohetes[i]
		c.vel = c.vel + Vector2(0.0, c.g * delta)
		c.pos = c.pos + c.vel * delta
		if _chispas.size() < MAX_CHISPAS:
			_chispas.append({"pos": c.pos, "vel": Vector2(randf_range(-8, 8), 18.0), "edad": 0.0,
				"vida": 0.35, "color": Color(1.0, 0.85, 0.5), "tam": PIXEL * 0.5})
		if c.vel.y >= -8.0:
			_explotar(c.pos, c.color)
			_cohetes.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _chispas.size():
		var s: Dictionary = _chispas[i]
		s.edad = s.edad + delta
		if s.edad >= s.vida:
			_chispas.remove_at(i)
			continue
		s.vel = s.vel + Vector2(0.0, 90.0 * delta)
		s.vel = s.vel * (1.0 - 0.9 * delta)
		s.pos = s.pos + s.vel * delta
		i += 1


func _draw() -> void:
	for c in _cohetes:
		draw_rect(Rect2((c.pos as Vector2).snapped(Vector2(PIXEL, PIXEL)), Vector2(PIXEL, PIXEL * 1.5)), Color(1.0, 0.95, 0.7))
	for s in _chispas:
		var t: float = s.edad / s.vida
		var col: Color = s.color
		# Se apagan en pasos (pixel art): brillo pleno, medio y casi nada.
		var a := 1.0 if t < 0.55 else (0.6 if t < 0.8 else 0.3)
		if t > 0.5 and int(s.edad * 20.0) % 2 == 0:
			a *= 0.5  # parpadeo al final
		col.a = a
		var tam: float = s.tam
		draw_rect(Rect2((s.pos as Vector2).snapped(Vector2(PIXEL, PIXEL)), Vector2(tam, tam)), col)
