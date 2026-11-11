shader_type canvas_item;

// Debe coincidir con RAYOS de vision_cono.gd (el arreglo tiene RAYOS + 1 elementos).
const int RAYOS = 32;

uniform vec2 origen = vec2(0.0);
uniform float angulo_centro = 0.0;
uniform float media_apertura = 0.61;
uniform float distancias[33];
uniform float suavizado_px = 70.0;
uniform float radio_cercano = 40.0;
uniform float ancho_base = 60.0;

uniform float nube_irregularidad_px = 35.0;
uniform float nube_tamano_px = 90.0;
uniform float nube_velocidad = 0.08;
uniform float variacion_sombra = 0.25;
uniform vec3 tinte_sombra : source_color = vec3(0.82, 0.84, 1.0);

// Fuera del cono: el color se multiplica por brillo_fuera y el alfa por opacidad_fuera.
uniform float brillo_fuera = 0.5;
uniform float opacidad_fuera = 1.0;

varying vec2 mundo;

void vertex() {
	// Posición en coordenadas del mundo: el efecto no depende de la cámara ni del nodo.
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// fBm de 3 octavas, normalizado a ~0..1.
float nube(vec2 p) {
	float suma = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 3; k++) {
		suma += ruido(p) * amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return suma / 0.875;
}

float visibilidad(vec2 p) {
	vec2 v = p - origen;
	float r = length(v);

	float cerca = 1.0 - smoothstep(radio_cercano * 0.5, radio_cercano, r);

	float a = atan(v.y, v.x) - angulo_centro;
	a = atan(sin(a), cos(a));

	// Los lados del cono parten de un vértice desplazado hacia atrás, así el cono nace
	// con ancho (ancho_base) en Spooky en vez de en una punta.
	float retroceso = ancho_base / tan(media_apertura);
	vec2 apice = origen - vec2(cos(angulo_centro), sin(angulo_centro)) * retroceso;
	vec2 w = p - apice;
	float a_lado = atan(w.y, w.x) - angulo_centro;
	a_lado = atan(sin(a_lado), cos(a_lado));
	float lateral = (media_apertura - abs(a_lado)) * length(w);

	float t = clamp((a + media_apertura) / (2.0 * media_apertura), 0.0, 1.0) * float(RAYOS);
	int i = min(int(floor(t)), RAYOS - 1);
	float alcance = mix(distancias[i], distancias[i + 1], t - float(i));
	float radial = alcance - r;

	vec2 deriva = vec2(TIME * nube_velocidad * nube_tamano_px, TIME * nube_velocidad * 0.6 * nube_tamano_px);
	float desplazamiento = (nube((p + deriva) / nube_tamano_px) - 0.5) * 2.0 * nube_irregularidad_px;
	desplazamiento *= smoothstep(0.0, 200.0, r);

	float en_cono = smoothstep(0.0, suavizado_px, min(lateral, radial) + desplazamiento);
	return max(en_cono, cerca);
}

void fragment() {
	float vis = visibilidad(mundo);
	vec3 oscuro = vec3(brillo_fuera);
	if (brillo_fuera < 0.999) {
		float n = nube((mundo + vec2(TIME * nube_velocidad * nube_tamano_px * 0.5)) / (nube_tamano_px * 2.5));
		float brillo = brillo_fuera * (1.0 + (n - 0.5) * 2.0 * variacion_sombra);
		oscuro = brillo * tinte_sombra;
	}
	COLOR.rgb *= mix(oscuro, vec3(1.0), vis);
	COLOR.a *= mix(opacidad_fuera, 1.0, vis);
}
