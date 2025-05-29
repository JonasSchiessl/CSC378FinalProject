extends Node2D

@onready var player = $Player
var death_screen: DeathScreen

func _ready():
	death_screen = preload("res://Scenes/Player/death_screen.tscn").instantiate()
	add_child(death_screen) 
	var tower_container = Node2D.new()
	tower_container.name = "Towers"
	add_child(tower_container)

	$Player.player_death.connect(_on_player_death)

	$DeathScreen.visible = false  # Hide UI at start

func _on_player_death():
	death_screen.show_death_screen()
