class_name DevHud
extends CanvasLayer
const FLASH_SECONDS := 1.7
var pip: PipController
var section := ""
var _banner: Label
var _flash := 0.0
var _finished := false
func _ready() -> void:
	_banner = Label.new()
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_banner.offset_top = 34.0
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_color", Color("#FFF6E8"))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color("#2E2A47"))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
func flash(text: String) -> void:
	if _finished:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", Color("#FFF6E8"))
	_flash = FLASH_SECONDS
func finish() -> void:
	_finished = true
	_banner.text = "FINISHED!"
	_banner.add_theme_color_override("font_color", Color("#FFD84D"))
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.modulate.a = 1.0
func _process(delta: float) -> void:
	if _finished or _banner == null:
		return
	_flash = maxf(_flash - delta, 0.0)
	_banner.modulate.a = minf(_flash / 0.45, 1.0)
