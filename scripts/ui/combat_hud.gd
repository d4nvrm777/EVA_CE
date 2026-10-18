extends Control
## Barras de vida del Eva y vida / AT Field del Ángel de prueba.

@export var eva: EvaController
@export var angel: AngelDummy
@export var camera_rig: EvaCamera

const EVA_STATE_NAMES := {
	EvaCombat.State.FREE: "",
	EvaCombat.State.ATTACK: "ATACANDO",
	EvaCombat.State.GUARD: "AT FIELD",
	EvaCombat.State.STAGGER: "ATURDIDO",
	EvaCombat.State.DOWN: "CAÍDO",
}

var _eva_hp: ProgressBar
var _eva_state: Label
var _angel_hp: ProgressBar
var _angel_at: ProgressBar
var _angel_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	_eva_state = _label(bottom, "EVA")
	_eva_hp = _bar(bottom, Color(0.45, 0.95, 0.3), 360)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top)
	_angel_label = _label(top, "ÁNGEL")
	_angel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_angel_hp = _bar(top, Color(0.85, 0.15, 0.1), 520)
	_angel_at = _bar(top, Color(1.0, 0.55, 0.1), 520)
	_angel_at.custom_minimum_size.y = 8


func _process(_delta: float) -> void:
	if eva and eva.combat:
		var c := eva.combat
		_eva_hp.value = c.health / c.max_health * 100.0
		var state_name: String = EVA_STATE_NAMES[c.state]
		_eva_state.text = "EVA" if state_name.is_empty() else "EVA  ·  " + state_name
	if angel:
		_angel_hp.value = angel.health / angel.max_health * 100.0
		_angel_at.value = angel.at / angel.max_at * 100.0
		var status := "NÚCLEO EXPUESTO" if angel.broken else "AT FIELD"
		if angel.state == AngelDummy.State.DEFEATED:
			status = "DERROTADO"
		if camera_rig and camera_rig.lock_target == angel:
			status += "  ·  FIJADO"
		_angel_label.text = "ÁNGEL DE PRUEBA  ·  " + status


func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


func _bar(parent: Control, color: Color, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 14)
	bar.show_percentage = false
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar
