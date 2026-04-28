extends CharacterBody2D

const WALK_SPEED   := 120.0
const RUN_SPEED    := 220.0
const JUMP_FORCE   := -420.0
const GRAVITY      := 980.0
const ROLL_SPEED   := 300.0
const ROLL_TIME    := 0.4
const WALL_GRAV    := 120.0
const WALL_MAX     := 50.0
const MAX_HELTH    := 25

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D

@onready var helth : int = MAX_HELTH

var face_dir      := 1.0
var jumps         := 0
var roll_timer    := 0.0
var state         := "idle"
var prev_on_floor := false
var _restart_pending := false

var ray_chest : RayCast2D
var ray_head  : RayCast2D

func _ready() -> void:
	helth = MAX_HELTH
	sprite.animation_finished.connect(_on_anim_done)

	ray_chest = RayCast2D.new()
	ray_chest.position = Vector2(0, -20)
	ray_chest.collision_mask = 1
	add_child(ray_chest)

	ray_head = RayCast2D.new()
	ray_head.position = Vector2(0, -38)
	ray_head.collision_mask = 1
	add_child(ray_head)

func _physics_process(delta: float) -> void:
	if helth <= 0 and not _restart_pending:
		_restart_pending = true
		call_deferred("_restart_level")
		return

	var on_floor := is_on_floor()
	var h        := Input.get_axis("move_left", "move_right")
	var running  := Input.is_action_pressed("roll")  # hold Shift = run

	# Raycasts always face current direction
	ray_chest.target_position = Vector2(16.0 * face_dir, 0)
	ray_head.target_position  = Vector2(16.0 * face_dir, 0)
	ray_chest.force_raycast_update()
	ray_head.force_raycast_update()
	var at_ledge := (ray_chest.is_colliding() and not ray_head.is_colliding()
		and not on_floor and velocity.y >= -20.0)

	# ── GRAVITY ──────────────────────────────────────────
	if on_floor:
		velocity.y = 0.0
	elif state == "wall_slide":
		velocity.y = min(velocity.y + WALL_GRAV * delta, WALL_MAX)
	else:
		velocity.y += GRAVITY * delta

	# ── LOCKED: ROLL ─────────────────────────────────────
	if state == "roll":
		roll_timer -= delta
		velocity.x = face_dir * ROLL_SPEED
		if roll_timer <= 0.0:
			_go("idle")
		move_and_slide()
		prev_on_floor = on_floor
		return

	# ── LOCKED: LAND ─────────────────────────────────────
	if state == "land" or state == "wall_land":
		velocity.x = 0.0
		move_and_slide()
		prev_on_floor = on_floor
		return

	# ── LOCKED: LEDGE ────────────────────────────────────
	if state == "ledge_grab" or state == "ledge_climb":
		velocity = Vector2.ZERO
		if state == "ledge_grab":
			if Input.is_action_just_pressed("jump"):
				_go("ledge_climb")
			elif Input.is_action_just_pressed("crouch"):
				state = "jump"
				velocity.y = 100.0
				_play("jump")
		move_and_slide()
		prev_on_floor = on_floor
		return

	# ── LOCKED: WALL SLIDE ───────────────────────────────
	if state == "wall_slide":
		var wn := get_wall_normal()
		# Landing from wall slide
		if on_floor and not prev_on_floor:
			_go("wall_land")
			move_and_slide()
			prev_on_floor = on_floor
			return
		elif Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_FORCE
			velocity.x = wn.x * RUN_SPEED
			face_dir = sign(wn.x)
			sprite.flip_h = (face_dir < 0)
			jumps = 1
			_go("jump")
		elif not is_on_wall_only():
			_go("jump")
		velocity.x = -wn.x * 5.0
		move_and_slide()
		prev_on_floor = on_floor
		return

	# ── FREE MOVEMENT ────────────────────────────────────
	if h != 0:
		face_dir = sign(h)
	sprite.flip_h = (face_dir < 0)

	var move_speed := RUN_SPEED if running else WALK_SPEED
	velocity.x = h * move_speed

	# Jump
	if Input.is_action_just_pressed("jump"):
		if on_floor:
			velocity.y = JUMP_FORCE
			jumps = 1
			_go("jump")
		elif jumps == 1:
			velocity.y = JUMP_FORCE * 0.85
			jumps = 2
			_go("air_spin")

	# Roll (tap Shift while moving on floor)
	if Input.is_action_just_pressed("roll") and on_floor and h != 0:
		roll_timer = ROLL_TIME
		velocity.x = face_dir * ROLL_SPEED
		_go("roll")
		move_and_slide()
		prev_on_floor = on_floor
		return

	# ── ANIMATION STATE ───────────────────────────────────
	if on_floor:
		# Just landed
		if not prev_on_floor and state in ["jump", "air_spin"]:
			_go("land")
		elif Input.is_action_pressed("crouch"):
			velocity.x = h * WALK_SPEED * 0.5
			_go("crouch_walk" if h != 0 else "crouch_idle")
		elif h != 0:
			_go("run" if running else "walk")
		else:
			_go("idle")
	else:
		if at_ledge and h != 0 and sign(h) == face_dir:
			_go("ledge_grab")
		elif is_on_wall_only() and h != 0 and velocity.y > 0:
			if sign(h) != sign(get_wall_normal().x):
				_go("wall_slide")
		elif state not in ["jump", "air_spin"]:
			_go("jump")
		# Reset jump count if walked off edge
		if on_floor == false and prev_on_floor == true and state == "jump":
			jumps = 1

	prev_on_floor = on_floor
	move_and_slide()

func _go(s: String) -> void:
	if state == s:
		return
	state = s
	_play(s)
	match s:
		"ledge_grab":
			sprite.position = Vector2(0, -10)
		"ledge_climb":
			sprite.position = Vector2(18, -38)
		_:
			sprite.position = Vector2(0, -16)

func _play(anim: String) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		# Fallback so kids don't get a frozen character if a file is missing
		push_warning("Missing animation: " + anim)
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func _on_anim_done() -> void:
	match state:
		"land":       _go("idle")
		"wall_land":  _go("idle")
		"roll":       _go("idle")
		"ledge_climb":
			position.y -= 48
			position.x += face_dir * 20
			_go("idle")

func _restart_level() -> void:
	var current_path := get_tree().current_scene.scene_file_path
	if current_path == "":
		push_warning("Player: Could not restart level; current scene path is empty")
		return
	get_tree().change_scene_to_file(current_path)
