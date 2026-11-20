class_name Opciones
extends RefCounted
## Opciones del jugador: volumen (general, música y efectos) y pantalla completa.
## Se guardan en user://opciones.cfg y se aplican al abrir el juego. Todo es estático:
## no hace falta ningún nodo ni autoload, se usa como Opciones.set_volumen("Efectos", 0.5).

const RUTA := "user://opciones.cfg"
## Buses de audio. "Master" es el general; Música y Efectos se crean aquí si no existen.
const BUSES: Array[String] = ["Master", "Musica", "Efectos"]

static var volumen: Dictionary = {"Master": 1.0, "Musica": 0.8, "Efectos": 1.0}
static var pantalla_completa: bool = true
## Cosas que el jugador ya vio (introducción, tutorial, cada boost): clave -> true. Se guarda en el mismo archivo.
static var vistos: Dictionary = {}
static var _cargado: bool = false


## Lee el archivo guardado (una sola vez), crea los buses y aplica todo.
static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) == OK:
		for b in BUSES:
			volumen[b] = clampf(float(cfg.get_value("audio", b, volumen[b])), 0.0, 1.0)
		pantalla_completa = bool(cfg.get_value("pantalla", "completa", true))
		for clave in (cfg.get_section_keys("progreso") if cfg.has_section("progreso") else PackedStringArray()):
			vistos[clave] = bool(cfg.get_value("progreso", clave, false))
	for nombre in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, nombre)
			AudioServer.set_bus_send(idx, "Master")
	aplicar()


static func aplicar() -> void:
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx == -1:
			continue
		var v: float = volumen[b]
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)
	var modo := DisplayServer.window_get_mode()
	var es_completa := modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if pantalla_completa != es_completa:
		if pantalla_completa:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			_poner_ventana()


## Sale de pantalla completa a una ventana normal. Como el juego arranca en pantalla
## completa, Windows dejaría la ventana del tamaño de todo el monitor (parece que no salió),
## así que le damos un tamaño proporcional (16:9, ~75% de la pantalla) y la centramos.
static func _poner_ventana() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Windows termina el cambio de modo un poco después; si cambiamos el tamaño de
	# inmediato, lo vuelve a poner del tamaño del monitor. Esperamos un par de frames.
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol:
		await arbol.process_frame
		await arbol.process_frame
	if pantalla_completa:
		return  # el jugador volvió a pedir pantalla completa mientras esperábamos
	var pantalla := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(pantalla)
	var base := Vector2(1152, 648)
	var escala := minf(area.size.x * 0.75 / base.x, area.size.y * 0.75 / base.y)
	var tam := Vector2i((base * escala).round())
	DisplayServer.window_set_size(tam)
	DisplayServer.window_set_position(area.position + (area.size - tam) / 2)


static func set_volumen(bus: String, valor: float) -> void:
	volumen[bus] = clampf(valor, 0.0, 1.0)
	aplicar()


static func set_pantalla_completa(activa: bool) -> void:
	pantalla_completa = activa
	aplicar()


static func guardar() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("audio", b, volumen[b])
	cfg.set_value("pantalla", "completa", pantalla_completa)
	for clave in vistos:
		cfg.set_value("progreso", clave, vistos[clave])
	cfg.save(RUTA)


## ¿Ya vio el jugador esta cosa? (por ejemplo "intro" o "tutorial_basico")
static func visto(clave: String) -> bool:
	return vistos.get(clave, false)


static func marcar_visto(clave: String) -> void:
	vistos[clave] = true
	guardar()


## Olvida todo lo visto para que la introducción y el tutorial vuelvan a salir.
static func reiniciar_vistos() -> void:
	vistos.clear()
	guardar()
