extends CanvasLayer
class_name DeathScreen

@onready var death_panel = $ColorRect
@onready var restart_button = $Button
@onready var death_message = $DeathMessage

var is_visible = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if restart_button and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)

func show_death_screen() -> void:
	if not is_inside_tree():
		call_deferred("show_death_screen")
		return

	is_visible = true
	visible = true

	get_tree().paused = true
	
	if restart_button:
		restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if death_panel:
		var tween = create_tween()
		death_panel.modulate.a = 0.0
		tween.tween_property(death_panel, "modulate:a", 1.0, 0.5)

func hide_death_screen() -> void:
	is_visible = false
	visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	print("Restart button pressed!")
	hide_death_screen()
	get_tree().reload_current_scene()

func set_death_message(message: String) -> void:
	if death_message:
		death_message.text = message
