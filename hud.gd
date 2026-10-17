extends CanvasLayer

@onready var barra_pintura: ProgressBar = $ProgressBar
@onready var label_tiempo: Label = $Label2
@onready var label_game_over: Label = $LabelGameOver
@onready var label_suciedad: Label = get_node_or_null("LabelSuciedad")

var tiempo_restante: float = 120.0
var cronometro_activo: bool = true


func _ready() -> void:
	actualizar_etiqueta_tiempo()


func _process(delta: float) -> void:
	if not cronometro_activo:
		return
	tiempo_restante -= delta
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		cronometro_activo = false
		terminar_partida()
	actualizar_etiqueta_tiempo()


func actualizar_etiqueta_tiempo() -> void:
	var segundos_enteros = int(ceil(tiempo_restante))
	label_tiempo.text = "Tiempo: " + str(segundos_enteros)


func terminar_partida() -> void:
	if label_game_over:
		label_game_over.visible = true
	get_tree().paused = true


func actualizar_barra_progreso(cantidad: int) -> void:
	barra_pintura.value = float(cantidad)


func _on_ghost_pinturas_actualizadas(cantidad_restante: int) -> void:
	$ProgressBar.value = float(cantidad_restante)


## Función para KIBO-17: muestra el porcentaje en enteros sin decimales
func actualizar_porcentaje_suciedad(porcentaje: float, _actuales: int, _totales: int) -> void:
	if label_suciedad:
		label_suciedad.text = "Suciedad: %d%%" % int(porcentaje)


## Si conectaste la señal con el nombre automático por defecto, redirige a la misma función
func _on_suelo_suciedad_actualizada(porcentaje: float, celdas_sucias: int, total_celdas: int) -> void:
	actualizar_porcentaje_suciedad(porcentaje, celdas_sucias, total_celdas)
