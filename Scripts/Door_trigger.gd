extends Area2D

@onready var door = $"../Door"

# Called when the node enters the scene tree for the first time.
func _ready():
	door.visible=false
	door.collision_layer=2
	door.collision_mask=2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body):
	door.visible=true
	door.collision_layer=1
	door.collision_mask=1
