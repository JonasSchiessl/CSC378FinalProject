# projectile.gd
extends Node2D
class_name Projectile

# Basic projectile properties
@export var speed: float = 300.0
@export var max_range: float = 1000.0
@export var lifetime: float = 5.0

# Arc properties
@export var arc_height: float = 0.0  # 0 for no arc/scaling, >0 for max scale increase
@export var base_scale: float = 1.0  # Original scale of the sprite

# Penetration
@export var penetration: int = 0  # 0 = no penetration, 1+ = number of targets to penetrate
var penetration_remaining: int = 0

# Area effect
@export var area_effect: bool = false
@export var area_effect_radius: float = 100.0
@export var area_effect_falloff: bool = true  # Damage falloff with distance

# Lingering effect properties
@export var create_lingering_effect: bool = false
@export var lingering_effect_scene: PackedScene
@export var lingering_effect_type: String = "fire"
@export var lingering_effect_radius: float = 100.0
@export var lingering_effect_duration: float = 5.0
@export var lingering_effect_damage: float = 1.0

# Runtime variables
var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var distance_traveled: float = 0.0
var timer: float = 0.0
var attack: Attack
var arc_progress: float = 0.0  # 0 to 1 for arc calculation
var targets_hit: Array = []  # Keep track of targets already hit for penetration

# Components
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D
@onready var area_effect_shape: CollisionShape2D = $AreaEffectZone/CollisionShape2D if has_node("AreaEffectZone/CollisionShape2D") else null
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Save start position for range calculation
	start_position = global_position
	
	# Save original scale
	base_scale = sprite.scale.x
	
	# Initialize penetration
	penetration_remaining = penetration
	
	# Set up area effect if enabled
	if area_effect and has_node("AreaEffectZone"):
		$AreaEffectZone.monitoring = false
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = area_effect_radius
		area_effect_shape.shape = circle_shape
	
	# Connect hitbox signals
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)
	hitbox_component.body_entered.connect(_on_hitbox_body_entered)
	
	# Enable hitbox
	hitbox_component.active = true
	hitbox_component.monitoring = true

func _physics_process(delta: float) -> void:
	# Update timer
	timer += delta
	
	# Calculate distance to travel this frame
	var frame_distance = speed * delta
	distance_traveled += frame_distance
	
	# Check if projectile has reached max range or lifetime
	if distance_traveled >= max_range or timer >= lifetime:
		on_projectile_expire()
		return
	
	# Move projectile
	global_position += direction * frame_distance
	
	# Rotate sprite to face direction
	sprite.rotation = direction.angle()
	
	# Handle arc scaling effect if enabled
	if arc_height > 0:
		# Calculate arc progress (0 to 1)
		arc_progress = distance_traveled / max_range
		
		# For top-down game, we'll use a parabolic scale curve
		# This gives maximum scale in the middle of the trajectory
		var scale_factor = 1.0 + (arc_height * sin(arc_progress * PI))
		
		# Apply scale to both sprite and hitbox
		sprite.scale = Vector2(base_scale, base_scale) * scale_factor
		
		# Also scale the collision shape if it exists
		if collision_shape and collision_shape.shape:
			# Note: This assumes the shape's original size is correctly set
			# You might need to adjust this based on your collision shape type
			if collision_shape.shape is CircleShape2D:
				var original_radius = collision_shape.shape.radius / scale_factor
				collision_shape.shape.radius = original_radius * scale_factor
			elif collision_shape.shape is RectangleShape2D:
				var original_extents = collision_shape.shape.extents / scale_factor
				collision_shape.shape.extents = original_extents * scale_factor

# Set up the projectile with attack data and settings
func setup(new_attack: Attack, new_direction: Vector2, 
		   new_speed: float = speed, new_max_range: float = max_range, 
		   new_arc_height: float = arc_height, new_penetration: int = penetration,
		   new_area_effect: bool = area_effect, new_area_radius: float = area_effect_radius,
		   new_lingering: bool = create_lingering_effect, new_lingering_type: String = lingering_effect_type,
		   new_lingering_radius: float = lingering_effect_radius, new_lingering_duration: float = lingering_effect_duration,
		   new_lingering_damage: float = lingering_effect_damage) -> void:
	attack = new_attack
	direction = new_direction.normalized()
	speed = new_speed
	max_range = new_max_range
	arc_height = new_arc_height
	penetration = new_penetration
	penetration_remaining = penetration
	area_effect = new_area_effect
	area_effect_radius = new_area_radius
	
	# Lingering effect parameters
	create_lingering_effect = new_lingering
	lingering_effect_type = new_lingering_type
	lingering_effect_radius = new_lingering_radius
	lingering_effect_duration = new_lingering_duration
	lingering_effect_damage = new_lingering_damage
	
	# Update area effect shape if needed
	if area_effect and area_effect_shape != null:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = area_effect_radius
		area_effect_shape.shape = circle_shape

# Called when hitting a hurtbox
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent and not targets_hit.has(area):
		# Add to hit targets list
		targets_hit.append(area)
		
		# Apply damage
		area.damage(attack)
		
		# Handle penetration
		penetration_remaining -= 1
		if penetration_remaining < 0:
			if area_effect:
				trigger_area_effect()
			elif create_lingering_effect:
				spawn_lingering_effect()
			queue_free()

# Called when hitting a physics body (like walls)
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Stop on solid objects
	if area_effect:
		trigger_area_effect()
	elif create_lingering_effect:
		spawn_lingering_effect()
	queue_free()

# Trigger area effect explosion
func trigger_area_effect() -> void:
	if not area_effect or not has_node("AreaEffectZone"):
		return
	
	# Enable area effect zone
	$AreaEffectZone.monitoring = true
	
	# Find all hurtboxes in area
	var overlapping_areas = $AreaEffectZone.get_overlapping_areas()
	
	# Apply damage to each hurtbox in area
	for area in overlapping_areas:
		if area is HurtboxComponent and not targets_hit.has(area):
			var distance = global_position.distance_to(area.global_position)
			var damage_multiplier = 1.0
			
			# Apply damage falloff based on distance
			if area_effect_falloff and distance > 0:
				damage_multiplier = 1.0 - (distance / area_effect_radius)
				damage_multiplier = max(0.1, damage_multiplier)  # At least 10% damage
			
			# Create a modified attack with adjusted damage
			var area_attack = Attack.new(
				attack.attack_damage * damage_multiplier,
				(area.global_position - global_position).normalized() * attack.knockback_force.length(),
				attack.attack_source
			)
			
			# Apply damage
			area.damage(area_attack)
	
	# Spawn lingering effect if needed
	if create_lingering_effect:
		spawn_lingering_effect()
	
	# Disable collision and make invisible but don't destroy yet
	hitbox_component.monitoring = false
	hitbox_component.monitorable = false
	sprite.visible = false
	
	# Create timer to destroy after effects finish
	var timer = get_tree().create_timer(0.5)  # Adjust as needed
	timer.timeout.connect(queue_free)

# Spawn a lingering effect at the current position
func spawn_lingering_effect() -> void:
	if not create_lingering_effect or not lingering_effect_scene:
		return
		
	var effect = lingering_effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.setup(attack.attack_source, lingering_effect_radius, 
				lingering_effect_duration, lingering_effect_damage, 
				lingering_effect_type)

# Called when projectile expires (range/lifetime)
func on_projectile_expire() -> void:
	if area_effect:
		trigger_area_effect()
	elif create_lingering_effect:
		spawn_lingering_effect()
	queue_free()
