class_name Portal
extends Area2D
## Portal Espiritual: zona segura y punto de recarga de ectoplasma.

signal jugador_entro
signal jugador_salio
signal recarga_completa

@export var radio: float = 48.0
@export var tiempo_recarga: float = 5 # Segundos para llenar el tanque desde 0
@export var capacidad: int = 20

var _jugador: Area2D = null
var _acumulado: float = 0.0
var _tiempo: float = 0.0


func _ready() -> void:
	($CollisionShape2D.shape as CircleShape2D).radius = radio
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw() # Para animar el pulso

	if _jugador == null:
		return
	if _jugador.pinturas_disponibles >= capacidad:
		return

	# Recarga proporcional al tiempo: 100 unidades en 1.5 s
	_acumulado += capacidad / tiempo_recarga * delta
	var enteras := int(_acumulado)
	if enteras > 0:
		_acumulado -= enteras
		_jugador.pinturas_disponibles = mini(capacidad, _jugador.pinturas_disponibles + enteras)
		if _jugador.pinturas_disponibles >= capacidad:
			recarga_completa.emit()


func _on_area_entered(area: Area2D) -> void:
	print("Entró algo al portal: ", area.name, " | grupos: ", area.get_groups())
	if area.is_in_group("jugador"):
		_jugador = area
		_acumulado = 0.0
		jugador_entro.emit()


func _on_area_exited(area: Area2D) -> void:
	if area == _jugador:
		_jugador = null
		jugador_salio.emit()


# Dibujo provisional morado/azul con pulso. Se reemplaza por sprite cuando haya arte.
func _draw() -> void:
	var pulso := 1.0 + sin(_tiempo * 3.0) * 0.05
	draw_circle(Vector2.ZERO, radio * pulso, Color(0.35, 0.2, 0.8, 0.35))
	draw_circle(Vector2.ZERO, radio * 0.6 * pulso, Color(0.2, 0.4, 1.0, 0.5))
	draw_arc(Vector2.ZERO, radio * pulso, 0.0, TAU, 32, Color(0.6, 0.5, 1.0), 3.0)
