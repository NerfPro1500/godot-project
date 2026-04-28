extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	call_deferred("_restart_level")

func _restart_level() -> void:
	var current_path := get_tree().current_scene.scene_file_path
	if current_path == "":
		push_warning("Border: Could not restart level; current scene path is empty")
		return
	get_tree().change_scene_to_file(current_path)
