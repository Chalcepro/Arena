extends Area3D

@export var weapon_data: WeaponData
@export var pickup_icon: Texture2D
@export var respawn_time: float = 30.0

@onready var mesh_instance = $MeshInstance3D
@onready var pickup_label = $PickupLabel  # Optional 3D label
@onready var respawn_timer = $RespawnTimer

var is_available := true

func _ready():
	body_entered.connect(_on_body_entered)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	
	if weapon_data and weapon_data.weapon_mesh:
		var mesh = weapon_data.weapon_mesh.instantiate()
		mesh_instance.add_child(mesh)

func _on_body_entered(body):
	if not is_available:
		return
	
	if body.has_method("pickup_weapon"):
		var success = body.pickup_weapon(weapon_data)
		if success:
			picked_up()

func picked_up():
	is_available = false
	mesh_instance.visible = false
	if pickup_label:
		pickup_label.visible = false
	collision_layer = 0  # Disable collisions
	respawn_timer.start(respawn_time)

func _on_respawn_timer_timeout():
	is_available = true
	mesh_instance.visible = true
	if pickup_label:
		pickup_label.visible = true
	collision_layer = 1  # Re-enable collisions
