extends Node2D

@export var spawn_radius: float = 800 # Radius around the player
@onready var parent = get_parent()
@onready var player = parent.get_node_or_null("Player")
@onready var enemy_container

var PoisonRatClass = preload("res://Scenes/Enemies/poison_rat.tscn")
var MeleeRatClass = preload("res://Scenes/Enemies/melee_rat.tscn")


func _ready() -> void:
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)


func start_wave(enemy_type, amount) -> void:
	var EnemyClass = null
	if enemy_type == "poison_rat":
		EnemyClass = PoisonRatClass
	elif enemy_type == "melee_rat":
		EnemyClass = MeleeRatClass
	
	for i in range(amount):
		var enemy = EnemyClass.instantiate()
		var angle = randf_range(0,2*PI)
		var spawn_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
		enemy.global_position = spawn_position
		enemy_container.add_child(enemy)


func end_wave() -> void:
	if is_instance_valid(enemy_container):
		enemy_container.queue_free()
		enemy_container = null
	
	$Timer.stop()

# Handle phase changes
func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.FIGHT:
			# Create a dedicated container for enemies
			enemy_container = Node2D.new()
			enemy_container.name = "Enemies"
			parent.add_child(enemy_container)
			$Timer.start()
		GameManager.Phase.BUILD:
			end_wave()

func _on_timer_timeout() -> void:
	if player: # Start a random wave - WILL PROBABLY BE REMOVED AFTER ACTUAL WAVE IMPLEMENTATION, IT'S LIKE THIS NOW FOR SIMULATION
		if randi_range(0,1) == 0:
			start_wave("poison_rat", randi_range(2, 3))
		else:
			start_wave("melee_rat", randi_range(2, 4))
