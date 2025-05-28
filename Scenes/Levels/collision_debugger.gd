extends Node2D
class_name CollisionDebugger

# Debug colors for different types of collision shapes
var debug_colors = {
	"tower_physical": Color.BLUE,      # Tower's physical collision (prevents movement)
	"tower_range": Color.RED,          # Tower's attack range detection
	"enemy_physical": Color.GREEN,     # Enemy's physical collision
	"enemy_hurtbox": Color.YELLOW,     # Enemy's hurtbox (can be damaged)
	"player_physical": Color.PURPLE,   # Player's physical collision
	"projectile": Color.ORANGE         # Projectile collision areas
}

# Control visibility of different debug layers
@export var show_tower_collision: bool = true
@export var show_enemy_collision: bool = true  
@export var show_player_collision: bool = true
@export var show_projectile_collision: bool = false
@export var line_width: float = 3.0

# Keep track of objects we're debugging
var tracked_objects: Array[Node] = []

func _ready() -> void:
	# Make sure we draw on top of everything else
	z_index = 1000
	
	# Start tracking objects in the scene
	call_deferred("start_tracking_objects")

func start_tracking_objects() -> void:
	"""Find and start tracking all collision objects in the scene"""
	var root = get_tree().current_scene
	if root:
		find_collision_objects(root)
	
	# Set up a timer to periodically refresh our tracking
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0  # Refresh every second
	timer.timeout.connect(refresh_tracking)
	timer.start()

func find_collision_objects(node: Node) -> void:
	"""Recursively find all collision objects starting from the given node"""
	# Check if this node has collision we should track
	if should_track_node(node):
		if not node in tracked_objects:
			tracked_objects.append(node)
			print("CollisionDebugger: Now tracking ", node.name, " (", node.get_class(), ")")
	
	# Recursively check children
	for child in node.get_children():
		find_collision_objects(child)

func should_track_node(node: Node) -> bool:
	"""Determine if we should track this node's collision shapes"""
	# Track towers
	if node is Tower or node.name.to_lower().contains("tower"):
		return show_tower_collision
	
	# Track enemies  
	if node.is_in_group("enemies") or node.name.to_lower().contains("enemy"):
		return show_enemy_collision
	
	# Track player
	if node is Player or node.name.to_lower().contains("player"):
		return show_player_collision
	
	# Track projectiles
	if node.name.to_lower().contains("projectile"):
		return show_projectile_collision
	
	return false

func refresh_tracking() -> void:
	"""Remove invalid objects and find new ones"""
	# Remove invalid objects
	tracked_objects = tracked_objects.filter(func(obj): return is_instance_valid(obj))
	
	# Look for new objects
	var root = get_tree().current_scene
	if root:
		find_collision_objects(root)
	
	# Force a redraw
	queue_redraw()

func _draw() -> void:
	"""Draw debug visualizations for all tracked collision shapes"""
	for obj in tracked_objects:
		if not is_instance_valid(obj):
			continue
			
		draw_object_collisions(obj)

func draw_object_collisions(obj: Node) -> void:
	"""Draw all collision shapes for a specific object"""
	# Determine what type of object this is to choose the right color
	var obj_type = get_object_type(obj)
	
	# Find and draw all collision shapes in this object
	draw_collision_shapes_recursive(obj, obj, obj_type)

func get_object_type(obj: Node) -> String:
	"""Determine what type of object this is for color coding"""
	if obj is Tower or obj.name.to_lower().contains("tower"):
		return "tower"
	elif obj.is_in_group("enemies") or obj.name.to_lower().contains("enemy"):
		return "enemy"  
	elif obj is Player or obj.name.to_lower().contains("player"):
		return "player"
	elif obj.name.to_lower().contains("projectile"):
		return "projectile"
	else:
		return "unknown"

func draw_collision_shapes_recursive(root_obj: Node, current_node: Node, obj_type: String) -> void:
	"""Recursively find and draw collision shapes starting from current_node"""
	
	# Check if this node is a collision shape
	if current_node is CollisionShape2D:
		var collision_shape = current_node as CollisionShape2D
		
		# Determine the specific color based on the parent's purpose
		var color = get_collision_color(collision_shape, obj_type)
		
		# Draw the shape
		draw_collision_shape(collision_shape, root_obj, color)
	
	# Check if this node is an Area2D (for attack ranges, hurtboxes, etc.)
	elif current_node is Area2D:
		var area = current_node as Area2D
		var color = get_area_color(area, obj_type)
		
		# Draw all collision shapes within this area
		for child in area.get_children():
			if child is CollisionShape2D:
				draw_collision_shape(child as CollisionShape2D, root_obj, color)
	
	# Recursively check children
	for child in current_node.get_children():
		draw_collision_shapes_recursive(root_obj, child, obj_type)

func get_collision_color(collision_shape: CollisionShape2D, obj_type: String) -> Color:
	"""Determine the appropriate color for a collision shape"""
	var parent = collision_shape.get_parent()
	
	if obj_type == "tower":
		if parent.name.to_lower().contains("attack") or parent.name.to_lower().contains("range"):
			return debug_colors.tower_range
		else:
			return debug_colors.tower_physical
	elif obj_type == "enemy":
		if parent.name.to_lower().contains("hurt"):
			return debug_colors.enemy_hurtbox
		else:
			return debug_colors.enemy_physical
	elif obj_type == "player":
		return debug_colors.player_physical
	else:
		return debug_colors.projectile

func get_area_color(area: Area2D, obj_type: String) -> Color:
	"""Determine the appropriate color for an Area2D"""
	if obj_type == "tower" and (area.name.to_lower().contains("attack") or area.name.to_lower().contains("range")):
		return debug_colors.tower_range
	elif obj_type == "enemy" and area.name.to_lower().contains("hurt"):
		return debug_colors.enemy_hurtbox
	else:
		return get_collision_color(null, obj_type)

func draw_collision_shape(collision_shape: CollisionShape2D, root_obj: Node, color: Color) -> void:
	"""Draw a specific collision shape with the given color"""
	if not collision_shape.shape or collision_shape.disabled:
		return
	
	# Calculate the world position of the collision shape
	var world_transform = collision_shape.global_transform
	var local_pos = to_local(world_transform.origin)
	
	# Draw different shapes based on their type
	if collision_shape.shape is CircleShape2D:
		var circle = collision_shape.shape as CircleShape2D
		draw_circle_outline(local_pos, circle.radius, color)
		
		# Also draw a small cross at the center
		draw_cross(local_pos, 5, color)
		
	elif collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var size = rect_shape.size
		
		# Create rectangle centered on the collision shape position
		var rect = Rect2(local_pos - size/2, size)
		draw_rect_outline(rect, color)
		
		# Draw a small cross at the center
		draw_cross(local_pos, 5, color)
		
	elif collision_shape.shape is CapsuleShape2D:
		var capsule = collision_shape.shape as CapsuleShape2D
		draw_capsule_outline(local_pos, capsule.radius, capsule.height, color)
		
		# Draw a small cross at the center  
		draw_cross(local_pos, 5, color)

func draw_circle_outline(center: Vector2, radius: float, color: Color) -> void:
	"""Draw a circle outline"""
	var points = PackedVector2Array()
	var num_points = 32
	
	for i in range(num_points + 1):
		var angle = (i * PI * 2) / num_points
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	# Draw the circle as a series of lines
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, line_width)

func draw_rect_outline(rect: Rect2, color: Color) -> void:
	"""Draw a rectangle outline"""
	var points = [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		rect.position  # Close the rectangle
	]
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, line_width)

func draw_capsule_outline(center: Vector2, radius: float, height: float, color: Color) -> void:
	"""Draw a capsule outline (rectangle with rounded ends)"""
	var half_height = height / 2.0
	
	# Draw the rectangular middle section
	var rect_top = center.y - half_height + radius
	var rect_bottom = center.y + half_height - radius
	
	if rect_bottom > rect_top:
		draw_line(Vector2(center.x - radius, rect_top), Vector2(center.x - radius, rect_bottom), color, line_width)
		draw_line(Vector2(center.x + radius, rect_top), Vector2(center.x + radius, rect_bottom), color, line_width)
	
	# Draw the rounded ends (semicircles)
	draw_semicircle(Vector2(center.x, center.y - half_height + radius), radius, 0, color)  # Top
	draw_semicircle(Vector2(center.x, center.y + half_height - radius), radius, PI, color)  # Bottom

func draw_semicircle(center: Vector2, radius: float, start_angle: float, color: Color) -> void:
	"""Draw a semicircle starting from the given angle"""
	var points = PackedVector2Array()
	var num_points = 16
	
	for i in range(num_points + 1):
		var angle = start_angle + (i * PI) / num_points
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, line_width)

func draw_cross(center: Vector2, size: float, color: Color) -> void:
	"""Draw a small cross at the given position"""
	draw_line(center + Vector2(-size, 0), center + Vector2(size, 0), color, line_width)
	draw_line(center + Vector2(0, -size), center + Vector2(0, size), color, line_width)

# Utility functions to toggle debug visualization from code
func toggle_tower_debug() -> void:
	show_tower_collision = !show_tower_collision
	queue_redraw()

func toggle_enemy_debug() -> void:
	show_enemy_collision = !show_enemy_collision  
	queue_redraw()

func toggle_player_debug() -> void:
	show_player_collision = !show_player_collision
	queue_redraw()

# Function to print detailed collision information
func print_collision_info() -> void:
	"""Print detailed information about all tracked collision objects"""
	print("\n=== COLLISION DEBUG INFO ===")
	
	for obj in tracked_objects:
		if not is_instance_valid(obj):
			continue
			
		print("\nObject: ", obj.name, " (", obj.get_class(), ")")
		print("  Global Position: ", obj.global_position)
		print("  Collision Layer: ", obj.collision_layer if obj.get("collision_layer") != null else "N/A")
		print("  Collision Mask: ", obj.collision_mask if obj.get("collision_mask") != null else "N/A")
		
		# Find all collision-related children
		print_collision_children(obj, "  ")

func print_collision_children(node: Node, indent: String) -> void:
	"""Recursively print collision-related children"""
	for child in node.get_children():
		if child is CollisionShape2D:
			var shape = child as CollisionShape2D
			print(indent, "CollisionShape2D: ", child.name)
			print(indent, "  Position: ", child.position)
			print(indent, "  Disabled: ", shape.disabled)
			print(indent, "  Shape Type: ", shape.shape.get_class() if shape.shape else "None")
			
			if shape.shape is CircleShape2D:
				print(indent, "  Radius: ", (shape.shape as CircleShape2D).radius)
			elif shape.shape is RectangleShape2D:
				print(indent, "  Size: ", (shape.shape as RectangleShape2D).size)
				
		elif child is Area2D:
			var area = child as Area2D  
			print(indent, "Area2D: ", child.name)
			print(indent, "  Position: ", child.position)
			print(indent, "  Collision Layer: ", area.collision_layer)
			print(indent, "  Collision Mask: ", area.collision_mask)
			print(indent, "  Monitoring: ", area.monitoring)
			print(indent, "  Monitorable: ", area.monitorable)
			
			# Check for collision shapes within the area
			print_collision_children(child, indent + "  ")
		else:
			# Continue searching in other children
			print_collision_children(child, indent)
