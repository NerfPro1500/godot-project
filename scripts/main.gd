extends Node2D

@onready var state_label : Label = $HUD/StateLabel

func _process(_delta: float) -> void:
	state_label.text = ''
