extends Node2D

## Minimum seconds between spawns.
@export var spawn_time_min := 2.0
## Maximum seconds between spawns.
@export var spawn_time_max := 5.0
## Maximum number of enemies this generator can have alive at once.
@export var max_enemies := 3
## How close the player must be before the generator activates.
@export var activation_radius := 300.0

var _enemy_scene : PackedScene = preload("res://scenes/enemy.tscn")
var _alive_enemies : Array[Node] = []
var _active := false

@onready var _timer : Timer = $SpawnTimer
@onready var _spawn_point : Marker2D = $SpawnPoint
@onready var _trigger_area : Area2D = $TriggerArea
@onready var _trigger_shape : CollisionShape2D = $TriggerArea/CollisionShape2D

func _ready() -> void:
	# Apply the exported radius to the trigger shape
	(_trigger_shape.shape as CircleShape2D).radius = activation_radius
	_timer.timeout.connect(_on_spawn_timer_timeout)
	_trigger_area.body_entered.connect(_on_body_entered)
	_trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _active:
		_active = true
		_start_timer()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_active = false
		_timer.stop()

func _start_timer() -> void:
	_timer.wait_time = randf_range(spawn_time_min, spawn_time_max)
	_timer.start()

func _on_spawn_timer_timeout() -> void:
	if not _active:
		return

	# Clean up references to freed enemies
	_alive_enemies = _alive_enemies.filter(func(e): return is_instance_valid(e))

	if _alive_enemies.size() < max_enemies:
		var enemy := _enemy_scene.instantiate()
		enemy.global_position = _spawn_point.global_position
		get_parent().add_child(enemy)
		_alive_enemies.append(enemy)

	_start_timer()
