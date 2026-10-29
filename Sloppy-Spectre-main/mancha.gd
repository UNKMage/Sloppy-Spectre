class_name Mancha
extends Area2D

const TAMANO_CELDA := 40 # Múltiplo de 3 para encajar con los pixeles del fantasma
const COLOR := Color(0.0, 0.77, 0.03)
	
func _draw() -> void:
	var mitad := TAMANO_CELDA / 2.0
	draw_rect(Rect2(-mitad, -mitad, TAMANO_CELDA, TAMANO_CELDA), COLOR)
