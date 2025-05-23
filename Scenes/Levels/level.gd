extends Node2D
func _ready():
	# Create a dedicated container for towers
	var tower_container = Node2D.new()
	tower_container.name = "Towers"
	add_child(tower_container)
