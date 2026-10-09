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

@export_group("Linterna")
## Si es false, la linterna está apagada y no aturde.
@export var linterna_encendida: bool = true
## Apertura total del cono de luz, en grados.
@export_range(10.0, 180.0, 1.0) var angulo_cono_grados: float = 60.0
## Alcance de la luz, en píxeles.
@export var alcance_linterna: float = 220.0
## Capas físicas que bloquean la luz (por defecto la capa 3, "paredes").
@export_flags_2d_physics var mascara_obstaculos: int = 4
## Qué tan rápido gira la linterna hacia donde camina (más alto = gira más rápido).
@export var suavidad_giro_linterna: float = 10.0

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
## Hacia dónde apunta la linterna (se actualiza según el movimiento).
var direccion_mirada: Vector2 = Vector2.DOWN
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
		_intentar_aturdir()

	# SCRUM-09: la linterna aturde a Spooky si lo alumbra.
	_actualizar_direccion_mirada(delta)
	if linterna_encendida and _spooky_en_cono_de_luz():
		_intentar_aturdir()
	match estado:
		Estado.PATRULLANDO:
			_patrullar()
		Estado.PERSIGUIENDO:
			_perseguir(delta)
		Estado.ASPIRANDO:
			_aspirar(delta)
	_mover_por_la_ruta()

## Aturde a Spooky (3 s, lo hace su propio script) salvo que ya esté aturdido o inmune.
## Es la misma lógica que ya usaba el contacto directo, ahora compartida con la linterna.
func _intentar_aturdir() -> void:
	if _jugador and _jugador.has_method("aplicar_aturdimiento") and not _jugador.get("inmune") and _jugador.get("movimiento_habilitado"):
		_jugador.aplicar_aturdimiento()
		cambiar_estado(Estado.ASPIRANDO)


## La linterna apunta hacia donde se mueve el Limpiador; si está quieto, conserva la última dirección.
func _actualizar_direccion_mirada(delta: float) -> void:
	if velocity.length() < 5.0:
		return
	var angulo := lerp_angle(direccion_mirada.angle(), velocity.angle(), clampf(suavidad_giro_linterna * delta, 0.0, 1.0))
	direccion_mirada = Vector2.from_angle(angulo)
	queue_redraw()  # el cono dibujado sigue a la linterna


## ¿Está Spooky dentro del cono de luz? Revisa alcance, ángulo y que ninguna pared tape la luz.
func _spooky_en_cono_de_luz() -> bool:
	# El Portal es zona segura: dentro de él la linterna no lo detecta.
	if _jugador == null or _jugador_en_portal:
		return false

	var hacia_spooky := _jugador.global_position - global_position
	var distancia := hacia_spooky.length()
	if distancia > alcance_linterna:
		return false

	# Ángulo entre hacia dónde mira la linterna y hacia dónde está Spooky.
	if distancia > 0.001:
		var mitad_cono := deg_to_rad(angulo_cono_grados) * 0.5
		if absf(direccion_mirada.angle_to(hacia_spooky)) > mitad_cono:
			return false

	return _luz_sin_obstaculos()


## Rayo del Limpiador a Spooky: si choca con una pared, la luz no llega.
## Solo se ejecuta cuando Spooky ya está dentro del alcance y del ángulo (barato).
func _luz_sin_obstaculos() -> bool:
	if mascara_obstaculos == 0:
		return true
	var consulta := PhysicsRayQueryParameters2D.create(global_position, _jugador.global_position, mascara_obstaculos)
	consulta.exclude = [get_rid()]  # que el rayo no choque con el propio Limpiador
	return get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()


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
	if linterna_encendida:
		_dibujar_cono()

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


## Dibuja el cono de luz (provisional, hasta que haya arte).
func _dibujar_cono() -> void:
	var mitad_cono := deg_to_rad(angulo_cono_grados) * 0.5
	var centro := direccion_mirada.angle()
	var puntos := PackedVector2Array([Vector2.ZERO])
	for i in range(17):
		var angulo := centro - mitad_cono + (mitad_cono * 2.0) * i / 16.0
		puntos.append(Vector2.from_angle(angulo) * alcance_linterna)
	draw_colored_polygon(puntos, Color(1.0, 0.95, 0.5, 0.22))
	draw_polyline(PackedVector2Array([puntos[1], Vector2.ZERO, puntos[17]]), Color(1.0, 0.95, 0.5, 0.6), 1.5)
