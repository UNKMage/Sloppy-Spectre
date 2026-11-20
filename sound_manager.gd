extends Node

# Rutas de los efectos de sonido
var snd_disparo: AudioStream = null
var snd_stun: AudioStream = null
var snd_recarga: AudioStream = null
var snd_alerta: AudioStream = null
var snd_gameover: AudioStream = null

# Reproductores con control de pausa/detención continua
var _player_alerta: AudioStreamPlayer = null
var _player_recarga: AudioStreamPlayer = null


## --- Música de fondo (se sintetiza al abrir el juego, ver MusicaProcedural) ---
const MUSICA := preload("res://musica_procedural.gd")
const NIVELES_JUEGO := ["res://main.tscn", "res://nivel_1.tscn", "res://nivel_2.tscn", "res://nivel_3.tscn", "res://tutorial_nivel.tscn"]
const VOLUMEN_MUSICA_DB := -9.0
var _musica: AudioStreamPlayer = null
var _pistas: Dictionary = {}
var _hilo: Thread = null
var _pista_actual: String = ""
var _volumen_fade: float = 0.0  # 0..1, para los fundidos entre pistas


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_sonidos()
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = -80.0
	add_child(_musica)
	_hilo = Thread.new()
	_hilo.start(_generar_pistas)


func _exit_tree() -> void:
	if _hilo != null and _hilo.is_started():
		_hilo.wait_to_finish()


func _generar_pistas() -> void:
	var resultado := {}
	for nombre in ["menu", "juego"]:
		resultado[nombre] = MUSICA.generar(nombre)
	_pistas_listas.call_deferred(resultado)


func _pistas_listas(resultado: Dictionary) -> void:
	_pistas = resultado


func _pista_deseada() -> String:
	var escena := get_tree().current_scene
	if escena != null and escena.scene_file_path in NIVELES_JUEGO:
		return "juego"
	return "menu"


func _process(delta: float) -> void:
	if _pistas.is_empty():
		return
	if AudioServer.get_bus_index("Musica") != -1 and _musica.bus != &"Musica":
		_musica.bus = &"Musica"
	var deseada := _pista_deseada()
	if deseada != _pista_actual:
		# Baja la actual y, al llegar a silencio, cambia de pista.
		_volumen_fade = move_toward(_volumen_fade, 0.0, delta * 2.5)
		if _volumen_fade <= 0.0:
			_pista_actual = deseada
			_musica.stream = _pistas[deseada]
			_musica.play()
	else:
		_volumen_fade = move_toward(_volumen_fade, 1.0, delta * 1.2)
	# En pausa la música baja para que se oiga el menú.
	var duck := -7.0 if get_tree().paused else 0.0
	_musica.volume_db = linear_to_db(maxf(_volumen_fade, 0.0001)) + VOLUMEN_MUSICA_DB + duck


func _cargar_sonidos() -> void:
	if ResourceLoader.exists("res://sonidos/sfx_disparo.wav"):
		snd_disparo = load("res://sonidos/sfx_disparo.wav")
	if ResourceLoader.exists("res://sonidos/sfx_stun.wav"):
		snd_stun = load("res://sonidos/sfx_stun.wav")
	if ResourceLoader.exists("res://sonidos/sfx_recarga.wav"):
		snd_recarga = load("res://sonidos/sfx_recarga.wav")
	if ResourceLoader.exists("res://sonidos/sfx_alerta.wav"):
		snd_alerta = load("res://sonidos/sfx_alerta.wav")
	if ResourceLoader.exists("res://sonidos/sfx_gameover.wav"):
		snd_gameover = load("res://sonidos/sfx_gameover.wav")


func reproducir_sfx(stream: AudioStream, volumen_db: float = 0.0) -> void:
	if stream == null:
		return
		
	var player := AudioStreamPlayer.new()
	_usar_bus_efectos(player)
	player.stream = stream
	player.volume_db = volumen_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func reproducir_disparo() -> void:
	reproducir_sfx(snd_disparo, -2.0)


func reproducir_stun() -> void:
	reproducir_sfx(snd_stun, 0.0)


## Inicia el sonido continuo mientras se recarga en el portal
func iniciar_recarga() -> void:
	if snd_recarga == null:
		return
	if _player_recarga == null:
		_player_recarga = AudioStreamPlayer.new()
		_usar_bus_efectos(_player_recarga)
		_player_recarga.stream = snd_recarga
		_player_recarga.volume_db = -3.0
		_player_recarga.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_player_recarga)
	if not _player_recarga.playing:
		_player_recarga.play()


## Detiene el sonido si sale del portal o si termina de recargar
func detener_recarga() -> void:
	if _player_recarga and _player_recarga.playing:
		_player_recarga.stop()


func reproducir_alerta() -> void:
	if snd_alerta == null:
		return
	if _player_alerta == null:
		_player_alerta = AudioStreamPlayer.new()
		_usar_bus_efectos(_player_alerta)
		_player_alerta.stream = snd_alerta
		_player_alerta.volume_db = 1.0
		_player_alerta.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_player_alerta)
	_player_alerta.play()


func detener_alerta() -> void:
	if _player_alerta and _player_alerta.playing:
		_player_alerta.stop()


func reproducir_gameover() -> void:
	# Por seguridad, si estaba sonando la recarga o la alerta, se apagan
	detener_alerta()
	detener_recarga()
	reproducir_sfx(snd_gameover, 0.0)


## Los efectos suenan por el bus "Efectos" (lo crea Opciones), para tener su propio volumen.
func _usar_bus_efectos(player: AudioStreamPlayer) -> void:
	if AudioServer.get_bus_index("Efectos") != -1:
		player.bus = "Efectos"


## Al pausar el juego se callan la alerta y la recarga; al continuar, siguen donde iban.
func pausar_juego(pausado: bool) -> void:
	for p in [_player_alerta, _player_recarga]:
		if p != null:
			p.stream_paused = pausado
