extends Control

@onready var game_manager : Node = get_node("/root/Game/GameManager")

@onready var inv:Inv=preload("res://Resources/player_inventory.tres")
@onready var slots:Array =  $NinePatchRect/GridContainer.get_children()

@onready var player = $"../../Player"

func _ready():
	inv.update.connect(update_slots)
	update_slots()
	visible = false

func update_slots():
	for i in min(inv.slots.size(),slots.size()):
		slots[i].update(inv.slots[i])

func _input(_event):
	if game_manager.is_UI_active():
		return
		
	if Input.is_action_just_pressed("toggle inventory"):
		visible = !visible

