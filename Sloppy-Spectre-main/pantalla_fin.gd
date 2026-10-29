extends CanvasLayer
## Pantalla de fin de partida. Sirve para VICTORIA y para GAME OVER:
## solo cambian el título, el color y los textos (los pone mostrar()).

const MENU := "res://menu_principal.tscn"
const COLOR_VICTORIA := Color(0.45, 1.0, 0.55)
const COLOR_DERROTA := Color(1.0, 0.35, 0.35)
## Segundos que los botones esperan antes de activarse. Si el jugador está presionando
## Espacio (para manchar) justo cuando termina la partida, no debe "pulsar" un botón sin querer.
const RETRASO_BOTONES := 0.8

@onready var _fondo: ColorRect = $Fondo
@onready var _titulo: Label = $Centro/Caja/Titulo
@onready var _motivo: Label = $Centro/Caja/Motivo
@onready var _datos: Label = $Centro/Caja/Datos
@onready var _boton_reintentar: Button = $Centro/Caja/Botones/BotonReintentar
@onready var _boton_menu: Button = $Centro/Caja/Botones/BotonMenu


func _ready() -> void:
	_boton_reintentar.pressed.connect(_reintentar)
	_boton_menu.pressed.connect(_ir_al_menu)


## Muestra la pantalla. victoria = true -> "¡VICTORIA!", false -> "GAME OVER".
func mostrar(victoria: bool, motivo: String, suciedad: float, tiempo_restante: float) -> void:
	var color := COLOR_VICTORIA if victoria else COLOR_DERROTA
	_titulo.text = "¡VICTORIA!" if victoria else "GAME OVER"
	_titulo.add_theme_color_override("font_color", color)
	_fondo.color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.82)
	_motivo.text = motivo
	_datos.text = "Suciedad final: %d%%      Tiempo restante: %d s" % [int(suciedad), ceili(tiempo_restante)]

	_boton_reintentar.disabled = true
	_boton_menu.disabled = true
	# create_timer sigue corriendo con el juego en pausa (por defecto ignora la pausa).
	await get_tree().create_timer(RETRASO_BOTONES).timeout
	_boton_reintentar.disabled = false
	_boton_menu.disabled = false
	_boton_reintentar.grab_focus()  # así también se puede usar con teclado (flechas + Enter)


func _reintentar() -> void:
	get_tree().paused = false  # el HUD pausó el juego al terminar; hay que despausar
	get_tree().reload_current_scene()


func _ir_al_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
