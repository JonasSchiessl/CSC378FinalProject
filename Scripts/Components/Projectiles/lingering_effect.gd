# lingering_effect.gd - FIXED VERSION
extends Node2D
class_name LingeringEffect

# Effect properties
@export var effect_radius: float = 100.0
@export var effect_duration: float = 5.0
@export var damage_per_tick: float = 1.0
@export var tick_rate: float = 0.5
@export var effect_type: String = "fire"

# Enhanced: Status effect properties
@export var status_effect_strength: float = 1.0
@export var status_effect_duration: float = 2.0
@export var apply_status_on_tick: bool = true
@export var apply_status_on_enter: bool = true  # NEW: Apply status when entering area

# Internal variables
var attack_source: Node2D
var timer: float = 0.0
var tick_timer: float = 0.0
var affected_entities: Dictionary = {}
var is_active: bool = true


# Components
@onready var effect_area: Area2D = $EffectArea
@onready var collision_shape: CollisionShape2D = $EffectArea/CollisionShape2D
@onready var effect_sprite: Sprite2D = $EffectSprite
@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

func _ready() -> void:
	set_as_top_level(true)
	
	call_deferred("_setup_area2d")
	call_deferred("_setup_shader")
	call_deferred("_connect_signals")
	
	var stored_global_pos = global_position
	global_position = stored_global_pos

func _exit_tree() -> void:
	pass

func _process(delta: float) -> void:
	if not is_active:
		return
		
	timer += delta

	# Check if effect should end
	if timer >= effect_duration:
		_end_effect()
		return

	# Apply damage ticks - Only if damage_per_tick > 0
	if damage_per_tick > 0:
		tick_timer += delta
		if tick_timer >= tick_rate:
			tick_timer = 0.0
			apply_damage_tick()

	# Update light intensity based on effect type and time
	if light:
		var intensity_factor = 1.0 - (timer / effect_duration) * 0.3  # Slight fade
		match effect_type:
			"lightning":
				# Flicker for lightning
				light.energy = intensity_factor * randf_range(0.7, 1.2)
			_:
				light.energy = intensity_factor * 0.8

func setup(source: Node2D, radius: float = effect_radius, duration: float = effect_duration, 
		   damage: float = damage_per_tick, type: String = effect_type, 
		   collision_layer: int = 0, collision_mask: int = 8,
		   status_strength: float = status_effect_strength, status_duration: float = status_effect_duration) -> void:
	attack_source = source
	effect_radius = radius
	effect_duration = duration
	damage_per_tick = damage
	effect_type = type
	status_effect_strength = status_strength
	status_effect_duration = status_duration
	
	call_deferred("_setup_collision", collision_layer, collision_mask, radius)
	call_deferred("_setup_shader")

func _setup_shader(alpha: float = 0.2) -> void:
	if not effect_sprite:
		return
		
	var sprite_scale = effect_radius / 64.0  # Assuming 64x64 base texture
	effect_sprite.scale = Vector2(sprite_scale, sprite_scale) * 3
	effect_sprite.modulate.a = alpha

func _connect_signals() -> void:
	if not effect_area.area_entered.is_connected(_on_area_entered):
		effect_area.area_entered.connect(_on_area_entered)
	if not effect_area.area_exited.is_connected(_on_area_exited):
		effect_area.area_exited.connect(_on_area_exited)

func _setup_area2d() -> void:
	effect_area.collision_layer = 0
	effect_area.collision_mask = 0
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = effect_radius
	collision_shape.shape = circle_shape
	
	_connect_signals()
	effect_area.monitoring = true

func _setup_collision(collision_layer: int, collision_mask: int, radius: float) -> void:
	if effect_area:
		effect_area.collision_layer = collision_layer
		effect_area.collision_mask = collision_mask
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		affected_entities[area] = true
		
		# NEW: Apply status effect immediately when entering area
		if apply_status_on_enter:
			var status_comp = get_status_effect_component(area)
			if status_comp:
				apply_lingering_status_effect(status_comp)

func _on_area_exited(area: Area2D) -> void:
	if affected_entities.has(area):
		affected_entities.erase(area)

func apply_damage_tick() -> void:
	if not is_active:
		return
		
	for area in affected_entities.keys():
		if area is HurtboxComponent and is_instance_valid(area):
			# Apply base damage if damage_per_tick > 0
			if damage_per_tick > 0:
				var tick_attack = Attack.new(
					damage_per_tick,
					Vector2.ZERO,
					attack_source
				)
				area.damage(tick_attack)
			
			# FIXED: Apply status effects on tick regardless of damage
			if apply_status_on_tick:
				var status_comp = get_status_effect_component(area)
				if status_comp:
					apply_lingering_status_effect(status_comp)

# Helper function to get the StatusEffectComponent from a hurtbox
func get_status_effect_component(hurtbox: HurtboxComponent) -> StatusEffectComponent:
	# First try the hurtbox's direct reference
	if hurtbox.status_effect_component:
		return hurtbox.status_effect_component
	
	# If that doesn't work, try to find it in the parent
	var parent = hurtbox.get_parent()
	if parent and parent.has_node("status_effect_component"):
		return parent.get_node("status_effect_component")
	
	# Last resort: search for any StatusEffectComponent in the parent
	if parent:
		for child in parent.get_children():
			if child is StatusEffectComponent:
				return child
	
	return null

# Apply status effects based on lingering effect type
func apply_lingering_status_effect(status_comp: StatusEffectComponent) -> void:
	if not status_comp or not is_active:
		return
	
	match effect_type:
		"fire", "burning":
			# Fire effects apply burning damage over time
			status_comp.apply_burning(status_effect_strength, status_effect_duration)
		"poison", "toxic":
			# Poison effects apply poison damage over time
			status_comp.apply_poison(status_effect_strength, status_effect_duration)
		"ice", "freeze", "frost":
			# Ice effects slow the target
			status_comp.apply_speed_modifier(status_effect_strength, status_effect_duration)
		"lightning", "electric", "shock":
			# Lightning effects have a chance to stun
			if randf() < status_effect_strength:
				status_comp.apply_stun(status_effect_duration)
		_:
			# Default: apply a generic burning effect
			status_comp.apply_burning(status_effect_strength, status_effect_duration)

# Set specific status effect parameters
func set_status_effect_params(strength: float, duration: float, apply_on_tick: bool = true, apply_on_enter: bool = true) -> void:
	status_effect_strength = strength
	status_effect_duration = duration
	apply_status_on_tick = apply_on_tick
	apply_status_on_enter = apply_on_enter

# Configure the lingering effect for a specific type with predefined settings
func configure_for_type(type: String) -> void:
	effect_type = type
	
	match type:
		"fire":
			damage_per_tick = 2.0
			status_effect_strength = 3.0  # 3 damage per second for burning
			status_effect_duration = 2.0
			apply_status_on_enter = true  # Apply burn immediately
			if effect_sprite:
				effect_sprite.modulate = Color(1.0, 0.5, 0.2, 0.3)  # Orange
		"poison":
			damage_per_tick = 1.0
			status_effect_strength = 2.0  # 2 damage per second for poison
			status_effect_duration = 3.0
			apply_status_on_enter = true  # Apply poison immediately
			if effect_sprite:
				effect_sprite.modulate = Color(0.3, 1.0, 0.3, 0.3)  # Green
		"ice":
			damage_per_tick = 0.5
			status_effect_strength = 0.5  # 50% speed reduction
			status_effect_duration = 3.0
			apply_status_on_enter = true  # Apply slow immediately
			if effect_sprite:
				effect_sprite.modulate = Color(0.5, 0.8, 1.0, 0.3)  # Blue
		"lightning":
			damage_per_tick = 1.5
			status_effect_strength = 0.3  # 30% stun chance
			status_effect_duration = 1.0
			apply_status_on_enter = true  # Try to stun immediately
			if effect_sprite:
				effect_sprite.modulate = Color(1.0, 1.0, 0.5, 0.4)  # Yellow
		_:
			# Default fire-like effect
			configure_for_type("fire")

# Proper cleanup when effect ends
func _end_effect() -> void:
	is_active = false
	
	# Stop all particle effects
	for child in get_children():
		if child is GPUParticles2D:
			child.emitting = false
	
	# Fade out the sprite
	if effect_sprite:
		var tween = create_tween()
		tween.tween_property(effect_sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()
