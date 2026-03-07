extends CharacterBody3D

# Speeds
var WALK_SPEED = 8.0
var SPRINT_SPEED = 20.0
var CROUCH_SPEED = 4.0
var SLIDE_SPEED = 14.0
var SLIDE_INITIAL_SPEED = 18.0   # boost for slide start
var JUMP_FORCE = 5.5

# Mouse
const MOUSE_SENS = 0.003

# Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# States
var speed = WALK_SPEED
var sliding = false
var crouching = false
var slide_direction = Vector3.ZERO

# Camera smoothing
var target_crouch_height = 1.5
var crouch_speed = 10.0

# FOV
var default_fov = 75.0
var sprint_fov = 85.0
var slide_fov = 105.0
var fov_change_speed = 8.0
var target_fov = default_fov

# Nodes
@onready var head = $head
@onready var camera = $head/camera_smooth/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = default_fov

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE

	# Movement input
	var input = Input.get_vector("move_right","move_left","move_backward","move_forward")
	var direction = (head.transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# --- State handling ---
	if not sliding:
		# Reset speed to walk (will be overridden by sprint/crouch)
		speed = WALK_SPEED

		# Sprint (only if not crouching)
		if Input.is_action_pressed("sprint") and not crouching:
			speed = SPRINT_SPEED
			target_fov = sprint_fov
		else:
			target_fov = default_fov

		# Crouch (hold)
		if Input.is_action_pressed("crouch"):
			crouching = true
			target_crouch_height = 1.0
			speed = CROUCH_SPEED
		else:
			crouching = false
			target_crouch_height = 1.5

		# Start slide
		if Input.is_action_just_pressed("crouch") and Input.is_action_pressed("sprint") and is_on_floor():
			sliding = true
			#crouching = true
			target_crouch_height = 1.0
			speed = SLIDE_INITIAL_SPEED
			target_fov = slide_fov
			# Use current movement direction if any, otherwise facing direction
			slide_direction = direction if direction.length() > 0 else -head.global_transform.basis.z
			slide_direction = slide_direction.normalized()
	else:
		# In slide – maintain stored direction
		velocity.x = slide_direction.x * speed
		velocity.z = slide_direction.z * speed
		target_fov = default_fov

		# Decelerate
		speed = lerp(speed, WALK_SPEED, delta * 2.0)

		# End slide when slow enough
		if speed <= WALK_SPEED + 0.5:
			sliding = false
			crouching = false
			target_crouch_height = 1.5
			target_fov = default_fov

	# Apply movement (if not sliding, use current direction)
	if not sliding:
		if direction.length() > 0:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

	# Smooth camera height
	head.position.y = lerp(head.position.y, target_crouch_height, delta * crouch_speed)

	# Smooth FOV
	camera.fov = lerp(camera.fov, target_fov, delta * fov_change_speed)
	
	# Mobile look
var touch_look_sensitivity = 0.005
var drag_touch_index = -1

func _input(event):
	# Existing mouse look (keep it)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Mobile look: detect touch drag on right half of screen
	if event is InputEventScreenTouch and event.pressed:
		if event.position.x > get_viewport().size.x / 2:
			drag_touch_index = event.index
	elif event is InputEventScreenTouch and not event.pressed and event.index == drag_touch_index:
		drag_touch_index = -1
	elif event is InputEventScreenDrag and event.index == drag_touch_index:
		head.rotate_y(-event.relative.x * touch_look_sensitivity)
		camera.rotate_x(-event.relative.y * touch_look_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# ESC and mouse click for mouse capture (keep)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	move_and_slide()
