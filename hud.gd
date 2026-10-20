extends CanvasLayer

## Pantalla que se muestra al ganar o perder (la misma escena para las dos).
const PANTALLA_FIN := preload("res://pantalla_fin.tscn")

@export_group("Reglas de la partida")
## Porcentaje de suciedad que hay que alcanzar para GANAR.
@export var meta_victoria: float = 80.0

@onready var barra_pintura: ProgressBar = $ProgressBar
@onready var label_tiempo: Label = $Label2
@onready var label_game_over: Label = $LabelGameOver
@onready var label_suciedad: Label = get_node_or_null("LabelSuciedad")
@onready var barra_suciedad: ProgressBar = get_node_or_null("ProgressBarSuciedad")
@onready var reintentar: Button = get_node_or_null("ButtonReintentar")

var tiempo_restante: float = 120.0
var cronometro_activo: bool = true
## true cuando ya se ganó o se perdió (evita terminar dos veces el mismo frame).
var partida_terminada: bool = false

## Evita reproducir la alerta repetidamente dentro del mismo segundo
var _ultimo_segundo_alerta: int = -1

var _porcentaje_suciedad: float = 0.0
## Al empezar la suciedad es 0%, así que "suciedad = 0" solo cuenta como derrota
## si antes hubo manchas (es decir, si los Limpiadores borraron todo).
var _hubo_suciedad: bool = false


func _ready() -> void:
	actualizar_etiqueta_tiempo()
	if reintentar and not reintentar.pressed.is_connected(_on_button_reintentar_pressed):
		reintentar.pressed.connect(_on_button_reintentar_pressed)
	_conectar_suelo()


## Conecta la señal de suciedad del Suelo si la escena no lo hizo ya. Así el HUD recibe el
## porcentaje en cualquier nivel (main.tscn no traía esa conexión) sin tener que editar la escena.
func _conectar_suelo() -> void:
	var suelo := get_tree().get_first_node_in_group("suelo")
	if suelo and not suelo.suciedad_actualizada.is_connected(actualizar_porcentaje_suciedad):
		suelo.suciedad_actualizada.connect(actualizar_porcentaje_suciedad)


func _process(delta: float) -> void:
	if not cronometro_activo:
		return
	tiempo_restante -= delta

	# Sonido de cuenta regresiva en los últimos 10 segundos
	var seg := int(ceil(tiempo_restante))
	if seg <= 10 and seg > 0 and seg != _ultimo_segundo_alerta:
		_ultimo_segundo_alerta = seg
		SoundManager.reproducir_alerta()

	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		cronometro_activo = false
		terminar_partida()
	actualizar_etiqueta_tiempo()


func actualizar_etiqueta_tiempo() -> void:
	var segundos_enteros = int(ceil(tiempo_restante))
	label_tiempo.text = "Tiempo: " + str(segundos_enteros)


## Derrota por tiempo (se llama cuando el cronómetro llega a 0).
func terminar_partida() -> void:
	_finalizar(false, "¡Se acabó el tiempo!")


## Cierra la partida: pausa el juego y muestra la pantalla de victoria o de game over.
## (Esta pantalla reemplaza al LabelGameOver y al botón Reintentar de antes, que ya no se muestran.)
func _finalizar(victoria: bool, motivo: String) -> void:
	if partida_terminada:
		return
	partida_terminada = true
	cronometro_activo = false
	get_tree().paused = true

	# Apagar la alerta del timer en cuanto termine la partida (ganes o pierdas)
	SoundManager.detener_alerta()
	
	# Sonido de Game Over si la partida terminó en derrota
	if not victoria:
		SoundManager.reproducir_gameover()
		
	var pantalla := PANTALLA_FIN.instantiate()
	add_child(pantalla)
	pantalla.mostrar(victoria, motivo, _porcentaje_suciedad, tiempo_restante)


func actualizar_barra_progreso(cantidad: int) -> void:
	barra_pintura.value = float(cantidad)


func _on_ghost_pinturas_actualizadas(cantidad_restante: int) -> void:
	$ProgressBar.value = float(cantidad_restante)


## Función para KIBO-17: muestra el porcentaje en enteros sin decimales
func actualizar_porcentaje_suciedad(porcentaje: float, _actuales: int, _totales: int) -> void:
	_porcentaje_suciedad = porcentaje
	if porcentaje > 0.0:
		_hubo_suciedad = true
	if barra_suciedad:
		barra_suciedad.value = porcentaje

	# Reglas de fin de partida (se revisan solo cuando cambia la suciedad, no en cada frame).
	if partida_terminada:
		return
	if porcentaje >= meta_victoria:
		_finalizar(true, "¡Ensuciaste la zona antes de que te atraparan!")
	elif _hubo_suciedad and porcentaje <= 0.0:
		_finalizar(false, "Los Limpiadores borraron todo tu ectoplasma.")


func _on_suelo_suciedad_actualizada(porcentaje: float, celdas_sucias: int, total_celdas: int) -> void:
	actualizar_porcentaje_suciedad(porcentaje, celdas_sucias, total_celdas)


# Solo reinicia la escena actual. Puede servir pero también puede quitarse si después no es necesaria.
func _on_button_reintentar_pressed() -> void:
	# 1. IMPORTANTE: Quitar la pausa antes de recargar, de lo contrario la escena se quedará congelada
	get_tree().paused = false
	# 2. Recarga la escena actual desde cero
	get_tree().reload_current_scene()
