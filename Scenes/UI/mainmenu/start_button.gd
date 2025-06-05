extends TextureButton
@export var default_color := Color(0.012, 1.0, 0.251)
@export var pressed_color := Color(0.0, 0.342, 0.025)
var label: RichTextLabel
signal button_is_pressed

func _ready():
	label = get_node_or_null("RichTextLabel")
	if label == null:
		push_error("RichTextLabel not found! Check node path.")
		return
	
	update_label_color(default_color)

func update_label_color(color: Color):
	label.modulate = color

func _on_button_down() -> void:
	if label:
		update_label_color(pressed_color)

func _on_button_up() -> void:
	button_is_pressed.emit()
	if label:
		update_label_color(default_color)
