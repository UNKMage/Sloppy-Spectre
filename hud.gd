extends CanvasLayer
# Asegúrate de que la ruta "$ProgressBar" coincida con tu nodo barra de progreso
@onready var barra_pintura: ProgressBar = $ProgressBar

# Esta función será llamada cuando el personaje emita la señal
func actualizar_barra_progreso(cantidad: int) -> void:
	barra_pintura.value = float(cantidad)

func _on_ghost_pinturas_actualizadas(cantidad_restante: int) -> void:
	$ProgressBar.value = float(cantidad_restante)
