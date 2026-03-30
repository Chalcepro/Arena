extends CharacterBody3D

# Bullet properties
@export var speed := 50.0
@export var damage := 12

# Direction to move (set by the gun)
var direction := Vector3.FORWARD
#
#func _ready():
	#
	# Ensure the bullet moves instantly
	# Optional: add a small flash effect here

func _physics_process(delta):
	# Move the bullet and detect collisions
	var collision = move_and_collide(direction * speed * delta)
	
	if collision:
		var hit = collision.get_collider()
		
		# Find a node that can take damage (walk up parents)
		while hit and not hit.has_method("take_damage"):
			hit = hit.get_parent()
		
		if hit and hit.has_method("take_damage"):
			hit.take_damage(damage)
		
		# Bullet disappears on hit
		queue_free()
