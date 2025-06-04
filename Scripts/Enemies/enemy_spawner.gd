extends Node2D

@export var spawn_radius: float = 400 # Radius around the player
@export var enemies_per_wave: int = 5

@onready var parent = get_parent()
@onready var player = parent.get_node_or_null("Player")
@onready var enemy_container
@onready var wave_label = $WaveText

var EnemyClass = preload("res://Scenes/Enemies/Enemy.tscn")

var current_wave: int = 0
var enemies_remaining: int = 0

func _ready() -> void:
	if GameManager.instance:
		GameManager.instance.phase_changed.connect(_on_phase_changed)
	wave_label.visible = false

func start_wave() -> void:
	current_wave += 1
	enemies_remaining = enemies_per_wave * current_wave
	update_wave_label()

	print("WAVE STARTED")
	
	# Create a dedicated container for enemies
	enemy_container = Node2D.new()
	enemy_container.name = "Enemies"
	parent.add_child(enemy_container)
	
	wave_label.visible = true
	$Timer.start()

func end_wave() -> void:
	print("WAVE ENDED")

	if is_instance_valid(enemy_container):
		enemy_container.queue_free()
		enemy_container = null

	wave_label.visible = false
	$Timer.stop()

func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	match new_phase:
		GameManager.Phase.FIGHT:
			start_wave()
		GameManager.Phase.BUILD:
			end_wave()

func _on_timer_timeout() -> void:
	if player and enemies_remaining > 0:
		var enemy = EnemyClass.instantiate()
		var angle = randf_range(0, 2 * PI)
		var spawn_position = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
		enemy.global_position = spawn_position
		enemy_container.add_child(enemy)

		enemies_remaining -= 1
		update_wave_label()
		if current_wave > 5:
			$Timer.stop()
		if enemies_remaining <= 0:
			print("All enemies defeated, starting next wave")
			start_wave()

func update_wave_label() -> void:
	wave_label.text = "Wave %d: %d Enemies To Spawn" % [current_wave, enemies_remaining]

