extends RefCounted
class_name State

var entity: Node = null  # The entity this state belongs to

func _init(parent: Node) -> void:
	entity = parent

# Called when entering this state
func enter() -> void:
	pass

# Called every physics frame
func physics_process(delta: float) -> void:
	pass

# Called every frame
func process(delta: float) -> void:
	pass

# Called when handling input
func input(event: InputEvent) -> void:
	pass

# Called when exiting this state
func exit() -> void:
	pass

# Check if this state should transition to another state
# Returns the new state name or null if no transition needed
func check_transitions() -> String:
	return ""
