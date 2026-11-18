@tool
class_name Pared
extends StaticBody2D
## Pared de los niveles. Se coloca y se ajusta directamente en el editor:
##   - Para MOVERLA: arrástrala en la vista 2D (el origen está en el CENTRO de la pared).
##   - Para cambiar su TAMAÑO: propiedad "Tamano" en el Inspector (ancho, alto en píxeles).
## Bloquea a Spooky y a los Limpiadores, y tapa la luz de la linterna (capa física 3 = "paredes").
## El nivel (nivel_con_paredes.gd) las detecta solo: quita el suelo bajo ellas y
## recalcula por dónde pueden caminar los Limpiadores.

## Capa física 3 ("paredes") = valor 4.
const CAPA_PAREDES := 4

## Ancho y alto de la pared, en píxeles.
@export var tamano: Vector2 = Vector2(40, 300):
	set(valor):
		tamano = valor.max(Vector2(4, 4))  # nunca cero ni negativo
		_actualizar()

var _colision: CollisionShape2D


func _enter_tree() -> void:
	add_to_group("paredes")  # así el nivel encuentra todas las paredes sin listarlas a mano


func _ready() -> void:
	if not Engine.is_editor_hint():
		collision_layer = CAPA_PAREDES
		collision_mask = 0
		z_index = 2  # por encima de las manchas, por debajo de Spooky y los Limpiadores (z 3)
	# La forma de colisión se crea aquí, una por pared, y se guarda como nodo "interno":
	# no sale en el árbol de nodos ni en el .tscn, y al duplicar una pared cada copia
	# tiene su propia forma (no se redimensionan todas a la vez).
	_colision = CollisionShape2D.new()
	_colision.shape = RectangleShape2D.new()
	add_child(_colision, false, Node.INTERNAL_MODE_FRONT)
	_actualizar()


func _actualizar() -> void:
	if _colision != null:
		(_colision.shape as RectangleShape2D).size = tamano
	queue_redraw()


## Estilo de la textura (pixel art dibujado en código, con la paleta de los fondos).
enum Estilo { LADRILLO, PIEDRA, RUINAS }
@export var estilo: Estilo = Estilo.RUINAS:
	set(valor):
		estilo = valor
		queue_redraw()

const CONTORNO := Color("14142b")
const MORTERO := Color("3a2030")
const LADRILLOS: Array[Color] = [Color("73362d"), Color("85402f"), Color("652a2a"), Color("8f4636")]
const PIEDRAS: Array[Color] = [Color("4c5469"), Color("555e75"), Color("444b61"), Color("5a6278")]
const MUSGOS: Array[Color] = [Color("3f5f2c"), Color("55803a"), Color("2f4a24")]
const LADRILLO_ANCHO := 24.0
const LADRILLO_ALTO := 12.0


func _draw() -> void:
	var rect := Rect2(-tamano * 0.5, tamano)
	# Sombra proyectada hacia abajo y a la derecha.
	draw_rect(Rect2(rect.position + Vector2(6.0, 8.0), rect.size), Color(0, 0, 0, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position)) + int(tamano.x * 31.0 + tamano.y)
	match estilo:
		Estilo.LADRILLO:
			_dibujar_ladrillos(rect, rng)
		Estilo.PIEDRA:
			_dibujar_piedra(rect, rng)
		_:
			_dibujar_ruinas(rect, rng)
	_dibujar_detalles(rect, rng)
	draw_rect(rect.grow(-1.0), CONTORNO, false, 2.0)


func _dibujar_ladrillos(rect: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(rect, MORTERO)
	var filas := int(ceil(rect.size.y / LADRILLO_ALTO))
	for f in filas:
		var y := rect.position.y + f * LADRILLO_ALTO
		var desfase := -LADRILLO_ANCHO * 0.5 if f % 2 == 1 else 0.0
		var x := rect.position.x + desfase
		while x < rect.end.x:
			var ladrillo := Rect2(x + 1.0, y + 1.0, LADRILLO_ANCHO - 2.0, LADRILLO_ALTO - 2.0).intersection(rect)
			if ladrillo.size.x > 1.0 and ladrillo.size.y > 1.0:
				var c := LADRILLOS[rng.randi() % LADRILLOS.size()]
				draw_rect(ladrillo, c)
				draw_rect(Rect2(ladrillo.position, Vector2(ladrillo.size.x, 2.0)), c.lightened(0.12))
				draw_rect(Rect2(ladrillo.position + Vector2(0.0, ladrillo.size.y - 2.0), Vector2(ladrillo.size.x, 2.0)), c.darkened(0.2))
			x += LADRILLO_ANCHO


func _dibujar_piedra(rect: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(rect, Color("343a50"))
	var alto := 28.0
	var filas := int(ceil(rect.size.y / alto))
	for f in filas:
		var y := rect.position.y + f * alto
		var c := PIEDRAS[rng.randi() % PIEDRAS.size()]
		var bloque := Rect2(rect.position.x + 1.0, y + 1.0, rect.size.x - 2.0, alto - 2.0).intersection(rect)
		if bloque.size.y > 1.0:
			draw_rect(bloque, c)
			draw_rect(Rect2(bloque.position, Vector2(bloque.size.x, 2.0)), c.lightened(0.15))
			draw_rect(Rect2(bloque.position + Vector2(0.0, bloque.size.y - 2.0), Vector2(bloque.size.x, 2.0)), c.darkened(0.22))


## Musgo en la base, grietas y manchas de humedad: que no se vea una pared nueva.
func _dibujar_detalles(rect: Rect2, rng: RandomNumberGenerator) -> void:
	var area := rect.size.x * rect.size.y
	for i in int(clampf(area / 900.0, 2.0, 40.0)):
		var p := Vector2(rng.randf_range(rect.position.x + 2.0, rect.end.x - 6.0), rect.end.y - rng.randf_range(2.0, minf(26.0, rect.size.y)))
		var w := rng.randf_range(4.0, 10.0)
		draw_rect(Rect2(p.snapped(Vector2(2, 2)), Vector2(w, 4.0)).intersection(rect), MUSGOS[rng.randi() % MUSGOS.size()])
	for i in int(clampf(area / 2500.0, 1.0, 14.0)):
		var p := Vector2(rng.randf_range(rect.position.x + 4.0, rect.end.x - 4.0), rng.randf_range(rect.position.y + 4.0, rect.end.y - 8.0)).snapped(Vector2(2, 2))
		draw_rect(Rect2(p, Vector2(2.0, rng.randf_range(6.0, 14.0))).intersection(rect), Color(0.05, 0.05, 0.12, 0.55))
	# Luz suave desde arriba, sombra en el pie.
	draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(rect.size.x - 2.0, 3.0)), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(rect.position + Vector2(1.0, rect.size.y - 5.0), Vector2(rect.size.x - 2.0, 4.0)), Color(0, 0, 0, 0.22))


## Las 4 esquinas de la pared en coordenadas globales (respeta posición, rotación y escala).
## Siempre en el mismo sentido (horario), que es lo que pide el horneado de navegación.
func contorno_global() -> PackedVector2Array:
	var m := tamano * 0.5
	var t := global_transform
	var contorno := PackedVector2Array([
		t * Vector2(-m.x, -m.y),
		t * Vector2(m.x, -m.y),
		t * Vector2(m.x, m.y),
		t * Vector2(-m.x, m.y),
	])
	if not Geometry2D.is_polygon_clockwise(contorno):
		contorno.reverse()
	return contorno


const YESOS: Array[Color] = [Color("4b5068"), Color("545973"), Color("444962"), Color("5a5f7a")]
const LADRILLOS_VIEJOS: Array[Color] = [Color("5e2d2d"), Color("6d3631"), Color("522828"), Color("733c33")]


## Muro de ruinas: yeso gris azulado desconchado, con ladrillo viejo al descubierto, grietas y
## una cornisa clara arriba. Más oscuro y apagado, para que se funda con los fondos nocturnos.
func _dibujar_ruinas(rect: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(rect, Color("33384d"))
	# Paños de yeso con juntas.
	var alto := 40.0
	for f in int(ceil(rect.size.y / alto)):
		var y := rect.position.y + f * alto
		var c := YESOS[rng.randi() % YESOS.size()]
		var panel := Rect2(rect.position.x + 1.0, y + 1.0, rect.size.x - 2.0, alto - 2.0).intersection(rect)
		if panel.size.y > 1.0:
			draw_rect(panel, c)
			draw_rect(Rect2(panel.position, Vector2(panel.size.x, 2.0)), c.lightened(0.12))
	# Motas de textura en el yeso.
	for i in int(rect.size.x * rect.size.y / 160.0):
		var p := Vector2(rng.randf_range(rect.position.x + 2.0, rect.end.x - 4.0), rng.randf_range(rect.position.y + 2.0, rect.end.y - 4.0)).snapped(Vector2(2, 2))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0, 0, 0.1, 0.18) if rng.randf() < 0.6 else Color(1, 1, 1, 0.07))
	# Ladrillo al descubierto donde cayó el yeso.
	for i in int(clampf(rect.size.x * rect.size.y / 2400.0, 1.0, 9.0)):
		var an := rng.randf_range(12.0, maxf(14.0, rect.size.x - 6.0))
		var al := rng.randf_range(14.0, 30.0)
		var origen := Vector2(rng.randf_range(rect.position.x + 3.0, maxf(rect.position.x + 4.0, rect.end.x - an - 3.0)),
			rng.randf_range(rect.position.y + 6.0, maxf(rect.position.y + 7.0, rect.end.y - al - 6.0))).snapped(Vector2(2, 2))
		var parche := Rect2(origen, Vector2(an, al)).intersection(rect.grow(-3.0))
		if parche.size.x < 4.0 or parche.size.y < 4.0:
			continue
		# Contorno irregular: se "muerden" las esquinas.
		draw_rect(Rect2(parche.position + Vector2(4, 0), parche.size - Vector2(8, 0)), Color("2a1a22"))
		draw_rect(Rect2(parche.position + Vector2(0, 4), parche.size - Vector2(0, 8)), Color("2a1a22"))
		var interior := parche.grow(-2.0)
		for fila in int(ceil(interior.size.y / 6.0)):
			var yb := interior.position.y + fila * 6.0
			var desf := -6.0 if fila % 2 == 1 else 0.0
			var xb := interior.position.x + desf
			while xb < interior.end.x:
				var ladrillo := Rect2(xb + 1.0, yb + 1.0, 10.0, 4.0).intersection(interior)
				if ladrillo.size.x > 1.0 and ladrillo.size.y > 1.0:
					draw_rect(ladrillo, LADRILLOS_VIEJOS[rng.randi() % LADRILLOS_VIEJOS.size()])
				xb += 12.0
	# Grietas en zigzag.
	for i in int(clampf(rect.size.x * rect.size.y / 3000.0, 1.0, 8.0)):
		var p := Vector2(rng.randf_range(rect.position.x + 6.0, rect.end.x - 6.0), rng.randf_range(rect.position.y + 4.0, rect.end.y - 30.0)).snapped(Vector2(2, 2))
		for paso in 5:
			var siguiente := p + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(4.0, 8.0)).snapped(Vector2(2, 2))
			draw_line(p, siguiente, Color(0.04, 0.04, 0.1, 0.8), 2.0)
			p = siguiente
	# Cornisa clara arriba (la luz da en el borde superior).
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2.0, 4.0)), Color("7d83a0"))
	draw_rect(Rect2(rect.position + Vector2(1, 5), Vector2(rect.size.x - 2.0, 2.0)), Color("2a2e42"))
