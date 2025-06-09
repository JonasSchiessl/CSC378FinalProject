# projectile.gd - ENHANCED VERSION with Sound Integration
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

# Collision layer configuration
@export var projectile_collision_layer: int = 32  # Default layer for projectiles
@export var target_collision_mask: int = 8        # What this projectile can hit

# Runtime variables
var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var distance_traveled: float = 0.0
var timer: float = 0.0
var attack: Attack
var arc_progress: float = 0.0  # 0 to 1 for arc calculation
var targets_hit: Array = []  # Keep track of targets already hit for penetration

# FIX: Add flag to prevent multiple lingering effect spawns
var has_spawned_lingering_effect: bool = false
var is_expired: bool = false

# Store the ProjectileType for sound and visual configuration
var projectile_type: ProjectileType = null

# Components
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D
@onready var area_effect_shape: CollisionShape2D = $AreaEffectZone/CollisionShape2D if has_node("AreaEffectZone/CollisionShape2D") else null
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var particles: GPUParticles2D = $TrailParticles if has_node("TrailParticles") else null

# Audio players - will be created dynamically from ProjectileType
var launch_audio_player: AudioStreamPlayer2D = null
var impact_audio_player: AudioStreamPlayer2D = null
var loop_audio_player: AudioStreamPlayer2D = null

# Set up the projectile with attack data and settings
func setup(new_attack: Attack, new_direction: Vector2, 
		   new_speed: float = speed, new_max_range: float = max_range, 
		   new_arc_height: float = arc_height, new_penetration: int = penetration,
		   new_area_effect: bool = area_effect, new_area_radius: float = area_effect_radius,
		   new_lingering: bool = create_lingering_effect, new_lingering_type: String = lingering_effect_type,
		   new_lingering_radius: float = lingering_effect_radius, new_lingering_duration: float = lingering_effect_duration,
		   new_lingering_damage: float = lingering_effect_damage,
		   projectile_type: ProjectileType = null,
		   collision_layer: int = -1, collision_mask: int = -1) -> void:
	
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
	
	# Store the projectile type for sound/visual configuration
	self.projectile_type = projectile_type
	
	# Collision layer setup
	if collision_layer != -1:
		projectile_collision_layer = collision_layer
	if collision_mask != -1:
		target_collision_mask = collision_mask
	
	# Apply collision settings to hitbox
	if hitbox_component:
		hitbox_component.collision_layer = projectile_collision_layer
		hitbox_component.collision_mask = target_collision_mask
	
	# Configure visual/audio based on projectile type
	if projectile_type:
		configure_as_type(projectile_type)
	
	# Setup particles AFTER configuring type
	setup_particles()
	
	# Update area effect shape if needed
	if area_effect and area_effect_shape != null:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = area_effect_radius
		area_effect_shape.shape = circle_shape

func _ready() -> void:
	# Save start position for range calculation
	start_position = global_position
	
	# Save original scale
	if base_scale == 0.0:
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
			if collision_shape.shape is CircleShape2D:
				var original_radius = collision_shape.shape.radius / scale_factor
				collision_shape.shape.radius = original_radius * scale_factor
			elif collision_shape.shape is RectangleShape2D:
				var original_extents = collision_shape.shape.extents / scale_factor
				collision_shape.shape.extents = original_extents * scale_factor

# ENHANCED: Setup audio players based on ProjectileType
func setup_audio_players() -> void:
	"""Setup audio players based on the ProjectileType's sound configuration"""
	if not projectile_type:
		return
	
	# Setup launch sound player
	if projectile_type.launch_sound:
		launch_audio_player = AudioStreamPlayer2D.new()
		launch_audio_player.stream = projectile_type.launch_sound
		launch_audio_player.name = "LaunchAudioPlayer"
		add_child(launch_audio_player)
		# Play launch sound immediately
		launch_audio_player.play()
		print("Playing projectile launch sound: ", projectile_type.name)
	
	# Setup impact sound player
	if projectile_type.impact_sound:
		impact_audio_player = AudioStreamPlayer2D.new()
		impact_audio_player.stream = projectile_type.impact_sound
		impact_audio_player.name = "ImpactAudioPlayer"
		add_child(impact_audio_player)
	
	# Setup loop sound player (for continuous sounds during flight)
	if projectile_type.loop_sound:
		loop_audio_player = AudioStreamPlayer2D.new()
		loop_audio_player.stream = projectile_type.loop_sound
		loop_audio_player.name = "LoopAudioPlayer"
		add_child(loop_audio_player)
		loop_audio_player.play()

func play_impact_sound() -> void:
	"""Play the impact sound from ProjectileType"""
	if impact_audio_player and impact_audio_player.stream:
		impact_audio_player.play()
		print("Playing projectile impact sound: ", projectile_type.name if projectile_type else "Unknown")

# New function to setup particles
func setup_particles() -> void:
	if not particles:
		return
	
	# Update particle direction based on projectile movement
	if particles.process_material and particles.process_material is ParticleProcessMaterial:
		var material = particles.process_material as ParticleProcessMaterial
		# Particles should emit backwards from projectile direction
		material.direction = Vector3(-direction.x, -direction.y, 0)
		# Adjust initial velocity based on projectile speed
		material.initial_velocity_min = speed * 0.1
		material.initial_velocity_max = speed * 0.3
	
	# Start emitting particles
	particles.emitting = true

# Configure this projectile to act as a specific type
func configure_as_type(projectile_type: ProjectileType) -> void:
	if not projectile_type:
		return
	
	# Ensure sprite is initialized
	if not sprite:
		sprite = $AnimatedSprite2D
		if not sprite:
			push_error("AnimatedSprite2D not found in projectile scene!")
			return
	
	# Apply visual configuration
	if projectile_type.sprite_frames:
		sprite.sprite_frames = projectile_type.sprite_frames
		sprite.play("default")
	
	if projectile_type.projectile_color != Color.WHITE:
		sprite.modulate = projectile_type.projectile_color
	
	# Apply particle configuration
	if particles:
		# Use the projectile type's specific particle material if provided
		if projectile_type.particle_material:
			particles.process_material = projectile_type.particle_material
		else:
			# Create a default particle material if none provided
			var default_material = ParticleProcessMaterial.new()
			default_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			default_material.spread = 15.0
			default_material.initial_velocity_min = 50.0
			default_material.initial_velocity_max = 100.0
			default_material.scale_min = 0.5
			default_material.scale_max = 1.0
			# Use projectile color for particles if no custom material
			default_material.color = projectile_type.projectile_color
			particles.process_material = default_material
		
		# Set particle texture if provided
		if projectile_type.particle_texture:
			particles.texture = projectile_type.particle_texture
	
	# ENHANCED: Setup audio players based on ProjectileType
	setup_audio_players()

# Function to stop particles gracefully
func stop_particles() -> void:
	if particles:
		particles.emitting = false
		# Optional: Let existing particles finish their lifetime
		var timer = get_tree().create_timer(particles.lifetime)
		timer.timeout.connect(func(): 
			if is_instance_valid(self):
				queue_free()
		)
	else:
		# If no particles, just destroy immediately
		queue_free()

# Called when hitting a hurtbox
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent and not targets_hit.has(area):
		# Add to hit targets list
		targets_hit.append(area)
		
		# Apply damage
		area.damage(attack)
		
		# ENHANCED: Play impact sound
		play_impact_sound()
		
		# Handle penetration
		penetration_remaining -= 1
		if penetration_remaining < 0:
			# FIX: Only trigger end-of-life effects once
			_handle_projectile_end()

# Called when hitting a physics body (like walls)
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Stop on solid objects
	# FIX: Only trigger end-of-life effects once
	_handle_projectile_end()

# FIX: Centralized function to handle projectile end-of-life effects
func _handle_projectile_end() -> void:
	if is_expired:
		return  # Prevent multiple calls
	
	is_expired = true
	
	# ENHANCED: Play impact sound
	play_impact_sound()
	
	if area_effect:
		trigger_area_effect()
	elif create_lingering_effect and not has_spawned_lingering_effect:
		spawn_lingering_effect()
	else:
		stop_particles()

# Trigger area effect explosion
func trigger_area_effect() -> void:
	if not area_effect or not has_node("AreaEffectZone"):
		return
	
	# Enable area effect zone
	$AreaEffectZone.set_deferred("monitoring", true)
	
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
	if create_lingering_effect and not has_spawned_lingering_effect:
		spawn_lingering_effect()
	
	# Disable collision and make invisible but don't destroy yet
	hitbox_component.set_deferred("monitoring", false)
	hitbox_component.set_deferred("monitorable", false)
	sprite.visible = false
	
	# Stop particles and handle cleanup
	stop_particles()

# Spawn a lingering effect at the current position
func spawn_lingering_effect() -> void:
	# FIX: Prevent multiple spawns
	if has_spawned_lingering_effect or not create_lingering_effect or not lingering_effect_scene:
		if not create_lingering_effect or not lingering_effect_scene:
			print("Cannot spawn lingering effect - missing scene or disabled")
		stop_particles()
		return
	
	# Mark as spawned to prevent duplicates
	has_spawned_lingering_effect = true
	
	var effect = lingering_effect_scene.instantiate()
	
	# Find the best parent for the lingering effect
	var target_parent = get_tree().current_scene
	
	# If we're in a nested scene, try to find the main game world
	var current_node = self
	while current_node.get_parent() != null:
		var parent = current_node.get_parent()
		# Look for a main game node or level node
		if parent.name.to_lower().contains("level") or parent.name.to_lower().contains("game") or parent.name.to_lower().contains("world"):
			target_parent = parent
			break
		# If we find a Node2D that's not a character, use it
		elif parent is Node2D and not parent is CharacterBody2D and not parent is RigidBody2D:
			target_parent = parent
		current_node = parent
	
	# Add to the chosen parent
	target_parent.add_child(effect)
	
	# CRITICAL: Set the global position AFTER adding to scene
	# Store position before adding to avoid any transform issues
	var spawn_position = global_position
	effect.global_position = spawn_position
	
	# Setup the effect with proper parameters
	effect.setup(null, lingering_effect_radius, 
		lingering_effect_duration, lingering_effect_damage, 
		lingering_effect_type, projectile_collision_layer,
		target_collision_mask)
	
	# Stop particles after spawning lingering effect
	stop_particles()

# Called when projectile expires (range/lifetime)
func on_projectile_expire() -> void:
	# FIX: Use centralized end handling
	_handle_projectile_end()

func set_collision_layers(layer: int, mask: int) -> void:
	projectile_collision_layer = layer
	target_collision_mask = mask
	
	if hitbox_component:
		hitbox_component.collision_layer = layer
		hitbox_component.collision_mask = mask
