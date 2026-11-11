class_name EctoplasmaVisual
extends Node2D
## Dibuja el ectoplasma como manchas orgánicas (con variantes y brillo leve):
## la mancha es un poco más grande que la celda, así los bordes no se ven cuadrados.
## Solo es visual: el conteo de celdas sigue en SueloManager y en CapaEctoplasma.
## Es un Node2D normal: un CanvasGroup rompía el shader de visión (pintaba un rectángulo).

## Cuántas variantes de mancha se generan.
const VARIANTES_MANCHA := 5
const TAM_TEXTURA := 64

@export_group("Mancha")
## Tamaño de la mancha en píxeles (la celda mide 40).
@export var tamano_mancha: float = 56.0

var _suelo: Node
var _capa_suelo: TileMapLayer
var _manchas: Dictionary = {}  # celda -> Array de [textura, posición, rotación, escala (Vector2)]
static var _tex_manchas: Array[Texture2D] = []


func iniciar(suelo: Node, capa_ectoplasma: TileMapLayer) -> void:
	_suelo = suelo
	_capa_suelo = suelo.get_node("CapaSuelo")
	if _tex_manchas.is_empty():
		for i in VARIANTES_MANCHA:
			_tex_manchas.append(_crear_textura(1000 + i * 37))
	# Manchas que ya existieran al empezar el nivel.
	for celda: Vector2i in capa_ectoplasma.get_used_cells():
		_agregar(celda)
	suelo.celda_pintada.connect(func(celda: Vector2i, _total: int) -> void: _agregar(celda))
	suelo.celda_limpiada.connect(func(celda: Vector2i, _total: int) -> void: _quitar(celda))
	queue_redraw()


func _centro(celda: Vector2i) -> Vector2:
	return _capa_suelo.position + _capa_suelo.map_to_local(celda)


func _agregar(celda: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(celda) + 7919
	var centro := _centro(celda)
	var items: Array = []
	var escala := rng.randf_range(0.9, 1.12)
	items.append([_tex_manchas[rng.randi() % VARIANTES_MANCHA], centro + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)),
		rng.randf() * TAU, Vector2(escala, escala) * tamano_mancha])
	_manchas[celda] = items
	queue_redraw()


func _quitar(celda: Vector2i) -> void:
	if _manchas.erase(celda):
		queue_redraw()


func _draw() -> void:
	for celda in _manchas:
		for it in _manchas[celda]:
			var tam: Vector2 = it[3]
			draw_set_transform(it[1], it[2], Vector2.ONE)
			draw_texture_rect(it[0], Rect2(-tam * 0.5, tam), false)


## Textura de una mancha: contorno irregular, color más oscuro en el borde y claro al centro,
## borde brillante y un brillo leve.
static func _crear_textura(semilla: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var amp: Array[float] = []
	var fase: Array[float] = []
	for k in range(2, 8):
		amp.append(rng.randf_range(0.02, 0.2) / (k * 0.55))
		fase.append(rng.randf() * TAU)
	var oscuro := Color(0.0, 0.42, 0.05)
	var claro := Color(0.2, 0.88, 0.25)
	var img := Image.create(TAM_TEXTURA, TAM_TEXTURA, false, Image.FORMAT_RGBA8)
	for y in TAM_TEXTURA:
		for x in TAM_TEXTURA:
			var p := Vector2((x + 0.5) / TAM_TEXTURA * 2.0 - 1.0, (y + 0.5) / TAM_TEXTURA * 2.0 - 1.0)
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var radio := 0.8
			for i in amp.size():
				radio += 0.8 * amp[i] * cos((i + 2) * ang + fase[i])
			radio = minf(radio, 0.97)
			var d := radio - r
			var alfa := smoothstep(0.0, 0.07, d)
			if alfa <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t := clampf(d / radio, 0.0, 1.0)
			var c := oscuro.lerp(claro, smoothstep(0.0, 0.75, t))
			# borde un poco más claro, como baba húmeda
			var borde := smoothstep(0.02, 0.1, d) * (1.0 - smoothstep(0.1, 0.22, d))
			c = c.lerp(Color(0.55, 1.0, 0.55), borde * 0.28)
			# brillo leve arriba a la izquierda
			var hd := p.distance_squared_to(Vector2(-0.3, -0.34))
			c = c.lerp(Color(0.92, 1.0, 0.92), exp(-hd / 0.02) * 0.5)
			c.a = alfa
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
