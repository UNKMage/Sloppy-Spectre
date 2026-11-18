class_name PixelCaja
extends StyleBox
## Caja de interfaz en pixel art: esquinas escalonadas (nada redondeado), bordes duros,
## luz arriba y sombra abajo, sombra proyectada sólida (sin degradados ni resplandor).
## Se usa como StyleBox de botones y paneles: boton.add_theme_stylebox_override("normal", PixelCaja.nueva(...)).

var relleno := Color(0.07, 0.06, 0.13)
var borde := Color.WHITE
## Segundo borde interior (alfa 0 = sin él). Da el aspecto de marco doble.
var borde_interno := Color(0, 0, 0, 0)
var sombra := Color(0, 0, 0, 0.6)
## Marcas en las esquinas, para el elemento seleccionado.
var esquinas := false
## Tamaño de un "pixel" de la interfaz.
var unidad := 4.0


static func nueva(p_relleno: Color, p_borde: Color, p_borde_interno := Color(0, 0, 0, 0), p_esquinas := false) -> PixelCaja:
	var c := PixelCaja.new()
	c.relleno = p_relleno
	c.borde = p_borde
	c.borde_interno = p_borde_interno
	c.esquinas = p_esquinas
	return c


func _rect(ci: RID, r: Rect2, color: Color) -> void:
	if r.size.x > 0.0 and r.size.y > 0.0:
		RenderingServer.canvas_item_add_rect(ci, r, color)


## Rectángulo con las 4 esquinas "mordidas" un pixel: el borde de pixel art.
func _forma(ci: RID, r: Rect2, color: Color) -> void:
	var u := unidad
	_rect(ci, Rect2(r.position.x + u, r.position.y, r.size.x - 2.0 * u, r.size.y), color)
	_rect(ci, Rect2(r.position.x, r.position.y + u, r.size.x, r.size.y - 2.0 * u), color)


func _draw(ci: RID, r: Rect2) -> void:
	var u := unidad
	r = Rect2(r.position.round(), r.size.round())
	if sombra.a > 0.0:
		_forma(ci, Rect2(r.position + Vector2(u, u), r.size), sombra)
	_forma(ci, r, borde)
	var dentro := r.grow(-u)
	if borde_interno.a > 0.0:
		_forma(ci, dentro, borde_interno)
		dentro = dentro.grow(-u)
	_forma(ci, dentro, relleno)
	# Luz arriba y sombra abajo, como un bisel.
	_rect(ci, Rect2(dentro.position.x + u, dentro.position.y, dentro.size.x - 2.0 * u, u), relleno.lightened(0.18))
	_rect(ci, Rect2(dentro.position.x + u, dentro.end.y - u, dentro.size.x - 2.0 * u, u), relleno.darkened(0.3))
	if esquinas:
		var largo := 3.0 * u
		var o := u * 1.5
		var fuera := r.grow(o)
		var col := Color.WHITE
		for esq in [[fuera.position, 1.0, 1.0], [Vector2(fuera.end.x, fuera.position.y), -1.0, 1.0],
				[Vector2(fuera.position.x, fuera.end.y), 1.0, -1.0], [fuera.end, -1.0, -1.0]]:
			var p: Vector2 = esq[0]
			var sx: float = esq[1]
			var sy: float = esq[2]
			_rect(ci, Rect2(p, Vector2(largo * sx, u * sy)).abs(), col)
			_rect(ci, Rect2(p, Vector2(u * sx, largo * sy)).abs(), col)
