class_name PuertaSalida
extends Area2D

## Ruta de la escena del siguiente nivel (ej: res://nivel_2.tscn)
@export var siguiente_nivel_ruta: String = "res://nivel_2.tscn"

const ESCENA_PANTALLA_CARGA := preload("res://pantalla_carga.tscn")

var activa: bool = false
var _tiempo: float = 0.0
var _jugador: Node2D = null


func _ready() -> void:
	add_to_group("puerta_salida")
	z_index = 1
	
	visible = false
	monitoring = false
	monitorable = false
	
	# Permite hacer clic directamente con el ratón
	input_pickable = true
	input_event.connect(_on_input_event)
	
	body_entered.connect(_on_body_or_area_entered)
	area_entered.connect(_on_body_or_area_entered)


func _process(delta: float) -> void:
	if not activa:
		return
	
	_tiempo += delta
	queue_redraw()
	# El marco aparece poco a poco y la etiqueta "ENTRA" flota y brilla para llamar la atención.
	var marco := get_node_or_null("Sprite2D") as CanvasItem
	if marco:
		marco.modulate.a = ease(clampf(_tiempo / 1.3, 0.0, 1.0), -2.0)
	var etiqueta := get_node_or_null("ENTRA") as Label
	if etiqueta:
		if _etiqueta_y == 0.0:
			_etiqueta_y = etiqueta.position.y
		etiqueta.position.y = _etiqueta_y + sin(_tiempo * 3.0) * 3.0
		etiqueta.modulate = Color(0.8, 0.95, 1.0).lerp(Color(1.0, 1.0, 1.0), 0.5 + 0.5 * sin(_tiempo * 4.0))

	# Buscar a Spooky en la escena
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador")
		if _jugador == null and get_tree().current_scene:
			_jugador = get_tree().current_scene.find_child("ghost", true, false)

	# Detección por proximidad directa (radio amplio de 120 px para que no falle por desalineación)
	if _jugador:
		# Calculamos la distancia hacia la puerta o hacia cualquiera de sus hijos visuales
		var pos_referencia := global_position
		var sprite := find_child("*Sprite*", true, false) as Node2D
		if sprite:
			pos_referencia = sprite.global_position
			
		if pos_referencia.distance_to(_jugador.global_position) <= 120.0:
			ir_al_siguiente_nivel()


func activar_puerta() -> void:
	if activa:
		return
	activa = true
	visible = true
	monitoring = true
	monitorable = true
	
	# Eliminar a los limpiadores
	var enemigos = get_tree().get_nodes_in_group("limpiador")
	for enemigo in enemigos:
		enemigo.queue_free()
	if get_tree().current_scene:
		for hijo in get_tree().current_scene.get_children():
			if "limpiador" in hijo.name.to_lower():
				hijo.queue_free()


func _on_body_or_area_entered(entidad: Node2D) -> void:
	if not activa:
		return
	if entidad.is_in_group("jugador") or entidad.name.to_lower() == "ghost":
		ir_al_siguiente_nivel()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not activa:
		return
	# Si el jugador hace clic sobre la puerta, entra de inmediato
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		ir_al_siguiente_nivel()


func ir_al_siguiente_nivel() -> void:
	activa = false
	set_deferred("monitoring", false)
	
	print(">>> ¡ENTRANDO AL SIGUIENTE NIVEL! Destino: ", siguiente_nivel_ruta)
	
	get_tree().paused = false
	
	if siguiente_nivel_ruta == "" or siguiente_nivel_ruta == null:
		get_tree().change_scene_to_file("res://menu_principal.tscn")
		return

	# Si existe la pantalla de carga la usamos, de lo contrario cambiamos directo
	if ResourceLoader.exists("res://pantalla_carga.tscn"):
		var pantalla = ESCENA_PANTALLA_CARGA.instantiate()
		get_tree().root.add_child(pantalla)
		pantalla.iniciar_carga(siguiente_nivel_ruta)
	else:
		get_tree().change_scene_to_file(siguiente_nivel_ruta)


## --- Arte animado de la puerta (pixel art dibujado en código) ---
## El marco es la imagen puerta_espiritual.png (umbral transparente); aquí se dibuja detrás
## la energía del umbral, el resplandor en el suelo, las runas y las motas que invitan a entrar.
const CX := 32  # centro del arco en la cuadrícula de la imagen (64x64 celdas de 2 px)
const GRID := 2.0
const PALETA: Array[Color] = [
	Color("1b1040"), Color("2d1b6b"), Color("4b2fa0"), Color("7a5ce6"), Color("8feaff"),
]
const CIAN := Color(0.56, 0.92, 1.0)
var _etiqueta_y: float = 0.0


func _en_umbral(x: int, y: int) -> bool:
	if y > 56 or y < 10:
		return false
	if y >= 24:
		return absi(x - CX) <= 13
	return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(CX + 0.5, 24.5)) <= 13.5


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func _draw() -> void:
	if not activa:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var c := sprite.position
	var s := sprite.scale.x
	var aparece := ease(clampf(_tiempo / 1.3, 0.0, 1.0), -2.0)
	var pulso := 0.5 + 0.5 * sin(_tiempo * 2.4)
	# Local de una celda de la imagen: la imagen mide 128x128 y está centrada en el sprite.
	var celda := func(gx: float, gy: float) -> Vector2:
		return c + Vector2((gx + 0.5) * GRID - 64.0, (gy + 0.5) * GRID - 64.0) * s

	# Resplandor en el suelo, frente a la puerta.
	draw_set_transform(celda.call(CX, 60), 0.0, Vector2(1.0, 0.32))
	for i in 5:
		draw_circle(Vector2.ZERO, (78.0 - i * 12.0 + pulso * 5.0) * s, Color(0.5, 0.4, 1.0, (0.05 + i * 0.016) * aparece))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Halo detrás del arco.
	for i in 4:
		draw_circle(celda.call(CX, 32), (74.0 - i * 10.0 + pulso * 4.0) * s, Color(0.45, 0.35, 0.95, (0.035 + i * 0.012) * aparece))

	# Energía del umbral: corrientes que suben, brillo abajo y chispas. Se "llena" desde abajo al aparecer.
	var limite := 57.0 - aparece * 47.0
	for gy in range(10, 57):
		if gy < limite:
			continue
		for gx in range(CX - 14, CX + 15):
			if not _en_umbral(gx, gy):
				continue
			var nx := (gx - CX) / 13.0
			var ny := (gy - 10.0) / 46.0
			var flujo := sin(gx * 0.45 + sin(gy * 0.17 - _tiempo * 2.2) * 1.6 + _tiempo * 0.8) * 0.5 + 0.5
			var v := flujo * 0.4 + (1.0 - nx * nx) * 0.5 * (0.4 + 0.6 * ny) + pulso * 0.08
			v += exp(-pow((gy - 55.0) / 9.0, 2.0)) * 0.35 * (1.0 - absf(nx) * 0.7)
			v += (_hash(gx, gy + int(_tiempo * 2.0)) - 0.5) * 0.07
			var color := PALETA[clampi(int(v * 4.2), 0, 4)]
			if _hash(gx + int(_tiempo * 5.0), gy) > 0.992:
				color = Color.WHITE
			var p: Vector2 = celda.call(gx, gy)
			draw_rect(Rect2(p - Vector2(GRID, GRID) * s * 0.5, Vector2(GRID, GRID) * s), color)

	# Runas del arco que se encienden en secuencia.
	for k in 9:
		var a := PI + (k + 0.5) * PI / 9.0
		var brillo := 0.5 + 0.5 * sin(_tiempo * 3.0 - k * 0.7)
		var p: Vector2 = celda.call(CX + cos(a) * 17.5, 23.5 + sin(a) * 17.5)
		draw_rect(Rect2(p - Vector2(2.0, 2.0) * s, Vector2(4.0, 4.0) * s), Color(CIAN.r, CIAN.g, CIAN.b, (0.3 + brillo * 0.7) * aparece))
	var clave: Vector2 = celda.call(CX, 5)
	var bc := 0.6 + 0.4 * pulso
	draw_rect(Rect2(clave - Vector2(1.0, 4.0) * s, Vector2(2.0, 8.0) * s), Color(CIAN.r, CIAN.g, CIAN.b, bc * aparece))
	draw_rect(Rect2(clave - Vector2(4.0, 1.0) * s, Vector2(8.0, 2.0) * s), Color(CIAN.r, CIAN.g, CIAN.b, bc * aparece))

	# Llamitas espirituales en los farolillos.
	for lado in [-1, 1]:
		var f: Vector2 = celda.call(CX + lado * 28, 50.5)
		var parpadeo := 0.7 + 0.3 * sin(_tiempo * 9.0 + lado * 2.0) + (_hash(int(_tiempo * 12.0), lado + 3) - 0.5) * 0.3
		draw_circle(f, 14.0 * s * parpadeo, Color(0.5, 0.4, 1.0, 0.18 * aparece))
		draw_rect(Rect2(f - Vector2(2.0, 3.0) * s * parpadeo, Vector2(4.0, 6.0) * s * parpadeo), Color(0.75, 0.95, 1.0, aparece))

	# Motas de espíritu que giran hacia el umbral: invitan a entrar.
	var centro_umbral: Vector2 = celda.call(CX, 34)
	for k in 14:
		var fase := fmod(_tiempo * 0.38 + k / 14.0, 1.0)
		var ang := k * 2.4 + fase * 3.2
		var rad := lerpf(120.0, 4.0, fase * fase) * s
		var p2 := centro_umbral + Vector2(cos(ang) * rad, sin(ang) * rad * 0.8)
		p2 = (p2 / 2.0).round() * 2.0
		draw_rect(Rect2(p2 - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0.75, 0.95, 1.0, sin(fase * PI) * 0.9 * aparece))

	# Destello y onda al aparecer.
	if _tiempo < 1.0:
		var t := _tiempo / 1.0
		draw_arc(centro_umbral, lerpf(10.0, 130.0, t), 0.0, TAU, 48, Color(0.7, 0.9, 1.0, (1.0 - t) * 0.8), 4.0)
		draw_circle(centro_umbral, 60.0 * (1.0 - t), Color(1.0, 1.0, 1.0, 0.35 * (1.0 - t)))
