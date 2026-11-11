extends CanvasLayer

@onready var barra_progreso: ProgressBar = $ProgressBar
@onready var label_estado: Label = $Label

var ruta_destino: String = ""
var progreso: Array = []
var cargando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func iniciar_carga(ruta: String) -> void:
	ruta_destino = ruta
	cargando = true
	barra_progreso.value = 0.0
	label_estado.text = "Cargando habitación..."
	ResourceLoader.load_threaded_request(ruta_destino)


func _process(_delta: float) -> void:
	if not cargando:
		return

	var estado = ResourceLoader.load_threaded_get_status(ruta_destino, progreso)
	if progreso.size() > 0:
		barra_progreso.value = progreso[0] * 100.0

	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		cargando = false
		label_estado.text = "¡LISTO!"
		
		# Espera un instante para que el jugador vea el 100%
		await get_tree().create_timer(0.3).timeout
		get_tree().paused = false
		
		var escena_empaquetada = ResourceLoader.load_threaded_get(ruta_destino)
		get_tree().change_scene_to_packed(escena_empaquetada)
		
		# Desvanece la cortina negra y elimina la pantalla de carga para revelar el nivel
		var tween := create_tween()
		var fondo = get_node_or_null("ColorRect")
		if fondo:
			tween.tween_property(fondo, "modulate:a", 0.0, 0.3)
		
		await tween.finished
		queue_free()
		
	elif estado == ResourceLoader.THREAD_LOAD_FAILED:
		cargando = false
		label_estado.text = "Error al cargar nivel"
