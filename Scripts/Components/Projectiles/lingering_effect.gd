# lingering_effect.gd
extends Node2D
class_name LingeringEffect

# Effect properties
@export var effect_radius: float = 100.0
@export var effect_duration: float = 5.0
@export var damage_per_tick: float = 1.0
@export var tick_rate: float = 0.5  # How often to apply damage (seconds)
@export var effect_type: String = "fire"  # fire, poison, ice, etc.

# Visual settings
@export var effect_color: Color = Color(1.0, 0.5, 0.0, 0.7)  # Orange for fire

# Internal variables
var attack_source: Node2D
var timer: float = 0.0
var tick_timer: float = 0.0
var affected_entities: Dictionary = {}  # Track which entities are in the area

# Components
@onready var effect_area: Area2D = $EffectArea
@onready var collision_shape: CollisionShape2D = $EffectArea/CollisionShape2D
@onready var particles: GPUParticles2D = $EffectParticles
@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

func _ready() -> void:
	# Set up collision shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = effect_radius
	collision_shape.shape = circle_shape
	
	# Configure particles based on effect type
	configure_effect_visuals()
	
	# Connect area signals
	effect_area.area_entered.connect(_on_area_entered)
	effect_area.area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
	# Update lifetime timer
	timer += delta
	if timer >= effect_duration:
		queue_free()
		return
	
	# Update tick timer for damage application
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		apply_damage_tick()
	
	# Optional: Fade out effect near the end
	if timer > effect_duration * 0.7:
		var fade_factor = 1.0 - ((timer - (effect_duration * 0.7)) / (effect_duration * 0.3))
		particles.modulate.a = fade_factor
		if light:
			light.energy = fade_factor * 0.8  # Assuming base energy is 0.8

# Initialize the lingering effect
func setup(source: Node2D, radius: float = effect_radius, duration: float = effect_duration, 
		   damage: float = damage_per_tick, type: String = effect_type) -> void:
	attack_source = source
	effect_radius = radius
	effect_duration = duration
	damage_per_tick = damage
	effect_type = type
	
	# Update collision shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = effect_radius
	collision_shape.shape = circle_shape
	
	# Update visuals
	configure_effect_visuals()

# Configure visuals based on effect type
func configure_effect_visuals() -> void:
	match effect_type:
		"fire":
			particles.process_material.color = Color(1.0, 0.5, 0.0, 0.7)
			if light:
				light.color = Color(1.0, 0.5, 0.0, 0.7)
				light.energy = 0.8
		"poison":
			particles.process_material.color = Color(0.0, 0.8, 0.0, 0.7)
			if light:
				light.color = Color(0.0, 0.8, 0.0, 0.7)
				light.energy = 0.6
		"ice":
			particles.process_material.color = Color(0.5, 0.8, 1.0, 0.7)
			if light:
				light.color = Color(0.5, 0.8, 1.0, 0.7)
				light.energy = 0.5
		"acid":
			particles.process_material.color = Color(0.8, 0.8, 0.0, 0.7)
			if light:
				light.color = Color(0.8, 0.8, 0.0, 0.7)
				light.energy = 0.7
		"lightning":
			particles.process_material.color = Color(0.7, 0.7, 1.0, 0.8)
			if light:
				light.color = Color(0.7, 0.7, 1.0, 0.8)
				light.energy = 1.0
				
				# Make lightning flicker
				var timer = Timer.new()
				add_child(timer)
				timer.wait_time = 0.1
				timer.autostart = true
				timer.timeout.connect(func(): light.energy = randf_range(0.6, 1.0))
	
	# Set particle emission shape radius
	# Assumes particles use a CircleShape for emission
	var particles_material = particles.process_material
	if particles_material is ParticleProcessMaterial:
		particles_material.emission_sphere_radius = effect_radius

# Track entities entering the effect area
func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		affected_entities[area] = true

# Track entities leaving the effect area
func _on_area_exited(area: Area2D) -> void:
	if affected_entities.has(area):
		affected_entities.erase(area)

# Apply damage to all entities in the effect area
func apply_damage_tick() -> void:
	for area in affected_entities.keys():
		if area is HurtboxComponent and is_instance_valid(area):
			# Create a damage attack for this tick
			var tick_attack = Attack.new(
				damage_per_tick,
				Vector2.ZERO,  # No knockback for lingering effects
				attack_source
			)
			
			# Apply status effects based on effect type
			match effect_type:
				"fire":
					tick_attack.apply_effect("burn", 1.0, tick_rate * 2)  # Burn effect lingers
				"poison":
					tick_attack.apply_effect("poison", 0.5, tick_rate * 3)  # Poison lasts longer
				"ice":
					tick_attack.apply_effect("slow", 0.5, tick_rate * 1.5)  # 50% slow
				"acid":
					tick_attack.apply_effect("armor_reduction", 0.3, tick_rate * 2)  # Reduce defense
				"lightning":
					tick_attack.apply_effect("stun", 0.2, 0.1)  # Small chance to stun briefly
			
			# Apply damage
			area.damage(tick_attack)
