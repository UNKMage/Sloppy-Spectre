class_name SueloManager
extends Node2D

## Se emite cuando cambia la suciedad global de la habitación (para KIBO-17 y KIBO-18)
signal suciedad_actualizada(porcentaje: float, celdas_sucias: int, total_celdas: int)

signal celda_pintada(posicion_mapa: Vector2i, total_celdas_sucias: int)
signal celda_limpiada(posicion_mapa: Vector2i, total_celdas_sucias: int)

@export var source_id: int = 0
@export var atlas_suelo: Vector2i = Vector2i(0, 0)
@export var atlas_ectoplasma: Vector2i = Vector2i(1, 0)
@export var tamano_mapa: Vector2i = Vector2i(29, 17)

## Meta de celdas para el 100%: 120 celdas permite una progresión justa sin llenarse al instante
@export var celdas_para_100: int = 120

var _celdas_sucias: Dictionary = {}
var _total_celdas_suelo: int = 0

@onready var _capa_suelo: TileMapLayer = $CapaSuelo
@onready var _capa_ectoplasma: TileMapLayer = $CapaEctoplasma


func _enter_tree() -> void:
	add_to_group("suelo")


func _ready() -> void:
	if _capa_suelo.get_used_cells().is_empty():
		_rellenar_suelo_provisional()

	# Contar el total de baldosas válidas en el nivel
	_total_celdas_suelo = _capa_suelo.get_used_cells().size()
	if _total_celdas_suelo == 0:
		_total_celdas_suelo = tamano_mapa.x * tamano_mapa.y

	# Registrar si ya existían manchas previas
	for celda: Vector2i in _capa_ectoplasma.get_used_cells():
		_celdas_sucias[celda] = true

	# Emitir estado inicial (0%)
	_actualizar_porcentaje_global()


func pintar(pos_global: Vector2, radio: int = 0) -> int:
	var centro: Vector2i = _capa_suelo.local_to_map(_capa_suelo.to_local(pos_global))
	var nuevas := 0
	for dx in range(-radio, radio + 1):
		for dy in range(-radio, radio + 1):
			if dx * dx + dy * dy > radio * radio + radio:
				continue
			if _pintar_celda(centro + Vector2i(dx, dy)):
				nuevas += 1

	if nuevas > 0:
		_actualizar_porcentaje_global()

	return nuevas


func _pintar_celda(celda: Vector2i) -> bool:
	if _celdas_sucias.has(celda):
		return false
	if _capa_suelo.get_cell_source_id(celda) == -1:
		return false

	_capa_ectoplasma.set_cell(celda, source_id, atlas_ectoplasma)
	_celdas_sucias[celda] = true
	celda_pintada.emit(celda, _celdas_sucias.size())
	return true


func limpiar(pos_global: Vector2) -> void:
	var capa = $CapaEctoplasma
	var pos_local = capa.to_local(pos_global)
	var pos_mapa = capa.local_to_map(pos_local)
	
	if _celdas_sucias.has(pos_mapa):
		_celdas_sucias.erase(pos_mapa)
		capa.erase_cell(pos_mapa)
		celda_limpiada.emit(pos_mapa, _celdas_sucias.size())
		_actualizar_porcentaje_global()


## Cálculo optimizado: proporcional a la meta y sin decimales
func _actualizar_porcentaje_global() -> void:
	if celdas_para_100 <= 0:
		return
	
	var celdas_actuales := _celdas_sucias.size()
	var porcentaje_calculado := (float(celdas_actuales) / float(celdas_para_100)) * 100.0
	var porcentaje_entero := int(clampf(round(porcentaje_calculado), 0.0, 100.0))
	
	suciedad_actualizada.emit(float(porcentaje_entero), celdas_actuales, celdas_para_100)


## Borra el suelo bajo un polígono (en coordenadas globales), por ejemplo el contorno de una pared.
## Se quitan las celdas cuyo CENTRO queda dentro del polígono. Sin suelo no se puede manchar,
## así el Limpiador nunca recibe manchas donde no puede entrar.
func quitar_suelo(contorno_global: PackedVector2Array) -> void:
	var minimo := contorno_global[0]
	var maximo := minimo
	for punto in contorno_global:
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
	var primera := _capa_suelo.local_to_map(_capa_suelo.to_local(minimo))
	var ultima := _capa_suelo.local_to_map(_capa_suelo.to_local(maximo))
	for x in range(primera.x, ultima.x + 1):
		for y in range(primera.y, ultima.y + 1):
			var celda := Vector2i(x, y)
			var centro := _capa_suelo.to_global(_capa_suelo.map_to_local(celda))
			if Geometry2D.is_point_in_polygon(centro, contorno_global):
				_capa_suelo.erase_cell(celda)


func _rellenar_suelo_provisional() -> void:
	for x in tamano_mapa.x:
		for y in tamano_mapa.y:
			_capa_suelo.set_cell(Vector2i(x, y), source_id, atlas_suelo)


func obtener_posicion_sucia_mas_cercana(origen_global: Vector2) -> Variant:
	if _celdas_sucias.is_empty():
		return null
		
	var capa = $CapaEctoplasma
	var pos_mapa_origen = capa.local_to_map(capa.to_local(origen_global))
	
	var celda_mas_cercana: Vector2i
	var distancia_minima = INF
	
	for celda in _celdas_sucias.keys():
		var dist = Vector2(pos_mapa_origen).distance_squared_to(Vector2(celda))
		if dist < distancia_minima:
			distancia_minima = dist
			celda_mas_cercana = celda
			
	var pos_local = capa.map_to_local(celda_mas_cercana)
	return capa.to_global(pos_local)
