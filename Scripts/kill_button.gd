extends Button

var kill_method:String

@onready var inv_ui_slot = $".."

@onready var inside_slot = $"../CenterContainer/Panel/inside_slot"

func _pressed():
	if !inside_slot.texture==null:
		inv_ui_slot.player.cause_of_kill=kill_method
