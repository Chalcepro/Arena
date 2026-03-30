extends Node3D

# ========================
# CONFIG
# ========================
@export var max_health := 3
@export var respawn_time := 5.0
@export var death_effect: PackedScene

# ========================
# NODE REFERENCES
# ========================
@onready var visual_node = $MeshInstance3D/CSGCylinder3D
@onready var collision_shape = $MeshInstance3D/Area3D/CollisionShape3D

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
	show_enemy()

# ========================
# PUBLIC METHODS
# ========================
# Now accepts an optional hit_location (ignored here for simplicity)
func take_damage(amount: int, _hit_location: String = "body"):
	if is_dead:
		return
	current_health -= amount
	print("Enemy took damage: ", amount, " -> health: ", current_health)
	if current_health <= 0:
		die()

func die():
	is_dead = true
	hide_enemy()
	
	if death_effect:
		var effect = death_effect.instantiate()
		add_child(effect)
		effect.global_position = global_position
	
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
	if visual_node:
		visual_node.visible = false
	if collision_shape:
		collision_shape.disabled = true

func show_enemy():
	if visual_node:
		visual_node.visible = true
	if collision_shape:
		collision_shape.disabled = false

# ========================
# PROCESS (for respawn timer)
# ========================
func _process(delta):
	if is_dead and respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			respawn()
