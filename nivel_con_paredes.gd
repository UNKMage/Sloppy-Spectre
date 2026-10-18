class_name NivelConParedes
extends Node
## Script de los niveles con paredes (2 y 3). Las paredes son nodos `Pared` (pared.tscn) que se
## arrastran en el editor dentro del nodo "Paredes". Al iniciar el nivel, este script:
##   1. Quita el suelo bajo cada pared (ahí no se puede manchar).
##   2. Hornea el mapa de navegación esquivando las paredes (así los Limpiadores no se atoran).
## La colisión de las paredes y el recorte de la luz ya los hace cada Pared por su cuenta.

## Zona por donde pueden caminar los Limpiadores (la pantalla).
@export var area_navegable: Rect2 = Rect2(0, 0, 1152, 648)
## Margen de seguridad alrededor de las paredes. El Limpiador mide 14 de radio: con 20 sobra espacio.
@export var radio_agente: float = 20.0

@onready var _navegacion: NavigationRegion2D = $navegacion
@onready var _suelo: SueloManager = $Suelo


func _ready() -> void:
	var paredes := get_tree().get_nodes_in_group("paredes")
	for nodo in paredes:
		_suelo.quitar_suelo((nodo as Pared).contorno_global())
	_hornear_navegacion(paredes)


## Navegación = "mapa de por dónde se puede caminar". Se hornea con la pantalla como zona
## caminable y cada pared como obstáculo; Godot calcula el resto (y deja el margen radio_agente).
func _hornear_navegacion(paredes: Array[Node]) -> void:
	var poligono := NavigationPolygon.new()
	poligono.agent_radius = radio_agente

	var datos := NavigationMeshSourceGeometryData2D.new()
	datos.add_traversable_outline(_rect_a_contorno(area_navegable))
	for nodo in paredes:
		datos.add_obstruction_outline((nodo as Pared).contorno_global())

	NavigationServer2D.bake_from_source_geometry_data(poligono, datos)
	_navegacion.navigation_polygon = poligono


func _rect_a_contorno(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
