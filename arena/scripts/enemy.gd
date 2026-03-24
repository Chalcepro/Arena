extends Node3D

# ========================
# CONFIG
# ========================
@export var max_health := 3
@export var respawn_time := 5.0          # time in seconds before respawn (0 = never)
@export var death_effect: PackedScene    # optional particle effect on death

# ========================
# NODE REFERENCES
# ========================
# Assume the enemy has a MeshInstance3D child (for visuals) and a CollisionShape3D child
@onready var mesh_node = $MeshInstance3D      # adjust path if different
@onready var collision_shape = $CollisionShape3D   # adjust if needed
# If you have multiple children, you can list them or use a group

# ========================
# STATE
# ========================
var current_health: int
var is_dead := false
var respawn_timer := 0.0

# ========================
# READY
# ========================
func _ready():
	current_health = max_health
	# Make sure we start alive
	show_enemy()

# ========================
# PUBLIC METHODS
# ========================
func take_damage(amount: int):
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	is_dead = true
	hide_enemy()
	
	# Optional: spawn death effect
	if death_effect:
		var effect = death_effect.instantiate()
		add_child(effect)
		effect.global_position = global_position
		# Effect will self‑destroy after its animation
	
	# If respawn_time > 0, start timer
	if respawn_time > 0:
		respawn_timer = respawn_time

func respawn():
	is_dead = false
	current_health = max_health
	show_enemy()

# ========================
# INTERNAL METHODS
# ========================
func hide_enemy():
	# Disable visuals
	if mesh_node:
		mesh_node.visible = false
	# Disable collision
	if collision_shape:
		collision_shape.disabled = true
	# You can also disable other children (e.g., Area3D for detection)
	# For example, if you have an Area3D for player detection:
	# $DetectionArea.monitoring = false

func show_enemy():
	if mesh_node:
		mesh_node.visible = true
	if collision_shape:
		collision_shape.disabled = false
	# Re‑enable detection areas
	# $DetectionArea.monitoring = true

# ========================
# PROCESS (for respawn timer)
# ========================
func _process(delta):
	if is_dead and respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			respawn()
