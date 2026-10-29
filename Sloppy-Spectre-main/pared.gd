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
## Color provisional de la pared (hasta que haya arte).
@export var color: Color = Color(0.33, 0.25, 0.46):
	set(valor):
		color = valor
		queue_redraw()

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


func _draw() -> void:
	var rect := Rect2(-tamano * 0.5, tamano)
	draw_rect(rect, color)
	draw_rect(rect, color.lightened(0.35), false, 2.0)


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
