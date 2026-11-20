class_name PixelSlider
extends Control
## Control deslizante en pixel art: una barra de bloques que se llena. Se maneja con el mouse
## (clic o arrastrar) o con el teclado (flechas izquierda y derecha cuando tiene el foco).

signal cambiado(valor: float)
## Al soltar el mouse o una tecla: sirve para sonar una muestra del volumen elegido.
signal soltado

const BLOQUES := 20

var color: Color = Color(0.56, 0.92, 1.0)
var valor: float = 1.0:
	set(v):
		valor = clampf(v, 0.0, 1.0)
		queue_redraw()
var _arrastrando := false


func _init() -> void:
	custom_minimum_size = Vector2(280, 32)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = event.pressed
		if event.pressed:
			grab_focus()
			_desde_x(event.position.x)
		else:
			soltado.emit()
		accept_event()
	elif event is InputEventMouseMotion and _arrastrando:
		_desde_x(event.position.x)
		accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var paso := 1.0 / BLOQUES
		valor += paso if event.is_action_pressed("ui_right") else -paso
		cambiado.emit(valor)
		soltado.emit()
		accept_event()


func _desde_x(x: float) -> void:
	var margen := 8.0
	var nuevo := clampf((x - margen) / (size.x - 2.0 * margen), 0.0, 1.0)
	# Se ajusta a bloques enteros: se ve limpio y es fácil llegar a 0 % y 100 %.
	nuevo = roundf(nuevo * BLOQUES) / BLOQUES
	if not is_equal_approx(nuevo, valor):
		valor = nuevo
		cambiado.emit(valor)


func _draw() -> void:
	var u := 4.0
	var marco := color.darkened(0.35) if not has_focus() else color
	draw_rect(Rect2(0, 0, size.x, size.y), marco)
	draw_rect(Rect2(u, u, size.x - 2.0 * u, size.y - 2.0 * u), Color(0.06, 0.05, 0.12))
	var ancho := (size.x - 4.0 * u) / BLOQUES
	for i in BLOQUES:
		var x := 2.0 * u + i * ancho
		var encendido := (i + 1.0) / BLOQUES <= valor + 0.001
		var c := color if encendido else Color(1, 1, 1, 0.07)
		draw_rect(Rect2(x, 2.0 * u, ancho - 2.0, size.y - 4.0 * u), c.darkened(0.2) if encendido else c)
		if encendido:
			draw_rect(Rect2(x, 2.0 * u, ancho - 2.0, 4.0), color.lightened(0.3))
	if has_focus():
		var largo := 12.0
		for esq in [[Vector2(-6, -6), 1.0, 1.0], [Vector2(size.x + 6, -6), -1.0, 1.0],
				[Vector2(-6, size.y + 6), 1.0, -1.0], [Vector2(size.x + 6, size.y + 6), -1.0, -1.0]]:
			var p: Vector2 = esq[0]
			var sx: float = esq[1]
			var sy: float = esq[2]
			draw_rect(Rect2(p, Vector2(largo * sx, u * sy)).abs(), Color.WHITE)
			draw_rect(Rect2(p, Vector2(u * sx, largo * sy)).abs(), Color.WHITE)
