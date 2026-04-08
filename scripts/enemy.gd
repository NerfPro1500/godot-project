extends CharacterBody2D

const WALK_SPEED  := 80.0
const CHASE_SPEED := 140.0
const GRAVITY     := 980.0
const DETECT_RANGE := 250.0

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_left  : RayCast2D = $RayLeft
@onready var ray_right : RayCast2D = $RayRight

var direction := -1.0
var _player : CharacterBody2D = null

func _ready() -> void:
	sprite.play("walk")
	_update_facing()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# Find the player once, then cache
	if _player == null or not is_instance_valid(_player):
		var p := get_tree().get_first_node_in_group("player")
		_player = p as CharacterBody2D

	var chasing := false
	if _player and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist <= DETECT_RANGE:
			chasing = true
			direction = sign(_player.global_position.x - global_position.x)
			if direction == 0.0:
				direction = 1.0
			_update_facing()

	var speed := CHASE_SPEED if chasing else WALK_SPEED
	velocity.x = direction * speed

	move_and_slide()

	# Patrol logic: reverse at walls/ledges when not chasing
	if is_on_floor() and not chasing:
		var hit_wall := is_on_wall()
		var at_ledge := false
		if direction < 0 and not ray_left.is_colliding():
			at_ledge = true
		elif direction > 0 and not ray_right.is_colliding():
			at_ledge = true

		if hit_wall or at_ledge:
			direction *= -1.0
			_update_facing()

func _update_facing() -> void:
	sprite.flip_h = (direction < 0)
