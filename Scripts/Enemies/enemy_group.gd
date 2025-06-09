# enemy_group.gd
extends Resource
class_name EnemyGroup

@export var enemy_type: String = "poison_rat"  # "poison_rat" or "melee_rat"
@export var enemy_count: int = 5
@export var group_delay: float = 0.0  # Delay before this group starts spawning (for sequential)
