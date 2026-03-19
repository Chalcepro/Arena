extends CharacterBody3D

# ========================
# CONFIG
# ========================
@export var WALK_SPEED := 8.0
@export var SPRINT_SPEED := 20.0
@export var CROUCH_SPEED := 4.0
@export var SLIDE_INITIAL_SPEED := 18.0
@export var JUMP_FORCE := 5.5
@export var ACCEL := 12.0
@export var DECEL := 10.0

const MOUSE_SENS := 0.003
var touch_sens := 0.005

@export var crouch_height := 1.0
@export var stand_height := 1.5
@export var crouch_speed := 10.0

@export var default_fov := 75.0
@export var sprint_fov := 85.0
@export var slide_fov := 105.0
@export var aim_fov := 55.0                # FOV when aiming
@export var fov_speed := 8.0

# Head bob
@export var head_bob_freq := 2.0
@export var head_bob_amp := 0.05

# Gun position offset when aiming (relative to its original position)
@export var aim_offset := Vector3(0.2, -0.1, -0.3)  # tweak to your liking

# ========================
# NODE REFERENCES
# ========================
@onready var head = $head
@onready var camera_smooth = $head/camera_smooth
@onready var camera = $head/camera_smooth/Camera3D
@onready var gun = $head/weapon/gun   # reference to gun

# ========================
# STATE VARIABLES
# ========================
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed := WALK_SPEED
var sliding := false
var crouching := false
var aiming := false                 # new
var slide_dir := Vector3.ZERO
var target_height := 1.5
var target_fov := 75.0
var drag_touch_index := -1
var bob_time := 0.0

# ========================
# READY
# ========================
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = default_fov
	target_height = stand_height
	target_fov = default_fov

# ========================
# INPUT
# ========================
func _input(event):
	# Mouse look
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

	# Aim input (hold to aim)
	if event.is_action_pressed("aim"):
		aiming = true
	if event.is_action_released("aim"):
		aiming = false

func rotate_camera(x, y, sens):
	head.rotate_y(-x * sens)
	camera.rotate_x(-y * sens)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

# ========================
# PHYSICS PROCESS
# ========================
func _physics_process(delta):
	var on_floor = is_on_floor()

	# Gravity
	if not on_floor:
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = JUMP_FORCE

	# Movement input
	var input = Input.get_vector("move_right","move_left","move_backward","move_forward")
	var direction = (head.transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# --- State logic ---
	if sliding:
		velocity.x = slide_dir.x * speed
		velocity.z = slide_dir.z * speed
		speed = lerp(speed, WALK_SPEED, delta * 2.0)
		if speed <= WALK_SPEED + 0.5:
			sliding = false
			crouching = false
			target_height = stand_height
	else:
		speed = WALK_SPEED

		# Crouch
		if Input.is_action_pressed("crouch") and on_floor:
			crouching = true
			target_height = crouch_height
			speed = CROUCH_SPEED
		else:
			if can_stand():
				crouching = false
				target_height = stand_height
			else:
				crouching = true

		# Sprint – only when moving forward and NOT aiming
		if Input.is_action_pressed("sprint") and not crouching and input.y > 0 and not aiming:
			speed = SPRINT_SPEED

		# Slide start
		if Input.is_action_just_pressed("crouch") and Input.is_action_pressed("sprint") and on_floor:
			sliding = true
			speed = SLIDE_INITIAL_SPEED
			slide_dir = direction if direction.length() > 0 else -head.global_transform.basis.z
			slide_dir = slide_dir.normalized()

	# --- Determine target FOV (priority: slide > aim > sprint > default) ---
	if sliding:
		target_fov = slide_fov
	elif aiming:
		target_fov = aim_fov
	elif Input.is_action_pressed("sprint") and not crouching and input.y > 0:
		target_fov = sprint_fov
	else:
		target_fov = default_fov

	# --- Movement (if not sliding) ---
	if not sliding:
		if direction.length() > 0:
			velocity.x = lerp(velocity.x, direction.x * speed, ACCEL * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, DECEL)
			velocity.z = move_toward(velocity.z, 0, DECEL)

	# --- Head bob (disabled while aiming) ---
	if on_floor and direction.length() > 0 and not sliding and not aiming:
		bob_time += delta * speed * head_bob_freq
		var bob_offset = sin(bob_time) * head_bob_amp
		camera_smooth.position.y = bob_offset
	else:
		bob_time = 0.0
		camera_smooth.position.y = lerp(camera_smooth.position.y, 0.0, delta * 10.0)

	# --- Apply camera effects ---
	head.position.y = lerp(head.position.y, target_height, delta * crouch_speed)
	camera.fov = lerp(camera.fov, target_fov, delta * fov_speed)

	# Pass aim offset to the gun (if it has the method)
	if gun and gun.has_method("set_aim_offset"):
		gun.set_aim_offset(aim_offset if aiming else Vector3.ZERO)

	move_and_slide()

# ========================
# HELPER: check if we can stand up
# ========================
func can_stand() -> bool:
	return not test_move(transform, Vector3(0, stand_height - crouch_height, 0))
