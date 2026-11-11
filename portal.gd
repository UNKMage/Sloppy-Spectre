class_name Portal
extends Area2D

signal jugador_entro
signal jugador_salio
signal recarga_completa
signal inmunidad_terminada

@export var radio: float = 48.0
@export var tiempo_recarga: float = 5.0
@export var capacidad: int = 100
@export var tiempo_inmunidad: float = 8.0

var _jugador: Area2D = null
var _acumulado: float = 0.0
var _tiempo: float = 0.0
var _tiempo_inmunidad_actual: float = 0.0 
var _inmunidad_activa: bool = false
var _hud: Node = null

func _ready() -> void:
	($CollisionShape2D.shape as CircleShape2D).radius = radio
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_hud = get_tree().get_first_node_in_group("hud")


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()

	if _jugador == null:
		SoundManager.detener_recarga()
		return

	if _inmunidad_activa:
		_tiempo_inmunidad_actual += delta
		
		var tiempo_restante := tiempo_inmunidad - _tiempo_inmunidad_actual
		
		if tiempo_restante <= 3.0 and tiempo_restante > 0.0:
			var segundos_restantes := int(ceil(tiempo_restante))
			if _hud and _hud.has_method("mostrar_aviso"):
				_hud.mostrar_aviso("Inmunidad restante: " + str(segundos_restantes))
		
		if _tiempo_inmunidad_actual >= tiempo_inmunidad:
			_inmunidad_activa = false
			_jugador.set("en_portal", false)
			if _hud and _hud.has_method("mostrar_aviso"):
				_hud.mostrar_aviso("¡Inmunidad terminada!")
				
				var timer_ocultar := get_tree().create_timer(2.0)
				timer_ocultar.timeout.connect(func():
					if _hud and _hud.has_method("ocultar_aviso"):
						_hud.ocultar_aviso()
				)
			print("¡Inmunidad terminada!")

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

#Informa si ya se acabó la inmunidad.
func tiene_inmunidad_activa() -> bool:
	return _inmunidad_activa

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("jugador"):
		_jugador = area
		_acumulado = 0.0
		_tiempo_inmunidad_actual = 0.0 
		_inmunidad_activa = true
		_jugador.set("en_portal", true)
		if _hud and _hud.has_method("ocultar_aviso"):
			_hud.ocultar_aviso()
		jugador_entro.emit()


func _on_area_exited(area: Area2D) -> void:
	if area == _jugador:
		SoundManager.detener_recarga()
		if _jugador:
			_inmunidad_activa = false
			_jugador.set("en_portal", false)
		if _hud and _hud.has_method("ocultar_aviso"):
			_hud.ocultar_aviso()
		_jugador = null
		jugador_salio.emit()


## Arte del Portal Espiritual (pixel art dibujado en código, para combinar con los fondos):
## aro de piedra con runas que brillan, remolino de energía violeta/cian y motas que flotan.
const PIXEL := 4.0
const PALETA_ENERGIA: Array[Color] = [
	Color("1b1040"), Color("2d1b6b"), Color("4b2fa0"), Color("7a5ce6"), Color("8feaff"),
]
const PIEDRAS: Array[Color] = [Color("48506a"), Color("5b6379"), Color("3d445c"), Color("6a728a")]
const CONTORNO := Color("14142b")


func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func _draw() -> void:
	var pulso := 0.5 + 0.5 * sin(_tiempo * 2.2)
	# Resplandor suave alrededor.
	for i in 5:
		draw_circle(Vector2.ZERO, radio * (1.45 - i * 0.12), Color(0.45, 0.35, 0.95, 0.04 + i * 0.01 + pulso * 0.012))

	var celdas := int(ceil(radio * 1.15 / PIXEL))
	for gy in range(-celdas, celdas):
		for gx in range(-celdas, celdas):
			var centro := Vector2((gx + 0.5) * PIXEL, (gy + 0.5) * PIXEL)
			var r := centro.length() / radio
			var color: Color
			if r > 1.1:
				continue
			elif r > 1.0:
				color = CONTORNO
			elif r > 0.84:
				# aro de piedra con variación de bloques
				color = PIEDRAS[int(_hash(gx, gy) * 4.0) % 4]
				if centro.y < -centro.x * 0.3:
					color = color.lightened(0.1)  # luz desde arriba
				if r > 0.96 or r < 0.87:
					color = color.darkened(0.2)
			elif r > 0.8:
				color = CONTORNO
			else:
				# remolino de energía
				var ang := atan2(centro.y, centro.x)
				var giro := sin(ang * 3.0 + r * 7.0 - _tiempo * 1.8) * 0.5 + 0.5
				var v := giro * 0.55 + (1.0 - r / 0.8) * 0.55 + pulso * 0.1
				v += (_hash(gx + int(_tiempo * 3.0), gy) - 0.5) * 0.08
				var paso := clampi(int(v * 4.2), 0, 4)
				color = PALETA_ENERGIA[paso]
			draw_rect(Rect2(centro - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), color)

	# Runas que brillan una tras otra alrededor del aro.
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var brillo := 0.5 + 0.5 * sin(_tiempo * 2.0 - k * 0.8)
		var p := Vector2.from_angle(a) * radio * 0.92
		p = (p / PIXEL).round() * PIXEL
		draw_rect(Rect2(p - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), Color(0.56, 0.92, 1.0, 0.35 + brillo * 0.65))
		var q := Vector2.from_angle(a).rotated(PI / 2.0) * PIXEL
		draw_rect(Rect2(p + q - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), Color(0.56, 0.92, 1.0, (0.35 + brillo * 0.65) * 0.6))

	# Motas de espíritu que suben desde el portal.
	for k in 9:
		var fase := fmod(_tiempo * 0.35 + k / 9.0, 1.0)
		var x := sin(k * 2.3 + _tiempo * 0.9) * radio * 0.7
		var y := radio * 0.5 - fase * radio * 1.7
		var p2 := (Vector2(x, y) / PIXEL).round() * PIXEL
		draw_rect(Rect2(p2 - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), Color(0.75, 0.95, 1.0, sin(fase * PI) * 0.9))
