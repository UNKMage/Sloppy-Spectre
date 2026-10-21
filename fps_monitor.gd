extends CanvasLayer
## Contador de FPS. F3 = mostrar/ocultar, F4 = reiniciar estadísticas.

var _label := Label.new()

var _frames: int = 0
var _tiempo_total: float = 0.0
var _delta_max: float = 0.0   # frame más lento  -> FPS mínimo
var _delta_min: float = INF   # frame más rápido -> FPS máximo
var _refresco_texto: float = 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego pausado
	_label.position = Vector2(8, 8)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	# Las estadísticas se acumulan siempre, aunque el texto esté oculto.
	_frames += 1
	_tiempo_total += delta
	_delta_max = maxf(_delta_max, delta)
	_delta_min = minf(_delta_min, delta)

	if not _label.visible:
		return
	_refresco_texto -= delta
	if _refresco_texto <= 0.0:
		_refresco_texto = 0.25  # actualiza el texto 4 veces por segundo
		_actualizar_texto()


func _actualizar_texto() -> void:
	if _frames == 0 or _tiempo_total <= 0.0:
		return
	var actual := Engine.get_frames_per_second()
	var minimo := 1.0 / _delta_max
	var maximo := 1.0 / _delta_min
	var promedio := _frames / _tiempo_total
	_label.text = "FPS: %d\nMin: %d\nMax: %d\nProm: %d" % [actual, minimo, maximo, promedio]


func reiniciar() -> void:
	_frames = 0
	_tiempo_total = 0.0
	_delta_max = 0.0
	_delta_min = INF


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F3:
				_label.visible = not _label.visible
			KEY_F4:
				reiniciar()
