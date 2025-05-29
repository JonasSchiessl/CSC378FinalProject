extends Node2D
class_name LingeringEffect

# Effect properties
@export var effect_radius: float = 100.0
@export var effect_duration: float = 5.0
@export var damage_per_tick: float = 1.0
@export var tick_rate: float = 0.5
@export var effect_type: String = "fire"

# Internal variables
var attack_source: Node2D
var timer: float = 0.0
var tick_timer: float = 0.0
var affected_entities: Dictionary = {}

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
	

func _process(delta: float) -> void:
	timer += delta
	
	# Check if effect should end
	if timer >= effect_duration:
		queue_free()
		return
	
	# Apply damage ticks
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
		   collision_layer: int = 0, collision_mask: int = 8) -> void:
	attack_source = source
	effect_radius = radius
	effect_duration = duration
	damage_per_tick = damage
	effect_type = type
	
	call_deferred("_setup_collision", collision_layer, collision_mask, radius)
	call_deferred("_setup_shader")
	

func _setup_shader() -> void:
	if not effect_sprite:
		return
		
	var sprite_scale = effect_radius / 64.0  # Assuming 64x64 base texture
	effect_sprite.scale = Vector2(sprite_scale, sprite_scale)

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

func _on_area_exited(area: Area2D) -> void:
	if affected_entities.has(area):
		affected_entities.erase(area)

func apply_damage_tick() -> void:
	for area in affected_entities.keys():
		if area is HurtboxComponent and is_instance_valid(area):
			var tick_attack = Attack.new(
				damage_per_tick,
				Vector2.ZERO,
				attack_source
			)
			
			# Apply status effects based on effect type
			match effect_type:
				"fire":
					tick_attack.apply_effect("burn", 1.0, tick_rate * 2)
				"poison":
					tick_attack.apply_effect("poison", 0.5, tick_rate * 3)
				"ice":
					tick_attack.apply_effect("slow", 0.5, tick_rate * 1.5)
				"lightning":
					tick_attack.apply_effect("stun", 0.2, 0.1)
			
			area.damage(tick_attack)
