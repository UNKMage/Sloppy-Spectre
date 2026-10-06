extends Area2D
## Spooky (fantasma). Movimiento omnidireccional con levitación fluida.
## Sin colisiones de terreno (GDD): se mueve libre en vista superior 2D.

@export var mancha_escena: PackedScene # Arrastra mancha.tscn aquí en el Inspector

@export_group("Movimiento")
## Velocidad máxima en px/s.
@export var velocidad_maxima: float = 420.0
## Qué tan rápido alcanza la velocidad máxima (px/s²). Más alto = más ágil.
@export var aceleracion: float = 1100.0
## Qué tan rápido se frena al soltar las teclas (px/s²). Más bajo = más "flotante".
@export var desaceleracion: float = 700.0
## Extra de frenado al invertir dirección bruscamente (gidsros más precisos para esquivar).
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

## Pon en false para bloquear el movimiento (ej. Stun de 3 s).
var movimiento_habilitado: bool = true

#Valor de prueba. Si se agrega 100 ya funciona también.
var pinturas_disponibles: int = 20

var velocidad: Vector2 = Vector2.ZERO
var _tiempo: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	_actualizar_velocidad(delta)
	global_position += velocidad * delta
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
	   # Dentro de _animar_levitacion()
	if absf(velocidad.x) > 10.0:
		_sprite.flip_h = velocidad.x > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not movimiento_habilitado:
		return
	if event.is_action_pressed("ensuciar"):
		if pinturas_disponibles > 0:
			dejar_mancha()
		else:
			print("¡Te has quedado sin pintura!")


func dejar_mancha() -> void:
	pinturas_disponibles -= 1
	print("Pinturas restantes: ", pinturas_disponibles)

	if mancha_escena:
		# 1. Creamos la mancha
		var nueva_mancha = mancha_escena.instantiate()
		# 2. La ponemos exactamente donde está el fantasma en este momento
		nueva_mancha.global_position = global_position
		# 3. La soltamos en el mundo para que se quede ahí pintando
		get_parent().add_child(nueva_mancha)
