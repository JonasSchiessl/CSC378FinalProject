extends State
class_name PlayerMoveState

func _init(player: Player) -> void:
	super._init(player) 

func enter() -> void:
	entity.animated_sprite.play("Walk")

func physics_process(delta: float) -> void:
	# Get movement input
	var move_input = entity.get_movement_input()
	
	# Set velocity based on input
	entity.velocity = move_input * entity.move_speed
	
	# Update sprite facing based on movement direction
	entity.update_sprite_facing(move_input)
	
	# Update movement direction (for gameplay purposes)
	if move_input.x != 0:
		entity.facing_direction.x = move_input.x
	if move_input.y != 0:
		entity.facing_direction.y = move_input.y

func check_transitions() -> String:
	# Check if we should return to idle
	var move_input = entity.get_movement_input()
	if move_input == Vector2.ZERO:
		return "idle"
	return ""

func exit() -> void:
	pass
