class_name EfectosParticulas
extends Node2D
## Efectos de partículas que acompañan a Spooky (viven como hijo suyo, así están en todos los niveles):
##   - motas de espíritu flotando por todo el nivel (ambiente),
##   - salpicadura de gotas verdes al soltar ectoplasma,
##   - estrellitas girando sobre Spooky mientras está aturdido.

@export_group("Ambiente")
## Cuántas motas flotan por el nivel (0 = sin ambiente).
@export var motas_ambiente: int = 36
## Zona del nivel que cubren las motas (la pantalla).
@export var area_nivel: Rect2 = Rect2(0, 0, 1152, 648)
@export_group("Ectoplasma")
## Gotas por cada mancha nueva.
@export var gotas_por_mancha: int = 10

var _ghost: Node
var _estrellas: CPUParticles2D
var _suelo: Node


func _ready() -> void:
	_ghost = get_parent()
	_crear_ambiente()
	_crear_estrellas()
	await get_tree().physics_frame
	_suelo = get_tree().get_first_node_in_group("suelo")
	if _suelo and _suelo.has_signal("celda_pintada"):
		_suelo.celda_pintada.connect(_on_celda_pintada)


func _process(_delta: float) -> void:
	if _estrellas and _ghost:
		_estrellas.global_position = (_ghost as Node2D).global_position + Vector2(0.0, -34.0)
		var aturdido = _ghost.get("movimiento_habilitado") == false
		_estrellas.emitting = aturdido


func _rampa(color: Color, pico: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, pico),
		Color(color.r, color.g, color.b, 0.0),
	])
	return g


func _crear_ambiente() -> void:
	if motas_ambiente <= 0:
		return
	var p := CPUParticles2D.new()
	p.top_level = true  # se queda quieto en el nivel, no sigue a Spooky
	p.global_position = area_nivel.get_center()
	p.z_index = 4
	p.amount = motas_ambiente
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area_nivel.size * 0.5
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = _rampa(Color(0.75, 0.9, 1.0), 0.4)
	add_child(p)


func _crear_estrellas() -> void:
	_estrellas = CPUParticles2D.new()
	_estrellas.top_level = true  # no hereda el oscurecido de Spooky aturdido
	_estrellas.z_index = 8
	_estrellas.emitting = false
	_estrellas.amount = 8
	_estrellas.lifetime = 0.9
	_estrellas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_estrellas.emission_sphere_radius = 16.0
	_estrellas.direction = Vector2(0.0, -1.0)
	_estrellas.spread = 40.0
	_estrellas.gravity = Vector2.ZERO
	_estrellas.initial_velocity_min = 4.0
	_estrellas.initial_velocity_max = 10.0
	_estrellas.tangential_accel_min = 60.0
	_estrellas.tangential_accel_max = 90.0
	_estrellas.scale_amount_min = 3.0
	_estrellas.scale_amount_max = 5.0
	_estrellas.color_ramp = _rampa(Color(1.0, 0.92, 0.45), 1.0)
	add_child(_estrellas)


func _on_celda_pintada(celda: Vector2i, _total: int) -> void:
	var capa := _suelo.get_node("CapaSuelo") as TileMapLayer
	var p := CPUParticles2D.new()
	p.top_level = true
	p.global_position = capa.to_global(capa.map_to_local(celda))
	p.z_index = 6
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = gotas_por_mancha
	p.lifetime = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2(0.0, 160.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = _rampa(Color(0.3, 0.95, 0.35), 0.9)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
