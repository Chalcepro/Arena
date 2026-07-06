extends CharacterBody3D

@onready var camera = %Camera
@export var subviewport_camera: Camera3D
@export var main_camera: Camera3D
@export var animation_tree: AnimationTree

# Crouch collision shape (ShapeCast3D pointing upward to check for ceiling)
@export var crouch_ceiling_check: ShapeCast3D

# Collision shape for the player (must be a CylinderShape3D or CapsuleShape3D)
@export var player_collision_shape: CollisionShape3D

var camera_rotation: Vector2 = Vector2(0.0,0.0)
var mouse_sensitivity = 0.001
var crouched: bool = false
var crouch_blocked: bool = false

@export_category("Crouch Parameters")
@export var enable_crouch: bool = true
@export var crouch_toggle: bool = false          # false = hold to crouch, true = toggle
@export_range(0.0,3.0) var crouch_speed_reduction = 2.0
@export_range(0.0,0.50) var crouch_blend_speed = .2
@export var standing_height: float = 1.8
@export var crouch_height: float = 1.0
@export var camera_standing_offset: float = 0.6   # camera Y relative to player origin when standing
@export var camera_crouch_offset: float = 0.2     # camera Y when crouching
@export var crouch_transition_speed: float = 8.0

enum {GROUND_CROUCH = -1, STANDING = 0, AIR_CROUCH = 1}

@export_category("Lean Parameters")
@export var enable_lean: bool = true
@export_range(0.0,1.0) var lean_speed: float = .2
@export var right_lean_collision: ShapeCast3D
@export var left_lean_collision: ShapeCast3D
var lean_tween
enum {LEFT = 1, CENTRE = 0, RIGHT = -1}

@export_category("Speed Parameters")
@export var enable_sprint: bool = true
@export var sprint_timer: Timer
@export var sprint_cooldown_time: float = 3.0
@export var sprint_time: float = 1.0
@export var sprint_replenish_rate: float = 0.30
@export var acceleration: float = 120
@export_range(0.01,1.0) var air_acceleration_modifier: float = 0.4   # better air control
var sprint_on_cooldown: bool = false
var sprint_time_remaining: float = sprint_time
@onready var sprint_bar: Range = $CanvasLayer/SprintBar

const NORMAL_speed = 1
@export_range(1.0,3.0) var sprint_speed: float = 2.0
@export_range(0.1,1.0) var walk_speed: float = 0.5
var speed_modifier: float = NORMAL_speed

@export_category("Jump Parameters")
@export var coyote_timer: Timer
@export var jump_peak_time: float = .5
@export var jump_fall_time: float = .5
@export var jump_height: float = 2.0
@export var jump_distance: float = 4.0
@export var coyote_time: float = .1
@export var jump_buffer_time: float = .2

# Gravity and jump physics
var jump_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var fall_gravity: float
var jump_velocity: float
var base_speed: float 
var _speed: float 
var jump_available: bool = true
var jump_buffer: bool = false

# Slide variables
@export_category("Slide Parameters")
@export var enable_slide: bool = true
@export var slide_speed: float = 8.0
@export var slide_duration: float = 0.8
@export var slide_deceleration: float = 10.0   # (reserved for future use)
@export var slide_cooldown: float = 1.0
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0

func _ready() -> void:
	update_camera_rotation()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	calculate_movement_parameters()
	# Initialize collision shape and camera position
	if player_collision_shape and player_collision_shape.shape is CylinderShape3D:
		standing_height = player_collision_shape.shape.height
		camera.position.y = camera_standing_offset
	
func update_camera_rotation() -> void:
	var current_rotation = get_rotation()
	camera_rotation.x = current_rotation.y
	camera_rotation.y = current_rotation.x
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if event is InputEventMouseMotion:
		var MouseEvent = event.relative * mouse_sensitivity
		camera_look(MouseEvent)
	
	# Crouch (only if not sliding)
	if enable_crouch and event.is_action_pressed("crouch") and not is_sliding:
		crouch()
	if enable_crouch and event.is_action_released("crouch"):
		if !crouch_toggle and crouched:
			crouch()
	
	# Slide trigger: sprinting on ground, not crouched, press crouch
	if enable_slide and event.is_action_pressed("crouch"):
		if not is_sliding and speed_modifier == sprint_speed and is_on_floor() and not crouched:
			start_slide()
	
	if enable_lean:
		if Input.is_action_just_released("lean_left") or Input.is_action_just_released("lean_right"):
			if !(Input.is_action_pressed("lean_right") or Input.is_action_pressed("lean_left")):
				lean(CENTRE)
		if Input.is_action_just_pressed("lean_left"):
			lean(LEFT)
		if Input.is_action_just_pressed("lean_right"):
			lean(RIGHT)
		
	if enable_sprint:
		if Input.is_action_just_pressed("sprint") and !crouched and !is_sliding:
			if !sprint_on_cooldown:
				speed_modifier = sprint_speed
				sprint_timer.start(sprint_time_remaining)
				
		if Input.is_action_just_released("sprint") or Input.is_action_just_released("walk"):
			if !(Input.is_action_pressed("walk") or Input.is_action_pressed("sprint")):
				speed_modifier = NORMAL_speed
				exit_sprint()
				
		if Input.is_action_just_pressed("walk") and !crouched:
			speed_modifier = walk_speed

func calculate_movement_parameters() -> void:
	jump_gravity = (2*jump_height)/pow(jump_peak_time,2)
	fall_gravity = (2*jump_height)/pow(jump_fall_time,2)
	jump_velocity = jump_gravity * jump_peak_time
	base_speed = jump_distance/(jump_peak_time+jump_fall_time)
	_speed = base_speed

func lean(blend_amount: int) -> void:
	if is_on_floor():
		if lean_tween:
			lean_tween.kill()
		
		lean_tween = get_tree().create_tween()
		lean_tween.tween_property(animation_tree,"parameters/lean_blend/blend_amount", blend_amount, lean_speed)

func lean_collision() -> void:
	animation_tree["parameters/left_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/left_collision_blend/blend_amount"]),float(left_lean_collision.is_colliding()),lean_speed
	)
	animation_tree["parameters/right_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/right_collision_blend/blend_amount"]),float(right_lean_collision.is_colliding()),lean_speed
	)

func crouch() -> void:
	if !crouch_ceiling_check.is_colliding() or crouched:
		# Toggle state
		crouched = !crouched
		
		if crouched:
			# Enter crouch
			speed_modifier = NORMAL_speed
			exit_sprint()
			if is_sliding:
				stop_slide()
		else:
			# Exit crouch – check if we can stand up
			if crouch_ceiling_check.is_colliding():
				crouched = true
				crouch_blocked = true
				return
		
		# Animation blend
		var Blend = GROUND_CROUCH if crouched and is_on_floor() else (AIR_CROUCH if crouched else STANDING)
		var blend_tween = get_tree().create_tween()
		blend_tween.tween_property(animation_tree, "parameters/Crouch_Blend/blend_amount", Blend, crouch_blend_speed)
		
		# Change collision height and camera position
		var target_height = crouch_height if crouched else standing_height
		var target_camera_y = camera_crouch_offset if crouched else camera_standing_offset
		var tween = get_tree().create_tween()
		tween.tween_property(player_collision_shape.shape, "height", target_height, crouch_transition_speed)
		tween.parallel().tween_property(camera, "position:y", target_camera_y, crouch_transition_speed)
	else:
		crouch_blocked = true

func camera_look(Movement: Vector2) -> void:
	camera_rotation += Movement
	
	transform.basis = Basis()
	camera.transform.basis = Basis()
	
	rotate_object_local(Vector3(0,1,0), -camera_rotation.x)
	camera.rotate_object_local(Vector3(1,0,0), -camera_rotation.y)
	camera_rotation.y = clamp(camera_rotation.y, -1.5, 1.2)
	
func exit_sprint() -> void:
	if !sprint_timer.is_stopped():
		sprint_time_remaining = sprint_timer.time_left
		sprint_timer.stop()

func sprint_replenish(delta: float) -> void:
	var sprint_bar_Value: float
	if !sprint_on_cooldown and (speed_modifier != sprint_speed):
		if is_on_floor():
			sprint_time_remaining = move_toward(sprint_time_remaining, sprint_time, delta * sprint_replenish_rate)
		sprint_bar_Value = (sprint_time_remaining / sprint_time) * 100
	else:
		sprint_bar_Value = (sprint_timer.time_left / sprint_time) * 100
	
	sprint_bar.value = sprint_bar_Value
	if sprint_bar_Value == 100:
		sprint_bar.hide()
	else:
		sprint_bar.show()

func _process(delta: float) -> void:
	if subviewport_camera:
		subviewport_camera.global_transform = main_camera.global_transform

func start_slide() -> void:
	# If we were crouching, stand up instantly (no tween) for slide
	if crouched:
		crouched = false
		player_collision_shape.shape.height = standing_height
		camera.position.y = camera_standing_offset
	is_sliding = true
	slide_timer = slide_duration
	speed_modifier = slide_speed
	# Optionally trigger slide animation here

func stop_slide() -> void:
	is_sliding = false
	speed_modifier = NORMAL_speed
	slide_cooldown_timer = slide_cooldown
	# Ensure we are not stuck in crouch after slide
	if crouched:
		crouched = false
		var tween = get_tree().create_tween()
		tween.tween_property(player_collision_shape.shape, "height", standing_height, crouch_transition_speed)
		tween.parallel().tween_property(camera, "position:y", camera_standing_offset, crouch_transition_speed)

func _physics_process(delta: float) -> void:
	sprint_replenish(delta)
	lean_collision()
	
	# Slide cooldown
	if slide_cooldown_timer > 0:
		slide_cooldown_timer -= delta
	
	# Active slide handling
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0 or not is_on_floor() or Input.is_action_just_released("crouch"):
			stop_slide()
		else:
			_speed = slide_speed
			var input_dir = Input.get_vector("left", "right", "up", "down")
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = move_toward(velocity.x, direction.x * _speed, acceleration * 0.2 * delta)
			velocity.z = move_toward(velocity.z, direction.z * _speed, acceleration * 0.2 * delta)
			move_and_slide()
			return
	
	# Crouch blocked recovery
	if crouched and crouch_blocked:
		if !crouch_ceiling_check.is_colliding():
			crouch_blocked = false
			if !Input.is_action_pressed("crouch") and !crouch_toggle:
				crouch()
	
	# Gravity and ground check
	var _acceleration: float
	if not is_on_floor():
		_acceleration = acceleration * air_acceleration_modifier
		if coyote_timer.is_stopped():
			coyote_timer.start(coyote_time)
		if velocity.y > 0:
			velocity.y -= jump_gravity * delta
		else:
			velocity.y -= fall_gravity * delta
	else:
		_acceleration = acceleration
		jump_available = true
		coyote_timer.stop()
		_speed = (base_speed / max((float(crouched) * crouch_speed_reduction), 1)) * speed_modifier
		if jump_buffer:
			jump()
			jump_buffer = false
	
	# Jump input
	if Input.is_action_just_pressed("ui_accept"):
		if jump_available:
			if crouched:
				crouch()
			else:
				lean(CENTRE)
				jump()
		else:
			jump_buffer = true
			get_tree().create_timer(jump_buffer_time).timeout.connect(on_jump_buffer_timeout)
	
	# Movement input
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = move_toward(velocity.x, direction.x * _speed, _acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * _speed, _acceleration * delta)
	
	move_and_slide()

func jump() -> void:
	velocity.y = jump_velocity
	jump_available = false

func _on_sprint_timer_timeout() -> void:
	sprint_on_cooldown = true
	get_tree().create_timer(sprint_cooldown_time).timeout.connect(_on_sprint_cooldown_timeout)
	speed_modifier = NORMAL_speed
	sprint_time_remaining = 0

func _on_sprint_cooldown_timeout() -> void:
	sprint_on_cooldown = false

func _on_coyote_timer_timeout() -> void:
	jump_available = false

func on_jump_buffer_timeout() -> void:
	jump_buffer = false
