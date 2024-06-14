extends PointLight2D

@onready var light = $".."

@export var is_flickering : bool = false

@onready var game_manager = get_node("/root/Game/GameManager")
@onready var day_night_cycle = get_node("/root/Game/Layout/day_night cycle")

var starting_energy : float = 0.9
var current_energy : float = starting_energy
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if day_night_cycle.time_as_float>9 && day_night_cycle.time_as_float<19:
		energy=0.2
	else:
		if is_flickering and randf_range(0,1) < 0.1:
			current_energy = starting_energy+randf_range(-0.1,0.1)
		energy = current_energy
	#if candle_lamp.as_entity.entity_name==null:
		#print("whi")
	if game_manager.get_item_action(light)=="off":
		light.visible=false
	elif game_manager.get_item_action(light)=="on":
		light.visible=true
