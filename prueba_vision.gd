extends SceneTree
## Pruebas headless del cono de visión.
## Uso: godot --headless --path . -s prueba_vision.gd

var _fallos := 0


func _initialize() -> void:
	_correr()


func _comprobar(condicion: bool, texto: String) -> void:
	print(("OK   " if condicion else "FALLA ") + texto)
	if not condicion:
		_fallos += 1


func _cargar(ruta: String) -> Node:
	var escena: Node = (load(ruta) as PackedScene).instantiate()
	root.add_child(escena)
	current_scene = escena
	for i in 10:
		await physics_frame
	return escena


func _descargar(escena: Node) -> void:
	escena.queue_free()
	await physics_frame
	await physics_frame


func _mover_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	root.push_input(ev)
	root.warp_mouse(pos)
	for i in 6:
		await physics_frame
	print("   mouse: ", root.get_mouse_position(), " ghost: ", get_first_node_in_group("jugador").global_position)


func _material(nodo: Node) -> ShaderMaterial:
	return (nodo as CanvasItem).material as ShaderMaterial


func _correr() -> void:
	# --- nivel 3 ---
	var n3 := await _cargar("res://nivel_3.tscn")
	var ghost := n3.get_node("ghost") as Area2D
	var vision := ghost.get_node("Vision") as VisionCono

	var m_suelo := _material(n3.get_node("Suelo/CapaSuelo"))
	var m_ecto := _material(n3.get_node("Suelo/CapaEctoplasma"))
	_comprobar(m_suelo != null and m_suelo.get_shader_parameter("opacidad_fuera") == 1.0, "CapaSuelo con material de sombra")
	_comprobar(m_ecto != null and m_ecto.get_shader_parameter("opacidad_fuera") == 0.0, "CapaEctoplasma con material de ocultar")

	var enemigos := get_nodes_in_group("enemigos")
	var todos_con_material := true
	for e in enemigos:
		if (e as CanvasItem).material == null:
			todos_con_material = false
	_comprobar(enemigos.size() == 3 and todos_con_material, "3 enemigos con material (hay %d)" % enemigos.size())

	var sin_material := true
	for p in get_nodes_in_group("paredes"):
		if (p as CanvasItem).material != null:
			sin_material = false
	var portal := n3.get_node_or_null("Portal") as CanvasItem
	_comprobar(sin_material, "paredes sin material")
	_comprobar(portal != null and portal.material == null, "Portal sin material")
	_comprobar(ghost.material == null, "ghost sin material")

	ghost.global_position = Vector2(660, 324)
	await _mover_mouse(Vector2(1000, 324))
	_comprobar(absf(vision._distancias[VisionCono.RAYOS / 2] - 60.0) < 8.0,
		"mouse a la derecha: rayo central ~60 (%.1f)" % vision._distancias[VisionCono.RAYOS / 2])

	await _mover_mouse(Vector2(100, 324))
	_comprobar(absf(absf(rad_to_deg(vision._angulo)) - 180.0) < 5.0, "mouse a la izquierda: ángulo ~180° (%.1f)" % rad_to_deg(vision._angulo))
	_comprobar(absf(vision._distancias[VisionCono.RAYOS / 2] - 220.0) < 8.0,
		"mouse a la izquierda: rayo central ~220 (%.1f)" % vision._distancias[VisionCono.RAYOS / 2])
	for i in 90:
		await physics_frame
	await _descargar(n3)

	# --- main sin paredes ---
	var n1 := await _cargar("res://main.tscn")
	var g1 := n1.get_node("ghost") as Area2D
	var v1 := g1.get_node("Vision") as VisionCono
	g1.global_position = Vector2(300, 400)
	await _mover_mouse(Vector2(900, 400))
	_comprobar(is_equal_approx(v1._distancias[VisionCono.RAYOS / 2], v1.alcance),
		"main: rayo central = alcance (%.1f)" % v1._distancias[VisionCono.RAYOS / 2])
	for i in 90:
		await physics_frame
	await _descargar(n1)

	# --- nivel 2 ---
	var n2 := await _cargar("res://nivel_2.tscn")
	for i in 90:
		await physics_frame
	_comprobar(true, "nivel_2 corre 90 fotogramas (revisa la consola por errores)")
	await _descargar(n2)

	print("Fallos: ", _fallos)
	quit(1 if _fallos > 0 else 0)
