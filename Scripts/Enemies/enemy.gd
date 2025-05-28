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
