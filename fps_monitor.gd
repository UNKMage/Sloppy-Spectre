extends CanvasLayer
## Contador de FPS. F3 = mostrar/ocultar, F4 = reiniciar estadísticas.
## Min y Max se calculan sobre el promedio de cada ventana de 1 s, no sobre frames sueltos.

const VENTANA := 1.0  # segundos por muestra

var _label := Label.new()

# Acumulado total (para el promedio real).
var _frames: int = 0
var _tiempo_total: float = 0.0

# Ventana en curso.
var _frames_ventana: int = 0
var _tiempo_ventana: float = 0.0

# Resultados.
var _fps_actual: float = 0.0
var _fps_min: float = INF
var _fps_max: float = 0.0
var _peor_frame: float = 0.0  # en segundos


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego pausado
	_label.position = Vector2(8, 8)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	_frames += 1
	_tiempo_total += delta
	_frames_ventana += 1
	_tiempo_ventana += delta
	_peor_frame = maxf(_peor_frame, delta)

	if _tiempo_ventana >= VENTANA:
		_fps_actual = _frames_ventana / _tiempo_ventana
		_fps_min = minf(_fps_min, _fps_actual)
		_fps_max = maxf(_fps_max, _fps_actual)
		_frames_ventana = 0
		_tiempo_ventana = 0.0
		if _label.visible:
			_actualizar_texto()


func _actualizar_texto() -> void:
	var promedio := _frames / _tiempo_total
	_label.text = "FPS: %d\nMin: %d\nMax: %d\nProm: %d\nPeor frame: %.1f ms" % [
		_fps_actual, _fps_min, _fps_max, promedio, _peor_frame * 1000.0
	]


func reiniciar() -> void:
	_frames = 0
	_tiempo_total = 0.0
	_frames_ventana = 0
	_tiempo_ventana = 0.0
	_fps_actual = 0.0
	_fps_min = INF
	_fps_max = 0.0
	_peor_frame = 0.0
	if _label.visible:
		_label.text = "Midiendo..."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F3:
				_label.visible = not _label.visible
				if _label.visible:
					_label.text = "Midiendo..."
			KEY_F4:
				reiniciar()
