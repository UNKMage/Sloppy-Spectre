class_name ReaccionesLimpiador
extends Node2D
## Hace que el Limpiador se sienta vivo, sin tocar su lógica: lee su estado y reacciona.
##   - Al descubrir a Spooky: salta de sorpresa y le sale un "!" rojo encima.
##   - Al perderlo de vista: un "?" amarillo.
##   - Al aturdir a Spooky: se ríe ("¡JA!").
##   - Camina con rebote e inclinación; al perseguir se enrojece; al limpiar vibra y chupa polvo.
## Se agrega como hijo de cada Limpiador (lo hace VisionCono). Se ve siempre, aunque el
## Limpiador quede oculto por la sombra: es el aviso de "alguien te vio".

enum Estado { PATRULLANDO, PERSIGUIENDO, ASPIRANDO }  # igual que en limpiador.gd

var _limpiador: CharacterBody2D
var _sprite: AnimatedSprite2D
var _ghost: Node
var _escala_base := Vector2.ONE
var _estado_previo := -1
var _t := 0.0
var _salto := 0.0
var _burbuja_texto := ""
var _burbuja_color := Color.WHITE
var _burbuja_t := 99.0
var _burbuja_dura := 1.0
var _ghost_estaba_aturdido := false
var _tween: Tween


func _ready() -> void:
	_limpiador = get_parent() as CharacterBody2D
	_sprite = _limpiador.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_escala_base = _sprite.scale
	z_index = 6
	await get_tree().physics_frame
	_ghost = get_tree().get_first_node_in_group("jugador")


func _process(delta: float) -> void:
	if _limpiador == null or _sprite == null:
		return
	_t += delta
	_burbuja_t += delta
	var estado: int = _limpiador.get("estado")
	if _estado_previo != -1 and estado != _estado_previo:
		_al_cambiar_estado(_estado_previo, estado)
	_estado_previo = estado
	_vigilar_aturdimiento()
	_animar_cuerpo(estado)
	queue_redraw()


func _al_cambiar_estado(antes: int, ahora: int) -> void:
	if ahora == Estado.PERSIGUIENDO:
		_burbuja("!", Color(1.0, 0.3, 0.28), 1.0)
		_saltar(14.0)
		_aplastar(Vector2(0.8, 1.3), 0.3)
		# Si está cerca, el susto se siente en la pantalla.
		if _ghost and (_ghost as Node2D).global_position.distance_to(_limpiador.global_position) < 320.0:
			GameFeel.sacudir(get_tree(), 4.0, 0.2)
	elif antes == Estado.PERSIGUIENDO and ahora == Estado.PATRULLANDO:
		_burbuja("?", Color(1.0, 0.85, 0.3), 1.2)
		_aplastar(Vector2(1.12, 0.9), 0.25)


## Cuando Spooky queda aturdido cerca, el Limpiador celebra.
func _vigilar_aturdimiento() -> void:
	if _ghost == null:
		return
	var aturdido: bool = _ghost.get("movimiento_habilitado") == false and not _ghost.get("inmune")
	if aturdido and not _ghost_estaba_aturdido:
		if (_ghost as Node2D).global_position.distance_to(_limpiador.global_position) < 380.0:
			_burbuja("¡JA!", Color(1.0, 0.9, 0.45), 1.3)
			_saltar(10.0)
	_ghost_estaba_aturdido = aturdido


func _animar_cuerpo(estado: int) -> void:
	var camina := _limpiador.velocity.length() > 5.0
	var rebote := -absf(sin(_t * 11.0)) * 3.0 if camina else 0.0
	var inclinacion := clampf(_limpiador.velocity.x / 150.0, -1.0, 1.0) * 0.09 if camina else 0.0
	var vibra := sin(_t * 45.0) * 0.9 if estado == Estado.ASPIRANDO else 0.0
	_sprite.position = Vector2(vibra, rebote - _salto)
	_sprite.rotation = lerp_angle(_sprite.rotation, inclinacion, 0.25)
	# Se enrojece mientras persigue.
	var objetivo := Color(1.0, 0.78, 0.78) if estado == Estado.PERSIGUIENDO else Color.WHITE
	_sprite.modulate = _sprite.modulate.lerp(objetivo, 0.15)


func _saltar(altura: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_salto", altura, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_salto", 0.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)


func _aplastar(factor: Vector2, duracion: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_sprite.scale = _escala_base * factor
	_tween = create_tween()
	_tween.tween_property(_sprite, "scale", _escala_base, duracion).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _burbuja(texto: String, color: Color, duracion: float) -> void:
	_burbuja_texto = texto
	_burbuja_color = color
	_burbuja_dura = duracion
	_burbuja_t = 0.0


func _draw() -> void:
	# Aspirando: motitas de polvo que son chupadas hacia el Limpiador.
	if _limpiador and _limpiador.get("estado") == Estado.ASPIRANDO:
		for k in 8:
			var f := fmod(_t * 1.6 + k / 8.0, 1.0)
			var a := k * 2.4 + _t
			var p := Vector2.from_angle(a) * lerpf(34.0, 6.0, f)
			p = (p / 2.0).round() * 2.0
			draw_rect(Rect2(p + Vector2(0, 6), Vector2(2, 2)), Color(0.8, 0.85, 1.0, sin(f * PI) * 0.8))
	if _burbuja_t < _burbuja_dura:
		_dibujar_burbuja()


## Globo de diálogo de pixel art sobre la cabeza: aparece con rebote, flota y se desvanece.
func _dibujar_burbuja() -> void:
	var fuente := UIPixel.fuente()
	var tam := 26
	var ancho_texto := fuente.get_string_size(_burbuja_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var ancho := maxf(ancho_texto + 20.0, 34.0)
	var alto := 38.0
	var entrada := clampf(_burbuja_t / 0.18, 0.0, 1.0)
	var escala := ease(entrada, -2.5) * (1.0 + 0.25 * sin(entrada * PI))
	var salida := clampf((_burbuja_t - (_burbuja_dura - 0.3)) / 0.3, 0.0, 1.0)
	var alfa := 1.0 - salida
	var flota := sin(_t * 6.0) * 2.0 - salida * 6.0
	draw_set_transform(Vector2(0, -52.0 + flota), 0.0, Vector2(escala, escala))
	var x := -ancho * 0.5
	var borde := Color(0.08, 0.08, 0.16, alfa)
	var relleno := Color(0.97, 0.97, 1.0, alfa)
	# caja con esquinas mordidas + cola
	draw_rect(Rect2(x + 4, -alto, ancho - 8, alto), borde)
	draw_rect(Rect2(x, -alto + 4, ancho, alto - 8), borde)
	draw_rect(Rect2(x + 4, -alto + 4, ancho - 8, alto - 8), relleno)
	draw_rect(Rect2(x + 4 - 4, -alto + 8, ancho, alto - 16), relleno)
	draw_rect(Rect2(-6, 0, 12, 4), borde)
	draw_rect(Rect2(-2, 4, 4, 4), borde)
	draw_rect(Rect2(-4, -4, 8, 4), relleno)
	var color := _burbuja_color
	color.a = alfa
	draw_string(fuente, Vector2(x, -alto * 0.5 + 9.0), _burbuja_texto, HORIZONTAL_ALIGNMENT_CENTER, ancho, tam, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
