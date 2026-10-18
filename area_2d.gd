extends Area2D
@export var mancha_escena: PackedScene

@export_group("Movimiento")
## Velocidad máxima en px/s.
@export var velocidad_maxima: float = 420.0
## Qué tan rápido alcanza la velocidad máxima (px/s²). Más alto = más ágil.
@export var aceleracion: float = 1100.0
## Qué tan rápido se frena al soltar las teclas (px/s²). Más bajo = más "flotante".
@export var desaceleracion: float = 700.0
## Extra de frenado al invertir dirección bruscamente (giros más precisos para esquivar).
@export var factor_giro: float = 1.6

@export_group("Levitación")
## Amplitud del balanceo vertical en píxeles.
@export var bob_amplitud: float = 3.0
## Velocidad del balanceo (rad/s).
@export var bob_velocidad: float = 3.5
## Inclinación máxima del sprite al moverse (grados).
@export var inclinacion_max_grados: float = 10.0
## Suavidad de la inclinación (más alto = reacciona más rápido).
@export var suavidad_inclinacion: float = 8.0

@export_group("Límites")
## Área donde puede moverse. Si el tamaño es 0, se usa la pantalla completa.
@export var limites: Rect2 = Rect2()
## Margen interno respecto a los límites (para que el sprite no se corte).
@export var margen_limites: float = 24.0

# Declaración de señal personalizada. Gasto de pintura
signal pinturas_actualizadas(cantidad_restante: int)

var inmune: bool = false    
## Pon en false para bloquear el movimiento (ej. Stun de 3 s).
var movimiento_habilitado: bool = true

# Valor de prueba. Si se agrega 100 ya funciona también.
var pinturas_disponibles: int = 100

var velocidad: Vector2 = Vector2.ZERO
var _tiempo: float = 0.0

## Capa física 3 ("paredes") = valor 4: es la que Spooky no puede atravesar.
const CAPA_PAREDES := 4

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _colision: CollisionShape2D = $CollisionShape2D
@onready var _suelo: SueloManager = get_tree().get_first_node_in_group("suelo") as SueloManager


func _physics_process(delta: float) -> void:
	_actualizar_velocidad(delta)
	_mover_chocando_con_paredes(velocidad * delta)
	_aplicar_limites()


func _process(delta: float) -> void:
	_animar_levitacion(delta)


func _actualizar_velocidad(delta: float) -> void:
	# get_vector ya normaliza: la diagonal no es más rápida que los ejes.
	var direccion := Vector2.ZERO
	if movimiento_habilitado:
		direccion = Input.get_vector("left", "right", "up", "down")

	if direccion != Vector2.ZERO:
		var objetivo := direccion * velocidad_maxima
		var tasa := aceleracion
		# Si el input va contra la velocidad actual, frena más fuerte para girar ágil.
		if velocidad.dot(direccion) < 0.0:
			tasa *= factor_giro
		velocidad = velocidad.move_toward(objetivo, tasa * delta)
	else:
		# Sin input (o aturdido): se desliza suavemente hasta detenerse.
		velocidad = velocidad.move_toward(Vector2.ZERO, desaceleracion * delta)


## Mueve a Spooky sin atravesar paredes. Spooky es un Area2D (no se mueve solo con la física),
## así que antes de cada paso se pregunta al motor: "¿mi forma chocaría con una pared ahí?".
func _mover_chocando_con_paredes(desplazamiento: Vector2) -> void:
	if desplazamiento == Vector2.ZERO:
		return
	# Si ya está dentro de una pared (por ejemplo, aparece encima de una), se mueve libre
	# para poder salir y no quedar atrapado.
	if _choca_con_pared(Vector2.ZERO):
		global_position += desplazamiento
		return
	# Primero el paso en X y luego el de Y, por separado: si uno está bloqueado el otro sigue,
	# y así Spooky resbala a lo largo de la pared en vez de pegarse a ella.
	var paso_x := Vector2(desplazamiento.x, 0.0)
	if _choca_con_pared(paso_x):
		velocidad.x = 0.0
	else:
		global_position += paso_x
	var paso_y := Vector2(0.0, desplazamiento.y)
	if _choca_con_pared(paso_y):
		velocidad.y = 0.0
	else:
		global_position += paso_y


## ¿Chocaría la forma de Spooky con una pared si se moviera `desplazamiento`?
func _choca_con_pared(desplazamiento: Vector2) -> bool:
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _colision.shape
	consulta.transform = _colision.global_transform.translated(desplazamiento)
	consulta.collision_mask = CAPA_PAREDES
	consulta.collide_with_areas = false  # solo cuerpos sólidos (las paredes)
	return not get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _aplicar_limites() -> void:
	var area := limites
	if area.size == Vector2.ZERO:
		area = get_viewport_rect()
	area = area.grow(-margen_limites)

	var antes := global_position
	global_position = global_position.clamp(area.position, area.end)

	# Al chocar con el borde, anula la velocidad en ese eje (evita "pegarse" a la pared).
	if not is_equal_approx(antes.x, global_position.x):
		velocidad.x = 0.0
	if not is_equal_approx(antes.y, global_position.y):
		velocidad.y = 0.0


func _animar_levitacion(delta: float) -> void:
	_tiempo += delta
	
	# Balanceo vertical solo en el sprite: no afecta la posición real ni donde cae la mancha.
	# Se atenúa un poco al ir rápido para que no estorbe la lectura del movimiento.
	var ratio := velocidad.length() / velocidad_maxima
	var amplitud := lerpf(bob_amplitud, bob_amplitud * 0.4, ratio)
	_sprite.position.y = sin(_tiempo * bob_velocidad) * amplitud

	# Inclinación según la velocidad horizontal.
	var inclinacion_objetivo := (velocidad.x / velocidad_maxima) * deg_to_rad(inclinacion_max_grados)
	_sprite.rotation = lerp_angle(_sprite.rotation, inclinacion_objetivo, clampf(suavidad_inclinacion * delta, 0.0, 1.0))
	
	if absf(velocidad.x) > 10.0:
		_sprite.flip_h = velocidad.x > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not movimiento_habilitado:
		return
	if event.is_action_pressed("ensuciar"):
		if pinturas_disponibles > 0:
			dejar_mancha()


func dejar_mancha() -> void:
	pinturas_disponibles -= 5
	
	# Emitir la señal personalizada pasando el nuevo valor
	emit_signal("pinturas_actualizadas", pinturas_disponibles)

	# SCRUM-04: en vez de instanciar una Mancha suelta, se tiñe la celda del
	# TileMap que está bajo el fantasma.
	if _suelo:
		_suelo.pintar(global_position)


func aplicar_aturdimiento() -> bool:
	if inmune or not movimiento_habilitado:
		return false
		
	# 1. Aturdimiento
	movimiento_habilitado = false
	modulate = Color(0.4, 0.4, 0.4) # Se oscurece al estar aturdido
	
	await get_tree().create_timer(3.0).timeout
	
	# 2. Despierta con inmunidad
	movimiento_habilitado = true
	inmune = true
	modulate = Color(1, 1, 1, 0.5) # Semitransparente por la inmunidad
	
	await get_tree().create_timer(1.5).timeout
	
	# 3. Fin de inmunidad
	inmune = false
	modulate = Color(1, 1, 1, 1) # Vuelve a su color normal
	
	return true
