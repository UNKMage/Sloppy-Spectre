class_name Boost
extends Area2D
## Orbe de poder en pixel art que flota en el mapa. Al tocarlo Spooky, avisa con la señal
## `recogido` (GestorBoosts aplica el efecto). Si nadie lo toma a tiempo parpadea y desaparece.

signal recogido(tipo: int, posicion: Vector2)
signal expirado(tipo: int)

enum Tipo { ECTOPLASMA, INMUNIDAD }

const CELDA := 3.0
const COLORES := {
	Tipo.ECTOPLASMA: {"cuerpo": Color("33e04d"), "oscuro": Color("0b6b1c"), "luz": Color("b6ffb6")},
	Tipo.INMUNIDAD: {"cuerpo": Color("4db8ff"), "oscuro": Color("17508f"), "luz": Color("c4ecff")},
}
## Gota (ectoplasma) y escudo (inmunidad), 7x7.
const ICONOS := {
	Tipo.ECTOPLASMA: [
		"...#...",
		"...#...",
		"..###..",
		".#####.",
		".#####.",
		".#####.",
		"..###..",
	],
	Tipo.INMUNIDAD: [
		"#######",
		"#######",
		"#######",
		"#######",
		".#####.",
		"..###..",
		"...#...",
	],
}

var tipo: int = Tipo.ECTOPLASMA
## Segundos que espera en el mapa antes de desaparecer.
var vida: float = 15.0

var _t: float = 0.0
var _restante: float = 0.0
var _tomado := false


func _ready() -> void:
	z_index = 4
	_restante = vida
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 26.0
	forma.shape = circulo
	add_child(forma)
	area_entered.connect(_on_area_entered)
	# Aparece creciendo con un pequeño rebote.
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_restante -= delta
	if _restante <= 0.0 and not _tomado:
		_tomado = true
		expirado.emit(tipo)
		queue_free()
		return
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if _tomado or not area.is_in_group("jugador"):
		return
	_tomado = true
	recogido.emit(tipo, global_position)
	queue_free()


func _draw() -> void:
	# Parpadea en los últimos 4 segundos para avisar que se va.
	if _restante < 4.0 and int(_t * 7.0) % 2 == 0:
		return
	var col: Dictionary = COLORES[tipo]
	var cuerpo: Color = col["cuerpo"]
	var oscuro: Color = col["oscuro"]
	var luz: Color = col["luz"]
	var bob := sin(_t * 3.0) * 4.0
	var centro := Vector2(0.0, bob)

	# Sombra en el suelo.
	draw_rect(Rect2(-14.0, 26.0, 28.0, 4.0), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-8.0, 30.0, 16.0, 3.0), Color(0, 0, 0, 0.2))

	# Aro de pixeles que pulsa alrededor.
	var pulso := 0.5 + 0.5 * sin(_t * 4.0)
	for i in 16:
		var a := TAU * i / 16.0 + _t * 0.8
		var p := centro + Vector2.from_angle(a) * (31.0 + pulso * 3.0)
		p = (p / 3.0).round() * 3.0
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(luz.r, luz.g, luz.b, 0.25 + 0.35 * pulso if i % 2 == 0 else 0.15))

	# Orbe: contorno oscuro, cuerpo, brillo arriba a la izquierda y sombra abajo a la derecha.
	for gy in range(-7, 8):
		for gx in range(-7, 8):
			var d := Vector2(gx, gy).length()
			if d > 7.2:
				continue
			var c := cuerpo
			if d > 6.1:
				c = oscuro
			elif gx + gy < -6 and d < 6.0:
				c = luz
			elif gx + gy > 6:
				c = cuerpo.darkened(0.25)
			draw_rect(Rect2(centro + Vector2(gx, gy) * CELDA - Vector2(CELDA, CELDA) * 0.5, Vector2(CELDA, CELDA)), c)

	# Icono blanco con sombra.
	var icono: Array = ICONOS[tipo]
	for fila in icono.size():
		var linea: String = icono[fila]
		for colu in linea.length():
			if linea[colu] == "#":
				var p := centro + Vector2(colu - 3, fila - 3) * CELDA - Vector2(CELDA, CELDA) * 0.5
				draw_rect(Rect2(p + Vector2(1, 1), Vector2(CELDA, CELDA)), Color(oscuro.r, oscuro.g, oscuro.b, 0.8))
		for colu in linea.length():
			if linea[colu] == "#":
				var p := centro + Vector2(colu - 3, fila - 3) * CELDA - Vector2(CELDA, CELDA) * 0.5
				draw_rect(Rect2(p, Vector2(CELDA, CELDA)), Color.WHITE)

	# Destellos que orbitan.
	for k in 3:
		var a2 := _t * 2.0 + k * TAU / 3.0
		var q := centro + Vector2(cos(a2), sin(a2) * 0.6) * 38.0
		q = (q / 3.0).round() * 3.0
		if sin(_t * 8.0 + k * 2.0) > -0.2:
			draw_rect(Rect2(q - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


## Dibuja el icono de un boost (para el HUD). `celda` = tamaño de cada pixel.
static func dibujar_icono(destino: CanvasItem, p_tipo: int, esquina: Vector2, celda: float) -> void:
	var col: Dictionary = COLORES[p_tipo]
	var cuerpo: Color = col["cuerpo"]
	var oscuro: Color = col["oscuro"]
	for gy in range(-7, 8):
		for gx in range(-7, 8):
			var d := Vector2(gx, gy).length()
			if d > 7.2:
				continue
			var c := cuerpo if d <= 6.1 else oscuro
			destino.draw_rect(Rect2(esquina + Vector2(gx + 7, gy + 7) * celda, Vector2(celda, celda)), c)
	var icono: Array = ICONOS[p_tipo]
	for fila in icono.size():
		var linea: String = icono[fila]
		for colu in linea.length():
			if linea[colu] == "#":
				destino.draw_rect(Rect2(esquina + Vector2(colu + 4, fila + 4) * celda, Vector2(celda, celda)), Color.WHITE)
