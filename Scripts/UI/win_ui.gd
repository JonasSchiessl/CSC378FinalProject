extends Control
class_name WinUI

func _ready() -> void:
	visible = false

func _on_menu_button_is_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/mainmenu/main_menu.tscn")

func start_UI():
	visible = true
