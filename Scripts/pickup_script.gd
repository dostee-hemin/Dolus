extends Node2D

@export var item: InvItem

var player=null
var player_in_area=false
@onready var sprite_2d = $Area2D/Sprite2D


func _ready():
	sprite_2d.texture=item.texture



func _on_area_2d_body_entered(body):

	if body.is_in_group("Player"):
		player=body
		player_in_area=true
		player.collect(item)
		await get_tree().create_timer(0.1).timeout
		self.queue_free()

