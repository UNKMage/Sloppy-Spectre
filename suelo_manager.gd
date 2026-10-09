class_name SueloManager
extends Node2D
## SCRUM-04: pintado de celdas del TileMap con ectoplasma verde en tiempo real.
## - CapaSuelo (TileMapLayer): suelo base limpio. Solo se lee.
## - CapaEctoplasma (TileMapLayer): manchas. Aquí se pinta.
## Las celdas son de 40 px, igual que TAMANO_CELDA de mancha.gd.

## Se emite cuando una celda NUEVA se tiñe de ectoplasma.
signal celda_pintada(posicion_mapa: Vector2i, total_celdas_sucias: int)
#Se emite cuando una celda se limpia
signal celda_limpiada(posicion_mapa: Vector2i, total_celdas_sucias: int)
## ID de la fuente (atlas) en suelo_tileset.tres.
@export var source_id: int = 0
## Coordenadas del tile de suelo limpio dentro del atlas.
@export var atlas_suelo: Vector2i = Vector2i(0, 0)
## Coordenadas del tile de ectoplasma verde dentro del atlas.
@export var atlas_ectoplasma: Vector2i = Vector2i(1, 0)
## Tamaño (en celdas) del suelo provisional. 29x17 celdas de 40 px cubren la pantalla.
## Solo se usa si CapaSuelo está vacía (cuando haya un mapa dibujado a mano, se ignora).
@export var tamano_mapa: Vector2i = Vector2i(29, 17)

## "Set" de celdas ya manchadas (Vector2i -> true): evita duplicar conteos
## y no obliga a recorrer el mapa para saber cuántas hay.
var _celdas_sucias: Dictionary = {}

@onready var _capa_suelo: TileMapLayer = $CapaSuelo
@onready var _capa_ectoplasma: TileMapLayer = $CapaEctoplasma


func _enter_tree() -> void:
	add_to_group("suelo")  # para que otros nodos lo encuentren sin rutas


func _ready() -> void:
	if _capa_suelo.get_used_cells().is_empty():
		_rellenar_suelo_provisional()

	# Si ya hubiera manchas dibujadas a mano en el editor, se registran.
	for celda: Vector2i in _capa_ectoplasma.get_used_cells():
		_celdas_sucias[celda] = true


## Pinta ectoplasma en la posición global recibida.
## radio 0 = una celda, radio 1 = área de ~3x3.
## Devuelve cuántas celdas NUEVAS se mancharon.
func pintar(pos_global: Vector2, radio: int = 0) -> int:
	var centro: Vector2i = _capa_suelo.local_to_map(_capa_suelo.to_local(pos_global))
	var nuevas := 0
	for dx in range(-radio, radio + 1):
		for dy in range(-radio, radio + 1):
			if dx * dx + dy * dy > radio * radio + radio:
				continue  # recorta esquinas para un pincel redondeado
			if _pintar_celda(centro + Vector2i(dx, dy)):
				nuevas += 1
	return nuevas


func _pintar_celda(celda: Vector2i) -> bool:
	# Ya estaba sucia: no repintar ni contar de nuevo.
	if _celdas_sucias.has(celda):
		return false
	# Solo se mancha donde hay suelo (no fuera del mapa).
	if _capa_suelo.get_cell_source_id(celda) == -1:
		return false

	_capa_ectoplasma.set_cell(celda, source_id, atlas_ectoplasma)
	_celdas_sucias[celda] = true
	celda_pintada.emit(celda, _celdas_sucias.size())
	return true


func _rellenar_suelo_provisional() -> void:
	for x in tamano_mapa.x:
		for y in tamano_mapa.y:
			_capa_suelo.set_cell(Vector2i(x, y), source_id, atlas_suelo)

## Devuelve la posición global del centro de la celda sucia más cercana, o null si está todo limpio.
func obtener_posicion_sucia_mas_cercana(origen_global: Vector2) -> Variant:
	if _celdas_sucias.is_empty():
		return null
		
	# Nota: Asegúrate de que el nombre del nodo sea exactamente $CapaEctoplasma
	var capa = $CapaEctoplasma
	var pos_mapa_origen = capa.local_to_map(capa.to_local(origen_global))
	
	var celda_mas_cercana: Vector2i
	var distancia_minima = INF
	
	# Buscamos iterando las celdas sucias registradas
	for celda in _celdas_sucias.keys():
		var dist = Vector2(pos_mapa_origen).distance_squared_to(Vector2(celda))
		if dist < distancia_minima:
			distancia_minima = dist
			celda_mas_cercana = celda
			
	var pos_local = capa.map_to_local(celda_mas_cercana)
	return capa.to_global(pos_local)

## Borra el ectoplasma de la coordenada global dada y lo quita del registro.
func limpiar(pos_global: Vector2) -> void:
	var capa = $CapaEctoplasma
	var pos_local = capa.to_local(pos_global)
	var pos_mapa = capa.local_to_map(pos_local)
	
	if _celdas_sucias.has(pos_mapa):
		_celdas_sucias.erase(pos_mapa)
		capa.erase_cell(pos_mapa)
		celda_limpiada.emit(pos_mapa, _celdas_sucias.size())
