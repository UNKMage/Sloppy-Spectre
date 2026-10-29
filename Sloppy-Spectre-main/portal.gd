class_name Portal
extends Area2D

signal jugador_entro
signal jugador_salio
signal recarga_completa

@export var radio: float = 48.0
@export var tiempo_recarga: float = 5.0
@export var capacidad: int = 100

var _jugador: Area2D = null
var _acumulado: float = 0.0
var _tiempo: float = 0.0


func _ready() -> void:
	($CollisionShape2D.shape as CircleShape2D).radius = radio
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()

	if _jugador == null:
		SoundManager.detener_recarga()
		return

	# Si ya tiene el tanque lleno, no suena y no recarga
	if _jugador.pinturas_disponibles >= capacidad:
		SoundManager.detener_recarga()
		return

	# Suena continuo mientras esté adentro y le falte pintura
	SoundManager.iniciar_recarga()

	_acumulado += capacidad / tiempo_recarga * delta
	var enteras := int(_acumulado)
	if enteras > 0:
		_acumulado -= enteras
		_jugador.pinturas_disponibles = mini(capacidad, _jugador.pinturas_disponibles + enteras)
		
		if _jugador.has_signal("pinturas_actualizadas"):
			_jugador.emit_signal("pinturas_actualizadas", _jugador.pinturas_disponibles)
		
		if _jugador.pinturas_disponibles >= capacidad:
			SoundManager.detener_recarga()
			recarga_completa.emit()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("jugador"):
		_jugador = area
		_acumulado = 0.0
		_jugador.set("en_portal", true)
		jugador_entro.emit()


func _on_area_exited(area: Area2D) -> void:
	if area == _jugador:
		SoundManager.detener_recarga()
		if _jugador:
			_jugador.set("en_portal", false)
		_jugador = null
		jugador_salio.emit()


func _draw() -> void:
	var pulso := 1.0 + sin(_tiempo * 3.0) * 0.05
	draw_circle(Vector2.ZERO, radio * pulso, Color(0.35, 0.2, 0.8, 0.35))
	draw_circle(Vector2.ZERO, radio * 0.6 * pulso, Color(0.2, 0.4, 1.0, 0.5))
	draw_arc(Vector2.ZERO, radio * pulso, 0.0, TAU, 32, Color(0.6, 0.5, 1.0), 3.0)
