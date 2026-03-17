extends Node3D

# Exports
@export var sway_amount := 0.05
@export var sway_speed := 4.0
@export var recoil_rotation := 0.1           # how much the camera rotates up per shot (radians)
@export var recoil_return_speed := 8.0       # how fast the camera returns
@export var tracer_duration := 0.05
@export var tracer_length := 100.0
@export var reload_duration := 0.5

# Node references
@onready var muzzle = $Muzzle
@onready var tracer = $Tracer

# State
var original_position: Vector3
var mouse_delta := Vector2.ZERO
var aim_offset := Vector3.ZERO
var reload_timer := 0.0
var is_reloading := false

# Recoil state
var recoil_remaining := 0.0

func _ready():
	original_position = position
	tracer.visible = false

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_delta = event.relative

func _process(delta):
	# Handle reload timer
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false

	# Shooting
	if Input.is_action_just_pressed("shoot") and not is_reloading:
		shoot()

	# Reload input
	if Input.is_action_just_pressed("reload") and not is_reloading:
		start_reload()

	# Weapon sway (only if not reloading)
	if not is_reloading:
		sway(delta)
	else:
		reload_animation(delta)

	# Smoothly return from recoil
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
			# Clamp just in case
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
	var input_dir = Input.get_vector("move_right","move_left","move_backward","move_forward")
	if input_dir.length() > 0:
		var bob = sin(Time.get_ticks_msec() * 0.01) * 0.02
		target_pos.y += bob

	# Smooth interpolation
	position = position.lerp(target_pos, sway_speed * delta)
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, sway_speed * delta)

func shoot():
	# Recoil: immediate upward kick
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam.rotation.x -= recoil_rotation
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		# Store how much we need to return
		recoil_remaining = recoil_rotation

	# --- Tracer effect (direct raycast, no extra node needed) ---
	var space_state = get_world_3d().direct_space_state
	var cam_global = cam.global_transform
	var from = cam_global.origin
	var to = from - cam_global.basis.z * tracer_length

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # adjust to your collision layers
	var result = space_state.intersect_ray(query)

	var hit_point = to
	if result:
		hit_point = result.position

	var muzzle_pos = muzzle.global_position
	var direction_to_hit = (hit_point - muzzle_pos).normalized()
	var distance = muzzle_pos.distance_to(hit_point)

	# Place tracer at midpoint and scale it
	tracer.global_position = muzzle_pos + direction_to_hit * (distance * 0.5)
	tracer.scale = Vector3(1, 1, distance)
	tracer.look_at(hit_point, Vector3.UP)

	tracer.visible = true
	await get_tree().create_timer(tracer_duration).timeout
	tracer.visible = false

func start_reload():
	is_reloading = true
	reload_timer = reload_duration
	print("Reloading...")

func reload_animation(delta):
	var t = 1.0 - (reload_timer / reload_duration)
	var offset = sin(t * PI * 4) * 0.05
	position = original_position + aim_offset + Vector3(0, 0, offset)
