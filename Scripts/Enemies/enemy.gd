extends StaticBody2D

@export var speed = 1

@onready var projectile_emitter = $projectile_emitter
@onready var parent = get_parent()
@onready var player

func _ready() -> void:
	# Initialize player var based on its place in the scene tree
	if get_parent().get_node_or_null("Player"):
		player = get_parent().get_node("Player")
	elif get_parent().get_parent().get_node_or_null("Player"):
		player = get_parent().get_parent().get_node_or_null("Player")
	
	#Miguel-added code for enemy detection for shooting at with towers
	# Debug collision layers
	add_to_group("enemies")
	print("=== ENEMY COLLISION DEBUG ===")
	print("Enemy collision layer: ", collision_layer)
	print("Enemy collision mask: ", collision_mask)
	print("Enemy is in enemies group: ", is_in_group("enemies"))
	print("=============================")
	
	
	# Create projectile_timer, which fires projectiles at the player on timeout
	var projectile_timer : Timer = Timer.new()
	add_child(projectile_timer)
	projectile_timer.wait_time = 3
	projectile_timer.timeout.connect(func(): fire_projectile())
	projectile_timer.start()

func _physics_process(delta: float) -> void:
	if global_position.distance_to(player.global_position) < 100:
		$AnimationPlayer.play("idle")
		return
	var direction = (player.global_position - global_position).normalized()
	if direction.x < 0: # Run left animation
		$Sprite.flip_h = false
		$AnimationPlayer.play("run")
	elif direction.x > 0: # Run right animation
		$Sprite.flip_h = true
		$AnimationPlayer.play("run")
	global_position += direction * speed

func fire_projectile():
	var direction = (player.global_position - global_position).normalized()
	projectile_emitter.fire_projectile(direction)

# Handle health change logic
func _on_health_component_health_change(old_value: Variant, new_value: Variant) -> void:
	print("Enemy took damage! Health: ", old_value, " -> ", new_value)
	
	# Flashing logic and damage number
	if new_value < old_value:
		print("took damage")

# Handle death logic
func _on_health_component_health_depleted() -> void:
	print("Enemy died!")
	
	# Stop movement and attacks
	set_physics_process(false)
	queue_free()
