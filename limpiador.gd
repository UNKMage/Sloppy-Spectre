extends CharacterBody2D
@export var velocidad: float = 150.0

@export_group("Detección")
## Distancia a la que detecta a Spooky y empieza a perseguirlo.
@export var rango_deteccion: float = 150.0
## Distancia a la que lo pierde. Mayor que la de detección para evitar parpadeos.
@export var rango_perdida: float = 300.0
## Segundos que sigue hacia el último punto donde lo vio antes de rendirse.
@export var memoria: float = 1.5

@export_group("Persecución")
## Cada cuántos segundos recalcula a dónde ir (no hace falta cada fotograma).
@export var intervalo_decision: float = 0.4
## Qué tan adelante apunta, en segundos del movimiento de Spooky. 0 = va directo a él.
@export var anticipacion: float = 0.6

@export_group("Depuración")
## Dibuja los círculos de detección y pérdida alrededor del Limpiador.
@export var mostrar_rangos: bool = true

@export_group("Limpieza")
## Segundos que tarda en limpiar una mancha al llegar a ella
@export var tiempo_por_mancha: float = 1.0

var _temporizador_aspirado: float = 0.0
var _destino_sucia_actual: Variant = null

var _jugador_en_portal: bool = false
@onready var _portal := get_parent().get_node_or_null("Portal")

@onready var _suelo := get_tree().get_first_node_in_group("suelo") as Node2D

enum Estado { PATRULLANDO, PERSIGUIENDO, ASPIRANDO }

var estado: Estado = Estado.PATRULLANDO
var _tiempo_decision: float = 0.0
var _tiempo_sin_ver: float = 0.0
var _navegacion_lista: bool = false

@onready var _agente: NavigationAgent2D = $NavigationAgent2D
@onready var _jugador := get_tree().get_first_node_in_group("jugador") as Node2D

#Espera dos fotogramas antes de pedir las rutas, en caso de latencia al sincronizar
func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_navegacion_lista = true
	
	if _portal:
		_portal.jugador_entro.connect(_on_jugador_entro_portal)
		_portal.jugador_salio.connect(_on_jugador_salio_portal)

func _on_jugador_entro_portal(param = null) -> void:
	_jugador_en_portal = true

func _on_jugador_salio_portal(param = null) -> void:
	_jugador_en_portal = false

func ir_a(destino: Vector2) -> void:
	_agente.target_position = destino

func _physics_process(delta: float) -> void:
	if not _navegacion_lista:
		return
	if _jugador and _distancia_al_jugador() <= 30.0:
		if _jugador.has_method("aplicar_aturdimiento") and not _jugador.get("inmune") and _jugador.get("movimiento_habilitado"):
			_jugador.aplicar_aturdimiento()
			cambiar_estado(Estado.ASPIRANDO)
	match estado:
		Estado.PATRULLANDO:
			_patrullar()
		Estado.PERSIGUIENDO:
			_perseguir(delta)
		Estado.ASPIRANDO:
			_aspirar(delta)
	_mover_por_la_ruta()

func cambiar_estado(nuevo: Estado) -> void:
	if nuevo == estado:
		return
	estado = nuevo
	_tiempo_decision = 0.0
	_tiempo_sin_ver = 0.0
	_destino_sucia_actual = null # <-- LÍNEA NUEVA
	print("Limpiador -> ", Estado.keys()[estado])
	queue_redraw()


func _patrullar() -> void:
	# Ignorar a Spooky si es inmune
	if _jugador and _jugador.get("movimiento_habilitado") and not _jugador.get("inmune") and _distancia_al_jugador() <= rango_deteccion:
		cambiar_estado(Estado.PERSIGUIENDO)
		return

	# Si hay suciedad, pasa a limpiar por iniciativa propia
	if _suelo and _suelo.obtener_posicion_sucia_mas_cercana(global_position) != null:
		cambiar_estado(Estado.ASPIRANDO)
		return

	if _agente.is_navigation_finished():
		ir_a(_punto_al_azar())


func _perseguir(delta: float) -> void:
	if _jugador == null:
		cambiar_estado(Estado.PATRULLANDO)
		return

	if _distancia_al_jugador() <= rango_perdida:
		_tiempo_sin_ver = 0.0
	else:
		_tiempo_sin_ver += delta
		if _tiempo_sin_ver >= memoria:
			# Lo perdió y agotó la memoria. Decide si limpia o patrulla.
			if _suelo and _suelo.obtener_posicion_sucia_mas_cercana(global_position) != null:
				cambiar_estado(Estado.ASPIRANDO)
			else:
				cambiar_estado(Estado.PATRULLANDO)
		return

	_tiempo_decision -= delta
	if _tiempo_decision > 0.0:
		return
	_tiempo_decision = intervalo_decision
	ir_a(_predecir_posicion())

	_tiempo_decision -= delta
	if _tiempo_decision > 0.0:
		return
	_tiempo_decision = intervalo_decision
	ir_a(_predecir_posicion())

func _distancia_al_jugador() -> float:
	# Si está en el portal, lo consideramos infinitamente lejos para que lo ignore/pierda
	if _jugador_en_portal:
		return INF
		
	return global_position.distance_to(_jugador.global_position)


func _punto_al_azar() -> Vector2:
	var area := get_viewport_rect().grow(-60.0)
	return Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


# Apunta a donde Spooky estará, no a donde está.
func _predecir_posicion() -> Vector2:
	var velocidad_jugador: Vector2 = _jugador.get("velocidad")
	return _jugador.global_position + velocidad_jugador * anticipacion

func _aspirar(delta: float) -> void:
	# Si vemos a Spooky Y NO es inmune, interrumpimos la limpieza
	if _jugador and _jugador.get("movimiento_habilitado") and not _jugador.get("inmune") and _distancia_al_jugador() <= rango_deteccion:
		cambiar_estado(Estado.PERSIGUIENDO)
		return

	# 1. Buscar una mancha si no tenemos una asignada
	if _destino_sucia_actual == null:
		_destino_sucia_actual = _suelo.obtener_posicion_sucia_mas_cercana(global_position)
		
		# Si ya no quedan manchas, volvemos a patrullar
		if _destino_sucia_actual == null:
			cambiar_estado(Estado.PATRULLANDO)
			return
			
		ir_a(_destino_sucia_actual)
		_temporizador_aspirado = tiempo_por_mancha

	# 2. Si ya llegamos a la mancha, contamos el tiempo y la limpiamos
	if _agente.is_navigation_finished():
		_temporizador_aspirado -= delta
		if _temporizador_aspirado <= 0.0:
			_suelo.limpiar(_destino_sucia_actual)
			_destino_sucia_actual = null # Reseteamos para que busque la siguiente en el próximo frames

func _mover_por_la_ruta() -> void:
	if _agente.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var siguiente := _agente.get_next_path_position()
		velocity = global_position.direction_to(siguiente) * velocidad
	move_and_slide()

func _draw() -> void:
	var color: Color
	match estado:
		Estado.PATRULLANDO:
			color = Color(0.95, 0.75, 0.15)
		Estado.PERSIGUIENDO:
			color = Color(0.95, 0.25, 0.2)
		Estado.ASPIRANDO:
			color = Color(0.2, 0.6, 0.95)
	draw_circle(Vector2.ZERO, 14.0, color)

	if mostrar_rangos:
		draw_arc(Vector2.ZERO, rango_deteccion, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
		draw_arc(Vector2.ZERO, rango_perdida, 0.0, TAU, 64, Color(1, 0.4, 0.4, 0.2), 1.0)
