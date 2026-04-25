extends Area2D

var _exit_transition_started := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _exit_transition_started:
		return
	_exit_transition_started = true
	call_deferred("_go_to_next_level")

func _go_to_next_level() -> void:
	var current_path := get_tree().current_scene.scene_file_path
	var current_file := current_path.get_file().get_basename()

	# Extract the trailing number from the current level filename.
	var regex := RegEx.new()
	regex.compile("(\\d+)$")
	var result := regex.search(current_file)
	print('Trying to exit ' + current_file)
	if result == null:
		push_warning("ExitZone: Could not parse level number from '%s'" % current_file)
		return

	var trailing := result.get_string()
	var next_num := trailing.to_int() + 1
	var current_prefix := current_file.substr(0, current_file.length() - trailing.length())
	var dir := current_path.get_base_dir()

	# Scan the scenes folder for any file ending with the next number AND sharing the same prefix.
	var da := DirAccess.open(dir)
	if da == null:
		push_warning("ExitZone: Cannot open directory '%s'" % dir)
		return

	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir():
			var base := fname.get_basename()
			var ext := fname.get_extension()
			if ext == "tscn" or ext == "scn":
				var m := regex.search(base)
				if m:
					print('Evaluating ' + m.get_string())
				if m and m.get_string().to_int() == next_num:
					var candidate_prefix := base.substr(0, base.length() - m.get_string().length())
					if candidate_prefix == current_prefix:
						get_tree().change_scene_to_file(dir.path_join(fname))
						return
		fname = da.get_next()

	push_warning("ExitZone: No level found with number %d in '%s'" % [next_num, dir])
