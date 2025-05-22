extends State
class_name PlayerIdleState

func _init(player: Player) -> void:
	super._init(player) 

func enter() -> void:
	entity.animated_sprite.play("Idle")

func physics_process(delta: float) -> void:
	# Nothing to do in idle state
	pass

func check_transitions() -> String:
	# Check for movement input
	var move_input = entity.get_movement_input()
	if move_input != Vector2.ZERO:
		return "move"
	return ""

func exit() -> void:
	pass
