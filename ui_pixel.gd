class_name UIPixel
extends RefCounted
## Piezas de interfaz en pixel art compartidas por el menú de pausa y las opciones:
## fuente pixel con acentos, etiquetas con contorno y botones con caja de pixel art.

const FUENTE_PIXEL := preload("res://addons/pixel_bars/font/pixel_ui_font.fnt")
static var _fuente: Font


## Fuente pixel del HUD, con la fuente normal de respaldo para acentos y símbolos.
static func fuente() -> Font:
	if _fuente == null:
		_fuente = FUENTE_PIXEL.duplicate()
		_fuente.fallbacks = [ThemeDB.fallback_font]
	return _fuente


static func etiqueta(texto: String, tamano: int, color: Color, contorno: int = 0,
		alineacion: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente())
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	if contorno > 0:
		l.add_theme_constant_override("outline_size", contorno)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
	l.horizontal_alignment = alineacion
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func boton(texto: String, color: Color, tam: Vector2 = Vector2(300, 54), tamano_fuente: int = 22) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tam
	b.size = tam
	b.add_theme_font_override("font", fuente())
	b.add_theme_font_size_override("font_size", tamano_fuente)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_focus_color", color)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", PixelCaja.nueva(Color(0.07, 0.06, 0.13), color.darkened(0.45)))
	b.add_theme_stylebox_override("hover", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
	b.add_theme_stylebox_override("focus", PixelCaja.nueva(Color(0.12, 0.11, 0.22), color, color.darkened(0.55), true))
	b.add_theme_stylebox_override("pressed", PixelCaja.nueva(Color(0.18, 0.16, 0.3), Color.WHITE, color, true))
	b.add_theme_stylebox_override("disabled", PixelCaja.nueva(Color(0.06, 0.05, 0.1), Color(0.3, 0.3, 0.4)))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	return b


## El autoload SoundManager, buscado por ruta (así estos scripts compilan aunque se carguen antes que los autoloads).
static func sonido() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SoundManager")
