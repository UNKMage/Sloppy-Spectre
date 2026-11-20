class_name MusicaProcedural
extends RefCounted
## Sintetiza las pistas de música del juego (estilo chiptune) sin archivos de audio.
## Devuelve un AudioStreamWAV en bucle. Pistas: "menu" (calmada) y "juego" (más tensa).
## Pensado para llamarse en un hilo: tarda un par de segundos en generar cada pista.

const RATE := 16000
const COMPASES := 8
## Raíz de cada compás en semitonos sobre La2 (110 Hz) y si el acorde es menor.
const PROGRESION := [
	[0, true], [-4, false], [3, false], [-2, false],
	[0, true], [-4, false], [-2, false], [-5, true],
]
const ONDA_PULSO := 0
const ONDA_TRIANGULO := 1
const ONDA_SENO := 2
const ONDA_RUIDO := 3


static func generar(pista: String) -> AudioStreamWAV:
	var bpm := 82.0 if pista == "menu" else 118.0
	var beat := 60.0 / bpm
	var total := int(COMPASES * 4.0 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for c in COMPASES:
		var raiz: int = PROGRESION[c][0]
		var menor: bool = PROGRESION[c][1]
		var tercera := 3 if menor else 4
		var tonos := [0, tercera, 7, 12]
		var t0 := c * 4.0 * beat
		if pista == "menu":
			_compas_menu(buf, t0, beat, raiz, tonos)
		else:
			_compas_juego(buf, t0, beat, raiz, tonos, c)
	# Normalizar y pasar a 16 bits.
	var pico := 0.001
	for i in total:
		pico = maxf(pico, absf(buf[i]))
	var k := 0.8 / pico
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * k, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav


static func _freq(semitonos: int) -> float:
	return 110.0 * pow(2.0, semitonos / 12.0)


static func _compas_menu(buf: PackedFloat32Array, t0: float, beat: float, raiz: int, tonos: Array) -> void:
	# Bajo largo
	_nota(buf, t0, beat * 4.0, _freq(raiz), ONDA_TRIANGULO, 0.30, 0.02, 0.6, 0.35)
	# Colchón suave (quinta y tercera)
	_nota(buf, t0, beat * 4.0, _freq(raiz + 12), ONDA_SENO, 0.07, 0.4, 0.5, 0.8)
	_nota(buf, t0, beat * 4.0, _freq(raiz + 19), ONDA_SENO, 0.05, 0.4, 0.5, 0.8)
	# Arpegio de corcheas, como campanitas
	var patron := [0, 2, 1, 2, 3, 2, 1, 2]
	for i in 8:
		var semi: int = raiz + 12 + tonos[patron[i]]
		_nota(buf, t0 + i * beat * 0.5, beat * 0.9, _freq(semi), ONDA_TRIANGULO, 0.16, 0.004, 3.2, 0.1)
	# Melodía lenta encima en los compases pares
	if int(t0 / (beat * 4.0)) % 2 == 0:
		_nota(buf, t0 + beat * 2.0, beat * 1.5, _freq(raiz + 24 + tonos[2]), ONDA_SENO, 0.10, 0.02, 1.8, 0.3)


static func _compas_juego(buf: PackedFloat32Array, t0: float, beat: float, raiz: int, tonos: Array, compas: int) -> void:
	# Bombo en cada tiempo (suave) para dar pulso
	for b in 4:
		_bombo(buf, t0 + b * beat, 0.26 if b % 2 == 0 else 0.16)
	# Bajo en corcheas
	var oct := [0, 0, 12, 0, 0, 12, 0, 7]
	for i in 8:
		_nota(buf, t0 + i * beat * 0.5, beat * 0.45, _freq(raiz + oct[i]), ONDA_PULSO, 0.20, 0.003, 5.0, 0.25)
	# Platillo en los contratiempos
	for i in 4:
		_nota(buf, t0 + (i + 0.5) * beat, beat * 0.12, 1.0, ONDA_RUIDO, 0.06, 0.001, 30.0, 0.12)
	# Arpegio de semicorcheas
	var patron := [0, 1, 2, 1, 3, 2, 1, 2, 0, 2, 3, 2, 1, 3, 2, 1]
	var alto := 24 if compas % 4 == 3 else 12
	for i in 16:
		var semi: int = raiz + alto + tonos[patron[i]]
		_nota(buf, t0 + i * beat * 0.25, beat * 0.5, _freq(semi), ONDA_PULSO, 0.10, 0.002, 7.0, 0.125)
	# Eco del arpegio, más suave y retrasado
	for i in 16:
		if i % 2 == 0:
			var semi2: int = raiz + 12 + tonos[patron[i]]
			_nota(buf, t0 + i * beat * 0.25 + beat * 0.375, beat * 0.4, _freq(semi2), ONDA_TRIANGULO, 0.05, 0.002, 6.0, 0.5)


## Suma una nota al búfer. `decay` es la caída exponencial; `duty` solo afecta a la onda de pulso.
static func _nota(buf: PackedFloat32Array, inicio: float, dur: float, freq: float, onda: int,
		vol: float, ataque: float, decay: float, duty: float) -> void:
	var i0 := int(inicio * RATE)
	var n := int(dur * RATE)
	var fin := mini(i0 + n, buf.size())
	var fase := 0.0
	var paso := freq / RATE
	var liberar := minf(0.04, dur * 0.3)
	for i in range(i0, fin):
		var t := float(i - i0) / RATE
		var env := minf(1.0, t / maxf(ataque, 0.0005)) * exp(-decay * t)
		var resto := dur - t
		if resto < liberar:
			env *= resto / liberar
		var s := 0.0
		match onda:
			ONDA_PULSO:
				s = 1.0 if fase < duty else -1.0
			ONDA_TRIANGULO:
				s = 4.0 * absf(fase - 0.5) - 1.0
			ONDA_SENO:
				s = sin(fase * TAU)
			_:
				s = randf() * 2.0 - 1.0
		buf[i] += s * env * vol
		fase += paso
		if fase >= 1.0:
			fase -= 1.0


static func _bombo(buf: PackedFloat32Array, inicio: float, vol: float) -> void:
	var i0 := int(inicio * RATE)
	var n := int(0.16 * RATE)
	var fin := mini(i0 + n, buf.size())
	var fase := 0.0
	for i in range(i0, fin):
		var t := float(i - i0) / RATE
		var f := 40.0 + 110.0 * exp(-t * 28.0)
		fase += f / RATE
		buf[i] += sin(fase * TAU) * exp(-t * 18.0) * vol
