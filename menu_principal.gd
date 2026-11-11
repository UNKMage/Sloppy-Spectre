extends Control
## Menú principal: cada botón carga el nivel que le corresponde.

## Ruta del botón (dentro de esta escena) -> escena del nivel que abre.
const NIVELES := {
	"Centro/Caja/BotonNivel1": "res://main.tscn",
	"Centro/Caja/BotonNivel2": "res://nivel_2.tscn",
	"Centro/Caja/BotonNivel3": "res://nivel_3.tscn",
}


func _ready() -> void:
	# Si venimos de un Game Over, el juego estaba pausado: sin esto los botones no responderían.
	get_tree().paused = false
	for ruta_boton: String in NIVELES:
		var boton: Button = get_node(ruta_boton)
		# bind() le "pega" la escena al botón: al presionarlo llama _abrir_nivel(escena).
		boton.pressed.connect(_abrir_nivel.bind(NIVELES[ruta_boton]))
	# Con el foco en el primer botón también se puede jugar con teclado (flechas + Enter).
	$Centro/Caja/BotonNivel1.grab_focus()


func _abrir_nivel(escena: String) -> void:
	get_tree().change_scene_to_file(escena)
