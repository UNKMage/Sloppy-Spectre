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
