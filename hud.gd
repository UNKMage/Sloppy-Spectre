extends CanvasLayer
# Asegúrate de que la ruta "$ProgressBar" coincida con tu nodo barra de progreso
@onready var barra_pintura: ProgressBar = $ProgressBar
@onready var label_tiempo: Label = $Label2 
@onready var label_game_over: Label = $LabelGameOver

# Tiempo total de la partida en segundos (ajústalo a lo que necesites)
var tiempo_restante: float = 120.0 
var cronometro_activo: bool = true

func _ready() -> void:
	# Inicializamos el texto del cronómetro al arrancar
	actualizar_etiqueta_tiempo()
	
func _process(delta: float) -> void:
	if not cronometro_activo:
		return
	# Restamos el tiempo transcurrido en este frame
	tiempo_restante -= delta
	if tiempo_restante <= 0.0:
		tiempo_restante = 0.0
		cronometro_activo = false
		terminar_partida()
	actualizar_etiqueta_tiempo()

func actualizar_etiqueta_tiempo() -> void:
	# Convertimos los segundos a formato de enteros para que se vea limpio (ej. 59, 58...)
	# O si prefieres mostrar decimales, puedes usar: "%.1f" % tiempo_restante
	var segundos_enteros = int(ceil(tiempo_restante))
	label_tiempo.text = "Tiempo: " + str(segundos_enteros)

func terminar_partida() -> void:
	# 1. Hacemos visible el Label de Game Over
	if label_game_over:
		label_game_over.visible = true
	
	# 2. Pausamos el juego por completo
	get_tree().paused = true

# Esta función será llamada cuando el personaje emita la señal
func actualizar_barra_progreso(cantidad: int) -> void:
	barra_pintura.value = float(cantidad)

func _on_ghost_pinturas_actualizadas(cantidad_restante: int) -> void:
	$ProgressBar.value = float(cantidad_restante)
