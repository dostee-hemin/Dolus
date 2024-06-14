extends Node2D

@onready var game_manager : Node = get_node("/root/Game/GameManager")

var as_entity : Entity

@export_multiline var actions_string : String
var all_actions : Array

# Called when the node enters the scene tree for the first time.
func _ready():
	all_actions = actions_string.split(";")
	as_entity = Entity.new(self, get_name(), game_manager.get_location(global_position), all_actions[0], null)
