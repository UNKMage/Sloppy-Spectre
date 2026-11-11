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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_sonidos()


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
