extends Node3D

# Weapon data
@export var weapon_data: WeaponData
@export var weapon_mesh_instance: MeshInstance3D

# Bullet settings
@export var bullet_scene: PackedScene   # assign the bullet scene in the inspector
@export var bullet_speed := 50.0
@export var bullet_damage := 12

# Visual effects
@export var sway_amount := 0.05
@export var sway_speed := 4.0
@export var muzzle_flash_duration := 0.05

# Node references
@export var muzzle: Marker3D
@onready var muzzle_flash = $MuzzleFlash
@onready var weapon_mesh_holder = $WeaponMeshHolder

# State
var original_position: Vector3
var mouse_delta := Vector2.ZERO
var aim_offset := Vector3.ZERO
var is_reloading := false
var reload_timer := 0.0
var current_ammo := 0
var reserve_ammo := 0
var can_shoot := true
var shoot_timer := 0.0

# Recoil state
var recoil_remaining := 0.0
var recoil_return_speed := 8.0

# Signals
signal ammo_updated(current: int, reserve: int)
signal weapon_fired()
signal weapon_reloaded()

func _ready():
	original_position = position
	if muzzle_flash:
		muzzle_flash.visible = false

	if weapon_data:
		current_ammo = weapon_data.magazine_size
		reserve_ammo = weapon_data.max_ammo
		ammo_updated.emit(current_ammo, reserve_ammo)

		if weapon_data.weapon_mesh:
			var mesh = weapon_data.weapon_mesh.instantiate()
			weapon_mesh_holder.add_child(mesh)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_delta = event.relative

func _process(delta):
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			finish_reload()

	if Input.is_action_pressed("shoot") and can_shoot and not is_reloading and current_ammo > 0:
		shoot()

	if weapon_data and Input.is_action_just_pressed("reload") and not is_reloading \
	   and current_ammo < weapon_data.magazine_size and reserve_ammo > 0:
		start_reload()

	if not is_reloading:
		sway(delta)
	else:
		reload_animation(delta)

	if recoil_remaining > 0:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var return_amount = recoil_return_speed * delta
			if recoil_remaining > return_amount:
				cam.rotation.x += return_amount
				recoil_remaining -= return_amount
			else:
				cam.rotation.x += recoil_remaining
				recoil_remaining = 0
			cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func set_aim_offset(offset: Vector3):
	aim_offset = offset

func sway(delta):
	var target_pos = original_position + aim_offset

	# Mouse look sway
	target_pos += Vector3(
		-mouse_delta.y * sway_amount,
		-mouse_delta.x * sway_amount,
		0
	) * 0.01

	# Movement bob
	var input_dir = Input.get_vector("move_right", "move_left", "move_backward", "move_forward")
	if input_dir.length() > 0:
		var bob = sin(Time.get_ticks_msec() * 0.01) * 0.02
		target_pos.y += bob

	position = position.lerp(target_pos, sway_speed * delta)
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, sway_speed * delta)

func shoot():
	if not weapon_data or current_ammo <= 0 or not bullet_scene:
		return

	# Consume ammo
	current_ammo -= 1
	ammo_updated.emit(current_ammo, reserve_ammo)

	# Set cooldown
	can_shoot = false
	shoot_timer = weapon_data.fire_rate

	# Get camera direction
	var cam = get_viewport().get_camera_3d()
	var bullet_dir = -cam.global_transform.basis.z.normalized()

	# Spawn bullet at muzzle
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = bullet_dir
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	get_tree().current_scene.add_child(bullet)   # or root, but current_scene works

	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		await get_tree().create_timer(muzzle_flash_duration).timeout
		muzzle_flash.visible = false

	# Apply recoil
	cam.rotation.x -= weapon_data.recoil_amount
	cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	recoil_remaining = weapon_data.recoil_amount

	weapon_fired.emit()

func calculate_damage() -> int:
	if not weapon_data:
		return 0
	return weapon_data.damage

func get_hit_location(position: Vector3, normal: Vector3) -> String:
	return "body"

func start_reload():
	if not weapon_data:
		return
	if is_reloading or current_ammo >= weapon_data.magazine_size or reserve_ammo <= 0:
		return

	is_reloading = true
	reload_timer = weapon_data.reload_time
	print("Reloading...")
	weapon_reloaded.emit()

func finish_reload():
	if not weapon_data:
		is_reloading = false
		return

	var ammo_needed = weapon_data.magazine_size - current_ammo
	var ammo_to_take = min(ammo_needed, reserve_ammo)

	current_ammo += ammo_to_take
	reserve_ammo -= ammo_to_take

	is_reloading = false
	ammo_updated.emit(current_ammo, reserve_ammo)
	print("Reload complete!")

func reload_animation(delta):
	if not weapon_data:
		return

	var t = 1.0 - (reload_timer / weapon_data.reload_time)
	var offset = sin(t * PI * 4) * 0.05
	position = original_position + aim_offset + Vector3(0, 0, offset)

func add_ammo(amount: int):
	reserve_ammo += amount
	ammo_updated.emit(current_ammo, reserve_ammo)

func get_ammo_string() -> String:
	return str(current_ammo) + " / " + str(reserve_ammo)
