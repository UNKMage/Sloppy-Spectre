class_name EstelaPolvo
extends Node2D
## Estela de polvo que deja un Limpiador al caminar. No lleva el material de visión,
## así que se ve siempre, aunque el Limpiador en sí quede oculto por la sombra.
## Cada paso suelta un puñado de "motitas" suaves que flotan, crecen y se disipan.

## Cada cuántos píxeles recorridos suelta una nubecita.
@export var distancia_entre_nubes: float = 14.0
## Motitas que forman cada nubecita.
@export_range(1, 8) var motas_por_nube: int = 4
## Segundos que tarda en disiparse cada mota.
@export var duracion: float = 2.6
## Radio inicial de cada mota, en píxeles.
@export var radio_inicial: float = 6.0
## Cuánto crece cada mota mientras se disipa.
@export var crecimiento: float = 14.0
## Qué tan rápido se dispersan las motas (px/s).
@export var dispersion: float = 14.0
## Deriva hacia arriba, como polvo que se levanta (px/s).
@export var elevacion: float = 8.0
## Color del polvo (el alfa es la opacidad máxima de cada mota).
@export var color: Color = Color(0.88, 0.84, 0.76, 0.32)

var objetivo: Node2D
var _motas: Array = []  # cada una: {pos, vel, edad, vida, radio, giro}
var _ultima_pos: Vector2 = Vector2.INF
static var _textura: GradientTexture2D


func _ready() -> void:
	if _textura == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_textura = GradientTexture2D.new()
		_textura.gradient = g
		_textura.fill = GradientTexture2D.FILL_RADIAL
		_textura.fill_from = Vector2(0.5, 0.5)
		_textura.fill_to = Vector2(1.0, 0.5)
		_textura.width = 64
		_textura.height = 64


func _process(delta: float) -> void:
	if is_instance_valid(objetivo):
		var pos := objetivo.global_position
		if _ultima_pos == Vector2.INF or pos.distance_to(_ultima_pos) >= distancia_entre_nubes:
			_ultima_pos = pos
			_soltar_nube(pos)
	var i := 0
	while i < _motas.size():
		var m: Dictionary = _motas[i]
		m.edad += delta
		if m.edad >= m.vida:
			_motas.remove_at(i)
			continue
		m.pos += m.vel * delta
		m.vel *= maxf(0.0, 1.0 - 1.4 * delta)  # frena poco a poco
		i += 1
	queue_redraw()


func _soltar_nube(pos: Vector2) -> void:
	for k in motas_por_nube:
		var dir := Vector2.from_angle(randf() * TAU)
		_motas.append({
			"pos": pos + dir * randf_range(0.0, 7.0) + Vector2(0.0, 6.0),
			"vel": dir * randf_range(0.3, 1.0) * dispersion + Vector2(0.0, -elevacion),
			"edad": 0.0,
			"vida": duracion * randf_range(0.7, 1.15),
			"radio": radio_inicial * randf_range(0.7, 1.3),
			"giro": randf_range(0.85, 1.2),
		})


func _draw() -> void:
	for m in _motas:
		var t: float = m.edad / m.vida
		# Aparece rápido y se disipa suave (sube y baja en lugar de apagarse en línea recta).
		var opacidad := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.25, 1.0, t))
		var c := color
		c.a *= opacidad
		var r: float = (m.radio + crecimiento * sqrt(t)) * m.giro
		draw_texture_rect(_textura, Rect2(to_local(m.pos) - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
