extends CharacterBody3D

# ========================
# CONFIG
# ========================
@export var WALK_SPEED := 8.0
@export var SPRINT_SPEED := 14.0
@export var CROUCH_SPEED := 4.0
@export var SLIDE_INITIAL_SPEED := 15.0
@export var JUMP_FORCE := 6.2
@export var ACCEL := 12.0
@export var DECEL := 10.0

const MOUSE_SENS := 0.003
var touch_sens := 0.005

@export var stand_height := 1.5
@export var crouch_height := 1.0
@export var slide_height := 0.7
@export var crouch_speed := 10.0

@export var default_fov := 65.0
@export var sprint_fov := 85.0
@export var slide_fov := 95.0
@export var aim_fov := 55.0
@export var fov_speed := 8.0

# Head bob
@export var head_bob_freq := 2.0
@export var head_bob_amp := 0.05

# Aim
@export var aim_offset := Vector3(0.2, -0.1, -0.3)

# Sprint boost
@export var BOOST_TRIGGER_TIME := 2.0
@export var MAX_BOOST_SPEED := 5.0
@export var BOOST_RAMP_SPEED := 10.0
@export var BOOST_DECAY_SPEED := 5.0

@export var sprint_accel_multiplier := 1.5

# Reset
@export var spawn_point: Node3D = null          # optional spawn marker
@export var fall_threshold_y := -10.0           # reset when below this Y
@export var reset_action := "reset"          # input action for manual reset

# Coyote time (edge jump forgiveness)
@export var coyote_time := 0.2        # seconds after leaving ground to still allow jump

# ========================
# NODE REFERENCES
# ========================
@onready var head = $head
@onready var camera_smooth = $head/camera_smooth
@onready var camera = $head/camera_smooth/Camera3D
@onready var gun = $head/weapon/gun
@onready var collider = $CollisionShape3D

# ========================
# STATE
# ========================
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var speed := WALK_SPEED
var sliding := false
var crouching := false
var aiming := false

var slide_dir := Vector3.ZERO
var target_height := 1.5
var target_fov := 75.0

var drag_touch_index := -1
var bob_time := 0.0

# Sprint latch
var sprint_latch_timer := 0.0
var sprint_latch_active := false

# Boost
var sprint_time := 0.0
var boost_speed := 0.0

# Spawn position (fallback)
var default_spawn := Vector3.ZERO

# Coyote time tracking
var was_on_floor := true
var coyote_timer := 0.0

# ========================
# READY
# ========================
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = default_fov
	target_height = stand_height
	target_fov = default_fov
	
	# Store initial position as default spawn
	default_spawn = global_position

# ========================
# INPUT
# ========================
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(event.relative.x, event.relative.y, MOUSE_SENS)

	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().size.x / 2:
			drag_touch_index = event.index
		elif not event.pressed and event.index == drag_touch_index:
			drag_touch_index = -1

	if event is InputEventScreenDrag and event.index == drag_touch_index:
		rotate_camera(event.relative.x, event.relative.y, touch_sens)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Aim
	if event.is_action_pressed("aim"):
		aiming = true
	if event.is_action_released("aim"):
		aiming = false
	
	# Reset
	if event.is_action_pressed(reset_action):
		reset_player()

func rotate_camera(x, y, sens):
	head.rotate_y(-x * sens)
	camera.rotate_x(-y * sens)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

# ========================
# RESET FUNCTION
# ========================
func reset_player():
	# Teleport to spawn point
	if spawn_point:
		global_position = spawn_point.global_position
	else:
		global_position = default_spawn
	
	# Reset velocity and states
	velocity = Vector3.ZERO
	sliding = false
	crouching = false
	aiming = false
	sprint_latch_active = false
	sprint_latch_timer = 0.0
	sprint_time = 0.0
	boost_speed = 0.0
	speed = WALK_SPEED
	
	# Reset camera and collider heights
	target_height = stand_height
	target_fov = default_fov
	camera.fov = default_fov
	head.position.y = stand_height
	
	# Reset collider shape
	var shape = collider.shape as CapsuleShape3D
	if shape:
		shape.height = stand_height
	
	# Optional: reset head rotation (if you want to face forward again)
	# head.rotation.y = 0
	# camera.rotation.x = 0

# ========================
# PHYSICS
# ========================
func _physics_process(delta):
	var on_floor = is_on_floor()
	
	# --- Coyote time update ---
	if on_floor and not was_on_floor:
		# Just landed – reset timer
		coyote_timer = 0.0
	elif not on_floor and was_on_floor:
		# Just left ground – start timer
		coyote_timer = coyote_time
	elif not on_floor:
		# In air – count down
		coyote_timer = max(coyote_timer - delta, 0.0)
	
	was_on_floor = on_floor
	
	# --- Fall out of world reset ---
	if global_position.y < fall_threshold_y:
		reset_player()
		return

	# Gravity
	if not on_floor:
		velocity.y -= gravity * delta

	# Jump – allow if on floor or coyote timer active
	if Input.is_action_just_pressed("jump") and (on_floor or coyote_timer > 0):
		velocity.y = JUMP_FORCE
		sliding = false
		coyote_timer = 0.0   # Prevent double jump

	# Input
	var input = Input.get_vector("move_right","move_left","move_backward","move_forward")
	var direction = (head.transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# ========================
	# STATE LOGIC
	# ========================
	if sliding:
		velocity.x = slide_dir.x * speed
		velocity.z = slide_dir.z * speed
		speed = lerp(speed, WALK_SPEED, delta * 2.0)

		if speed <= WALK_SPEED + 0.5:
			sliding = false

	else:
		speed = WALK_SPEED

		# Crouch
		if Input.is_action_pressed("crouch") and on_floor:
			crouching = true
		else:
			if can_stand():
				crouching = false

		# Sprint
		var forward_pressed = input.y > 0.1
		var raw_sprint = Input.is_action_pressed("sprint") and not crouching and forward_pressed and not aiming

		if raw_sprint:
			sprint_latch_timer = 0.1
			sprint_latch_active = true
		elif sprint_latch_timer > 0:
			sprint_latch_timer -= delta
		else:
			sprint_latch_active = false

		var should_sprint = sprint_latch_active

		# Boost
		if should_sprint:
			sprint_time += delta
			if sprint_time >= BOOST_TRIGGER_TIME:
				boost_speed = min(boost_speed + BOOST_RAMP_SPEED * delta, MAX_BOOST_SPEED)
			speed = SPRINT_SPEED + boost_speed
		else:
			sprint_time = 0.0
			boost_speed = move_toward(boost_speed, 0.0, BOOST_DECAY_SPEED * delta)

		# Slide start
		if Input.is_action_just_pressed("crouch") and Input.is_action_pressed("sprint") and on_floor:
			sliding = true
			speed = SLIDE_INITIAL_SPEED
			slide_dir = direction if direction.length() > 0 else -head.global_transform.basis.z
			slide_dir = slide_dir.normalized()

	# ========================
	# COLLIDER HEIGHT (FIXED)
	# ========================
	var shape = collider.shape as CapsuleShape3D
	var target_capsule_height = stand_height

	if sliding:
		target_capsule_height = slide_height
	elif crouching:
		target_capsule_height = crouch_height

	shape.height = lerp(shape.height, target_capsule_height, delta * crouch_speed)

	# ========================
	# MOVEMENT
	# ========================
	if not sliding:
		var accel = ACCEL
		if sprint_latch_active:
			accel *= sprint_accel_multiplier

		if direction.length() > 0:
			velocity.x = lerp(velocity.x, direction.x * speed, accel * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, DECEL)
			velocity.z = move_toward(velocity.z, 0, DECEL)

	# ========================
	# HEAD BOB (FIXED)
	# ========================
	if on_floor and direction.length() > 0 and not sliding and not aiming:
		var speed_ratio = speed / SPRINT_SPEED
		bob_time += delta * speed_ratio * 10.0 * head_bob_freq
		var bob_offset = sin(bob_time) * head_bob_amp
		camera_smooth.position.y = bob_offset
	else:
		bob_time = 0.0
		camera_smooth.position.y = lerp(camera_smooth.position.y, 0.0, delta * 10.0)

	# ========================
	# FOV
	# ========================
	if sliding:
		target_fov = slide_fov
	elif aiming:
		target_fov = aim_fov
	elif sprint_latch_active and input.y > 0.1:
		target_fov = sprint_fov
	else:
		target_fov = default_fov

	camera.fov = lerp(camera.fov, target_fov, delta * fov_speed)

	# ========================
	# HEAD HEIGHT
	# ========================
	var target_head_height = stand_height
	if sliding:
		target_head_height = slide_height
	elif crouching:
		target_head_height = crouch_height

	head.position.y = lerp(head.position.y, target_head_height, delta * crouch_speed)

	# Aim offset
	if gun and gun.has_method("set_aim_offset"):
		gun.set_aim_offset(aim_offset if aiming else Vector3.ZERO)

	move_and_slide()

# ========================
# CAN STAND CHECK (FIXED)
# ========================
func can_stand() -> bool:
	var shape = collider.shape
	if shape is CapsuleShape3D:
		var height_diff = stand_height - crouch_height
		return not test_move(transform, Vector3(0, height_diff, 0))
	return true
