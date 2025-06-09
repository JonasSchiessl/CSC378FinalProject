# wave_data.gd  
extends Resource
class_name WaveData

@export var enemy_groups: Array[Resource] = []
@export var spawn_delay: float = 1.0  # Delay between individual enemy spawns
@export var wave_delay: float = 5.0   # Delay before next wave starts
@export var wave_name: String = ""
@export var spawn_pattern: SpawnPattern = SpawnPattern.SEQUENTIAL  # How to spawn enemy groups

enum SpawnPattern {
	SEQUENTIAL,  # Spawn groups one after another
	SIMULTANEOUS,  # Spawn all groups at the same time
	RANDOM_MIX   # Randomly mix enemies from all groups
}
