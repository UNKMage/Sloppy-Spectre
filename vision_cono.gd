class_name VisionCono
extends Node2D
## Cono de visión de Spooky: apunta al mouse y, fuera de él, el escenario queda
## bajo una sombra tipo nube. Reparte un shader compartido a suelo, ectoplasma y enemigos.

## Cuántos rayos se lanzan. DEBE coincidir con RAYOS de vision_cono.gdshader.
const RAYOS := 32
const SHADER := preload("res://vision_cono.gdshader")

@export_group("Cono")
## Apertura total del cono, en grados.
@export_range(10.0, 180.0, 1.0) var angulo_cono_grados: float = 70.0
## Alcance de la vista, en píxeles.
@export var alcance: float = 380.0
## Radio del círculo siempre visible bajo Spooky (0 = sin círculo).
@export var radio_cercano: float = 90.0
## Semiancho del cono junto a Spooky, en píxeles (0 = nace en una punta).
@export var ancho_base: float = 60.0
## Capas físicas que tapan la vista (por defecto la capa 3, "paredes").
@export_flags_2d_physics var mascara_obstaculos: int = 4

@export_group("Sombra")
## Brillo fuera del cono. 0 = negro, 1 = sin sombra.
@export_range(0.0, 1.0, 0.01) var brillo_sombra: float = 0.5
## Cuánto varía la oscuridad dentro de la sombra.
@export_range(0.0, 1.0, 0.01) var variacion_sombra: float = 0.25
## Color con el que se tiñe la sombra.
@export var tinte_sombra: Color = Color(0.82, 0.84, 1.0)
## Ancho del degradado del borde, en píxeles.
@export var suavizado_borde: float = 70.0

@export_group("Nube")
## Cuánto deforma el ruido el borde del cono, en píxeles.
@export var irregularidad_px: float = 35.0
## Tamaño de las "bolas" de nube, en píxeles.
@export var tamano_nube_px: float = 90.0
## Velocidad con que se desplaza la nube (0 = quieta).
@export var velocidad_nube: float = 0.08

var _material_suelo: ShaderMaterial
var _material_ocultar: ShaderMaterial
var _distancias := PackedFloat32Array()
var _angulo: float = 0.0
var _angulo_calculado: float = INF
var _pos_calculada: Vector2 = Vector2.INF


func _ready() -> void:
	_distancias.resize(RAYOS + 1)
	_distancias.fill(alcance)
	_material_suelo = _crear_material(brillo_sombra, 1.0)
	_material_ocultar = _crear_material(1.0, 0.0)
	# Esperamos un fotograma para que el nivel esté completo.
	await get_tree().physics_frame
	_repartir_materiales(get_tree().current_scene)
	for enemigo in get_tree().get_nodes_in_group("enemigos"):
		(enemigo as CanvasItem).material = _material_ocultar


func _crear_material(brillo_fuera: float, opacidad_fuera: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("brillo_fuera", brillo_fuera)
	m.set_shader_parameter("opacidad_fuera", opacidad_fuera)
	m.set_shader_parameter("suavizado_px", suavizado_borde)
	m.set_shader_parameter("radio_cercano", radio_cercano)
	m.set_shader_parameter("ancho_base", ancho_base)
	m.set_shader_parameter("nube_irregularidad_px", irregularidad_px)
	m.set_shader_parameter("nube_tamano_px", tamano_nube_px)
	m.set_shader_parameter("nube_velocidad", velocidad_nube)
	m.set_shader_parameter("variacion_sombra", variacion_sombra)
	m.set_shader_parameter("tinte_sombra", tinte_sombra)
	m.set_shader_parameter("media_apertura", deg_to_rad(angulo_cono_grados) * 0.5)
	m.set_shader_parameter("distancias", _distancias)
	return m


func _repartir_materiales(nodo: Node) -> void:
	if nodo is TileMapLayer:
		var capa := nodo as TileMapLayer
		capa.use_parent_material = false
		capa.material = _material_ocultar if capa.name == &"CapaEctoplasma" else _material_suelo
	for hijo in nodo.get_children():
		_repartir_materiales(hijo)


func _physics_process(_delta: float) -> void:
	var hacia_mouse := get_global_mouse_position() - global_position
	if hacia_mouse.length() > 4.0:
		_angulo = hacia_mouse.angle()
	if global_position == _pos_calculada and _angulo == _angulo_calculado:
		return
	_pos_calculada = global_position
	_angulo_calculado = _angulo

	var mitad := deg_to_rad(angulo_cono_grados) * 0.5
	var espacio := get_world_2d().direct_space_state
	for i in range(RAYOS + 1):
		var ang := _angulo - mitad + (mitad * 2.0) * i / RAYOS
		var destino := global_position + Vector2.from_angle(ang) * alcance
		var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, mascara_obstaculos)
		var choque := espacio.intersect_ray(consulta)
		_distancias[i] = global_position.distance_to(choque.position) if not choque.is_empty() else alcance

	for m in [_material_suelo, _material_ocultar]:
		m.set_shader_parameter("origen", global_position)
		m.set_shader_parameter("angulo_centro", _angulo)
		m.set_shader_parameter("distancias", _distancias)
