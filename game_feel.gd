class_name GameFeel
extends Node
## "Jugosidad" del juego: sacudidas de pantalla, congelado de un instante al recibir un golpe,
## destellos, aplastar y estirar a Spooky, y el pulso rojo de alerta cuando queda poco tiempo.
## Vive como hijo de Spooky (así está en todos los niveles). Otros scripts piden efectos con
## GameFeel.sacudir(...) y GameFeel.congelar(...), sin tener que conocer este nodo.

const VINETA_ALERTA_SEGUNDOS := 10.0

var _ghost: Node2D
var _sprite: AnimatedSprite2D
var _suelo: Node
var _sacudida_fuerza := 0.0
var _sacudida_dura := 0.0
var _sacudida_resta := 0.0
var _destello: ColorRect
var _vineta: TextureRect
var _t := 0.0
var _estaba_aturdido := false
var _tween_sprite: Tween
var _escala_base := Vector2(3, 3)


# --- API estática: la usan otros scripts ---

## Sacude la pantalla. fuerza = píxeles de desplazamiento máximo, duracion = segundos.
static func sacudir(arbol: SceneTree, fuerza: float = 6.0, duracion: float = 0.25) -> void:
	var nodo := arbol.get_first_node_in_group("game_feel") as GameFeel
	if nodo:
		nodo._iniciar_sacudida(fuerza, duracion)


## Congela el juego un instante (como cuando algo golpea fuerte). Dura `duracion` segundos reales.
static func congelar(arbol: SceneTree, duracion: float = 0.07) -> void:
	if Engine.time_scale < 1.0 or arbol.paused:
		return
	Engine.time_scale = 0.04
	# El 4.º parámetro hace que el temporizador ignore la cámara lenta.
	await arbol.create_timer(duracion, true, false, true).timeout
	Engine.time_scale = 1.0


## Destello de color sobre toda la pantalla (se apaga solo).
static func destello(arbol: SceneTree, color: Color, duracion: float = 0.35) -> void:
	var nodo := arbol.get_first_node_in_group("game_feel") as GameFeel
	if nodo:
		nodo._iniciar_destello(color, duracion)


# --- Instancia ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_feel")
	_ghost = get_parent() as Node2D
	_sprite = _ghost.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_escala_base = _sprite.scale
	_crear_capas()
	await get_tree().physics_frame
	_suelo = get_tree().get_first_node_in_group("suelo")
	if _suelo and _suelo.has_signal("celda_pintada"):
		_suelo.celda_pintada.connect(_on_celda_pintada)


func _exit_tree() -> void:
	# Si el nivel se cierra a media sacudida, la pantalla debe quedar en su sitio.
	if is_inside_tree():
		get_viewport().canvas_transform = Transform2D.IDENTITY
	Engine.time_scale = 1.0


func _crear_capas() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 3  # sobre el juego, bajo el HUD
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	# Viñeta roja para la alerta de poco tiempo.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 0.1, 0.1, 0.0), Color(1, 0.1, 0.1, 0.85)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_vineta = TextureRect.new()
	_vineta.texture = tex
	_vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vineta.stretch_mode = TextureRect.STRETCH_SCALE
	_vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vineta.modulate.a = 0.0
	capa.add_child(_vineta)
	_destello = ColorRect.new()
	_destello.color = Color(1, 1, 1, 0)
	_destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_destello)


func _process(delta: float) -> void:
	var vp := get_viewport()
	if get_tree().paused:
		vp.canvas_transform = Transform2D.IDENTITY  # en pausa la pantalla no tiembla
		return
	_t += delta
	# Sacudida: el desplazamiento se apaga de golpe al principio y suave al final.
	if _sacudida_resta > 0.0:
		_sacudida_resta -= delta
		var k := clampf(_sacudida_resta / _sacudida_dura, 0.0, 1.0)
		var fuerza := _sacudida_fuerza * k * k
		vp.canvas_transform = Transform2D(0.0, Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fuerza)
		if _sacudida_resta <= 0.0:
			vp.canvas_transform = Transform2D.IDENTITY
	# Alerta: pulso rojo en los bordes cuando quedan 10 segundos o menos.
	var hud := get_tree().get_first_node_in_group("hud")
	var restante: float = hud.get("tiempo_restante") if hud else 999.0
	var partida_terminada: bool = hud.get("partida_terminada") if hud else false
	if restante <= VINETA_ALERTA_SEGUNDOS and restante > 0.0 and not partida_terminada:
		var intensidad := remap(restante, VINETA_ALERTA_SEGUNDOS, 0.0, 0.18, 0.42)
		_vineta.modulate.a = intensidad * (0.5 + 0.5 * sin(_t * (5.0 + (VINETA_ALERTA_SEGUNDOS - restante))))
	else:
		_vineta.modulate.a = move_toward(_vineta.modulate.a, 0.0, delta * 2.0)
	_detectar_aturdimiento()


func _iniciar_sacudida(fuerza: float, duracion: float) -> void:
	# Una sacudida nueva solo reemplaza a la actual si es más fuerte.
	if fuerza * duracion >= _sacudida_fuerza * maxf(_sacudida_resta, 0.0):
		_sacudida_fuerza = fuerza
		_sacudida_dura = duracion
		_sacudida_resta = duracion


func _iniciar_destello(color: Color, duracion: float) -> void:
	_destello.color = color
	var tw := create_tween()
	tw.tween_property(_destello, "color:a", 0.0, duracion).from(color.a)


# --- Reacciones de Spooky ---

## Al ser aturdido: golpe fuerte (sacudida, congelado y destello rojo), y Spooky se aplasta.
func _detectar_aturdimiento() -> void:
	if _ghost == null:
		return
	var aturdido: bool = _ghost.get("movimiento_habilitado") == false and not _ghost.get("inmune")
	if aturdido and not _estaba_aturdido:
		_iniciar_sacudida(14.0, 0.45)
		GameFeel.congelar(get_tree(), 0.09)
		_iniciar_destello(Color(1.0, 0.15, 0.15, 0.28), 0.45)
		_aplastar(Vector2(1.5, 0.55), 0.5)
	_estaba_aturdido = aturdido


## Al soltar ectoplasma: un temblor mínimo y Spooky se "sacude" como si escupiera.
func _on_celda_pintada(_celda: Vector2i, _total: int) -> void:
	_iniciar_sacudida(2.5, 0.1)
	_aplastar(Vector2(1.22, 0.8), 0.22)


## Aplasta/estira el sprite de Spooky y lo devuelve a su tamaño con rebote.
func _aplastar(factor: Vector2, duracion: float) -> void:
	if _sprite == null:
		return
	if _tween_sprite and _tween_sprite.is_valid():
		_tween_sprite.kill()
	var base := _escala_base
	_sprite.scale = base * factor
	_tween_sprite = create_tween()
	_tween_sprite.tween_property(_sprite, "scale", base, duracion).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
